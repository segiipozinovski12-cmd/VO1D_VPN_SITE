import Foundation
import Combine
import NetworkExtension

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var sessionToken: String?
    @Published private(set) var account: AccountState?
    @Published private(set) var servers: [VO1DServer] = []
    @Published private(set) var selectedServer: VO1DServer?
    @Published private(set) var activeServer: VO1DServer?
    @Published private(set) var phase: ConnectionPhase = .ready
    @Published private(set) var isActivating = false
    @Published private(set) var isRefreshingAccount = false
    @Published private(set) var isBootstrapping = true
    @Published private(set) var favoriteCodes: Set<String>
    @Published private(set) var appliedOptions: ConnectionOptions?
    @Published var errorMessage: String?

    let vpn: VPNManager
    let preferences: Preferences
    let pings = PingStore()
    let session = SessionMonitor()
    private let api = APIClient.shared
    private let defaults: UserDefaults
    private var subscriptions = Set<AnyCancellable>()
    private var connectionTask: Task<Void, Never>?
    private var connectionID = UUID()
    private var switching = false
    private var foreground = true
    private var didBootstrap = false
    private var authRevision = UUID()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = Preferences(defaults: defaults)
        vpn = VPNManager()
        // No default country or favorite receives special treatment.
        favoriteCodes = Set(defaults.stringArray(forKey: "vo1d.favoriteServers") ?? [])
        vpn.$status.removeDuplicates().sink { [weak self] status in
            self?.statusChanged(status)
        }.store(in: &subscriptions)
        preferences.$livePing.dropFirst().sink { [weak self] enabled in
            guard let self else { return }
            self.pings.stop()
            self.pings.start(live: enabled && self.foreground && self.sessionToken != nil)
        }.store(in: &subscriptions)
    }

    var isDemoMode: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
    var isConnected: Bool { phase == .connected }
    var fastestServer: VO1DServer? { ServerRanking.fastest(servers, pings: pings.values) }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        defer { isBootstrapping = false }
        #if targetEnvironment(simulator)
        setupSimulatorDemo()
        try? await vpn.prepare()
        await pings.refresh()
        chooseInitialServer()
        #else
        sessionToken = KeychainStore.loadToken()
        do { try await vpn.prepare() } catch { report(error) }
        if sessionToken != nil { await refresh() }
        #endif
        pings.start(live: preferences.livePing && foreground)
        if preferences.autoConnect, account?.active == true, !vpn.isConnected, !vpn.isBusy {
            toggleConnection()
        }
    }

    @discardableResult
    func activate(key: String) async -> Bool {
        guard !isActivating else { return false }
        isActivating = true
        errorMessage = nil
        defer { isActivating = false }
        let revision = authRevision
        #if targetEnvironment(simulator)
        disconnect()
        setupSimulatorDemo()
        await pings.refresh()
        chooseInitialServer()
        pings.start(live: preferences.livePing && foreground)
        return true
        #else
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        do {
            let resolved = try AppConfig.resolveActivation(clean)
            let response = try await api.activate(key: resolved)
            guard revision == authRevision, !Task.isCancelled else { return false }
            disconnect()
            KeychainStore.saveToken(response.token)
            sessionToken = response.token
            apply(account: response.account, collection: response.servers)
            await pings.refresh()
            chooseInitialServer()
            pings.start(live: preferences.livePing && foreground)
            return true
        } catch { report(error); return false }
        #endif
    }

    func refresh() async {
        #if !targetEnvironment(simulator)
        guard let token = sessionToken, !isRefreshingAccount else { return }
        isRefreshingAccount = true
        defer { isRefreshingAccount = false }
        let revision = authRevision
        do {
            let response = try await api.me(token: token)
            guard revision == authRevision, sessionToken == token else { return }
            apply(account: response.account, collection: response.servers)
            await pings.refresh()
            chooseInitialServer()
            pings.start(live: preferences.livePing && foreground)
        } catch {
            // A network outage must not destroy an otherwise valid keychain session.
            guard revision == authRevision else { return }
            report(error)
        }
        #endif
    }

    func toggleConnection() {
        if phase.isBusy || vpn.isConnected { disconnect(); return }
        let route = preferences.autoFastest ? (fastestServer ?? selectedServer) : selectedServer
        guard let route else { errorMessage = "No available route. Refresh locations and try again."; return }
        beginConnection(to: route)
    }

    func connectFastest() async {
        guard !phase.isBusy else { return }
        if fastestServer == nil { await pings.refresh() }
        guard !phase.isBusy else { return }
        guard let server = fastestServer else {
            errorMessage = "No route responded to the ping check. Try again or select a location manually."
            return
        }
        if vpn.isConnected, activeServer?.code == server.code { return }
        beginConnection(to: server)
    }

    func select(_ server: VO1DServer) {
        guard !phase.isBusy, servers.contains(where: { $0.id == server.id }) else { return }
        preferences.autoFastest = false
        Haptics.play(.selection, enabled: preferences.haptics)
        guard selectedServer?.code != server.code else { return }
        if vpn.isConnected { beginConnection(to: server) }
        else { selectedServer = server; defaults.set(server.code, forKey: "vo1d.selectedServer") }
    }

    func reconnect() {
        guard !phase.isBusy, let server = activeServer ?? selectedServer else { return }
        beginConnection(to: server)
    }

    func disconnect() {
        connectionID = UUID()
        connectionTask?.cancel()
        connectionTask = nil
        switching = false
        phase = vpn.isConnected || vpn.isBusy ? .disconnecting : .ready
        vpn.disconnect()
        session.setConnected(false)
    }

    private func beginConnection(to server: VO1DServer) {
        guard account?.active == true, account?.banned == false,
              (account?.until ?? 0) > Int64(Date().timeIntervalSince1970) else {
            errorMessage = "Your subscription is inactive. Update your access key in Profile."
            Haptics.play(.error, enabled: preferences.haptics)
            return
        }
        connectionTask?.cancel()
        let id = UUID()
        connectionID = id
        switching = vpn.isConnected || vpn.isBusy
        phase = switching ? .switching : .preparing
        selectedServer = server
        errorMessage = nil
        let options = preferences.connectionOptions
        Haptics.play(.connect, enabled: preferences.haptics)
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                if self.vpn.isConnected || self.vpn.isBusy {
                    self.vpn.disconnect()
                    try await self.vpn.waitUntilDisconnected()
                }
                try Task.checkCancellation()
                guard id == self.connectionID else { return }
                self.appliedOptions = options
                #if targetEnvironment(simulator)
                try await self.vpn.connectDemo { [weak self] stage in
                    guard let self, id == self.connectionID else { return }
                    if !self.switching { self.phase = stage }
                }
                #else
                guard let token = self.sessionToken else { throw APIClientError.server("Session expired. Please activate your key again.") }
                if !self.switching { self.phase = .routing }
                let tunnel = try await self.api.tunnel(token: token, country: server.code)
                try Task.checkCancellation()
                guard id == self.connectionID else { return }
                if !self.switching { self.phase = .securing }
                try await self.vpn.connect(tunnel: tunnel, options: options)
                // A bounded wait also catches an extension that exits before connecting.
                let deadline = ContinuousClock.now.advanced(by: .seconds(25))
                while !self.vpn.isConnected {
                    try Task.checkCancellation()
                    guard ContinuousClock.now < deadline else { throw APIClientError.server("Connection timed out. Please try another location.") }
                    try await Task.sleep(for: .milliseconds(100))
                }
                #endif
                guard id == self.connectionID else { return }
                self.defaults.set(server.code, forKey: "vo1d.selectedServer")
                self.connectionTask = nil
            } catch is CancellationError {
                // Only the latest operation may change the visible state.
            } catch {
                guard id == self.connectionID else { return }
                self.switching = false
                self.vpn.disconnect()
                self.phase = .failed
                self.report(error)
                self.connectionTask = nil
            }
        }
    }

    private func statusChanged(_ status: NEVPNStatus) {
        session.setConnected(status == .connected, since: vpn.connectedDate)
        switch status {
        case .connected:
            switching = false
            activeServer = selectedServer
            phase = .connected
            Haptics.play(.success, enabled: preferences.haptics)
        case .reasserting: phase = .securing
        case .connecting:
            if !switching && !phase.isBusy { phase = .securing }
        case .disconnecting:
            if !switching && phase != .failed { phase = .disconnecting }
        case .disconnected, .invalid:
            activeServer = nil
            if !switching && (phase == .disconnecting || phase == .connected) { phase = .ready }
        @unknown default: phase = .ready
        }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        session.setForeground(active)
        if active { pings.start(live: preferences.livePing && sessionToken != nil) }
        else { pings.stop() }
    }
    func toggleFavorite(_ server: VO1DServer) {
        if favoriteCodes.contains(server.code) { favoriteCodes.remove(server.code) }
        else { favoriteCodes.insert(server.code) }
        defaults.set(Array(favoriteCodes).sorted(), forKey: "vo1d.favoriteServers")
        Haptics.play(.selection, enabled: preferences.haptics)
    }
    func logout() async {
        authRevision = UUID()
        let previousToken = sessionToken
        disconnect()
        pings.stop()
        session.reset()
        sessionToken = nil
        account = nil
        servers = []
        selectedServer = nil
        activeServer = nil
        errorMessage = nil
        #if !targetEnvironment(simulator)
        KeychainStore.deleteToken()
        if let previousToken { await api.logout(token: previousToken) }
        #endif
    }
    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
        Haptics.play(.error, enabled: preferences.haptics)
    }
    private func apply(account: AccountState, collection: ServerCollection) {
        self.account = account
        servers = collection.countries.sorted { $0.name < $1.name }
        if let selectedServer { self.selectedServer = servers.first { $0.code == selectedServer.code } }
        pings.configure(servers)
    }
    private func chooseInitialServer() {
        if vpn.isConnected, let country = vpn.currentCountry,
           let route = servers.first(where: { $0.code == country }) {
            selectedServer = route
            activeServer = route
            appliedOptions = vpn.currentOptions
            return
        }
        if selectedServer == nil, !preferences.autoFastest,
           let code = defaults.string(forKey: "vo1d.selectedServer") {
            selectedServer = servers.first { $0.code == code }
        }
        if selectedServer == nil { selectedServer = fastestServer ?? servers.first }
        if vpn.isConnected { activeServer = selectedServer }
    }
    #if targetEnvironment(simulator)
    private func setupSimulatorDemo() {
        let expiry = Int64(Date().addingTimeInterval(90 * 86_400).timeIntervalSince1970)
        sessionToken = "VO1D-SIMULATOR-DEMO"
        let countries = [("DE", "Germany", "🇩🇪"), ("NL", "Netherlands", "🇳🇱"),
                         ("RU", "Russia", "🇷🇺"), ("FI", "Finland", "🇫🇮"),
                         ("FR", "France", "🇫🇷"), ("UK", "United Kingdom", "🇬🇧"),
                         ("TR", "Turkey", "🇹🇷"), ("US", "United States", "🇺🇸"),
                         ("CA", "Canada", "🇨🇦"), ("SG", "Singapore", "🇸🇬"), ("JP", "Japan", "🇯🇵")]
        let routes = countries.map { code, name, flag in
            VO1DServer(id: code, code: code, name: name, flag: flag, label: "VO1D · \(code)", nodes: 1,
                       probeHost: "demo.invalid", probePort: 443, protocolName: "VLESS · Reality")
        }
        apply(account: AccountState(id: 1024, active: true, banned: false, until: expiry, remainingSeconds: 90 * 86_400),
              collection: ServerCollection(countries: routes, totalCountries: routes.count))
    }
    #endif
    deinit { connectionTask?.cancel() }
}
