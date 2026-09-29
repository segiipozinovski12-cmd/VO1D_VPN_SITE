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
    @Published private(set) var isGuestMode = false
    @Published private(set) var paywallRequested = false
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
    private var trafficTask: Task<Void, Never>?
    private var connectionID = UUID()
    private var switching = false
    private var foreground = true
    private var didBootstrap = false
    private var authRevision = UUID()
    private let pendingPaymentOrderKey = "vo1d.pendingPayment.orderID"
    private let pendingPaymentPollKey = "vo1d.pendingPayment.pollToken"

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

    var hasActiveSubscription: Bool {
        account?.active == true &&
        account?.banned == false &&
        (account?.until ?? 0) > Int64(Date().timeIntervalSince1970)
    }

    var fastestServer: VO1DServer? { ServerRanking.fastest(servers, pings: pings.values) }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        defer { isBootstrapping = false }
        #if targetEnvironment(simulator)
        let processInfo = ProcessInfo.processInfo
        let autoLoginPreview =
            processInfo.arguments.contains("-vo1d.preview.autoLogin") ||
            processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            processInfo.processName.contains("xctest")

        try? await vpn.prepare()

        if autoLoginPreview {
            setupSimulatorDemo()
            await pings.refresh()
            chooseInitialServer()
        } else {
            // Match a real fresh install: first launch opens the plan/key screen.
            sessionToken = nil
            account = nil
            servers = []
            selectedServer = nil
            activeServer = nil
        }
        #else
        sessionToken = KeychainStore.loadToken()

        do {
            try await vpn.prepare()
        } catch {
            // Browsing the interface must not be blocked by Network Extension
            // provisioning. Surface this only for an already-authenticated user.
            if sessionToken != nil {
                report(error)
            }
        }

        if sessionToken != nil {
            await refresh()
        } else {
            setupGuestCatalog()
            await resumePendingPaymentIfNeeded()
        }
        #endif
        pings.start(
            live:
                preferences.livePing &&
                foreground &&
                sessionToken != nil
        )
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

        guard let embedded = AccessKeyVault.license(for: clean) else {
            report(APIClientError.server("This VO1D key is not valid. Check the code and try again."))
            return false
        }

        do {
            let response = try await api.activate(key: embedded.code)
            guard revision == authRevision, !Task.isCancelled else { return false }
            disconnect()
            KeychainStore.saveToken(response.token)
            sessionToken = response.token
            isGuestMode = false
            paywallRequested = false
            apply(account: response.account, collection: response.servers)
            await pings.refresh()
            chooseInitialServer()
            pings.start(live: preferences.livePing && foreground)
            return true
        } catch { report(error); return false }
        #endif
    }

    func createPayment(
        planDays: Int,
        method: String
    ) async throws -> PaymentCreateResponse {
        errorMessage = nil
        let response = try await api.createPayment(
            planDays: planDays,
            paymentMethod: method
        )
        defaults.set(response.orderId, forKey: pendingPaymentOrderKey)
        defaults.set(response.pollToken, forKey: pendingPaymentPollKey)
        return response
    }

    func paymentStatus(
        orderID: String,
        pollToken: String
    ) async throws -> PaymentStatusResponse {
        try await api.paymentStatus(
            orderID: orderID,
            pollToken: pollToken
        )
    }

    @discardableResult
    func finishPurchasedPayment(
        _ response: PaymentStatusResponse
    ) async -> Bool {
        guard response.status == "paid",
              let token = response.token,
              let account = response.account,
              let collection = response.servers
        else {
            return false
        }

        disconnect()
        KeychainStore.saveToken(token)
        sessionToken = token
        isGuestMode = false
        paywallRequested = false
        errorMessage = nil
        defaults.removeObject(forKey: pendingPaymentOrderKey)
        defaults.removeObject(forKey: pendingPaymentPollKey)
        apply(account: account, collection: collection)
        await pings.refresh()
        chooseInitialServer()
        pings.start(live: preferences.livePing && foreground)
        Haptics.play(.success, enabled: preferences.haptics)
        return true
    }

    private func resumePendingPaymentIfNeeded() async {
        guard let orderID = defaults.string(forKey: pendingPaymentOrderKey),
              let pollToken = defaults.string(forKey: pendingPaymentPollKey),
              !orderID.isEmpty,
              !pollToken.isEmpty
        else { return }

        do {
            let response = try await api.paymentStatus(
                orderID: orderID,
                pollToken: pollToken
            )

            if response.status == "paid" {
                _ = await finishPurchasedPayment(response)
            } else if ["expired", "canceled", "refunded", "chargeback", "error"]
                .contains(response.status) {
                defaults.removeObject(forKey: pendingPaymentOrderKey)
                defaults.removeObject(forKey: pendingPaymentPollKey)
            }
        } catch {
            // A pending payment should survive temporary network outages.
        }
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
        guard hasActiveSubscription else {
            presentPaywall()
            return
        }

        if phase.isBusy || vpn.isConnected {
            Haptics.play(.selection, enabled: preferences.haptics)
            disconnect()
            return
        }
        let route = preferences.autoFastest ? (fastestServer ?? selectedServer) : selectedServer
        guard let route else {
            errorMessage = "No available route. Refresh locations and try again."
            Haptics.play(.error, enabled: preferences.haptics)
            return
        }
        beginConnection(to: route)
    }

    func connectFastest() async {
        guard hasActiveSubscription else {
            presentPaywall()
            return
        }

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
        guard hasActiveSubscription else {
            presentPaywall()
            return
        }

        guard !phase.isBusy, let server = activeServer ?? selectedServer else { return }
        beginConnection(to: server)
    }

    func disconnect() {
        connectionID = UUID()
        connectionTask?.cancel()
        connectionTask = nil
        stopTrafficPolling()
        switching = false
        phase = vpn.isConnected || vpn.isBusy ? .disconnecting : .ready
        vpn.disconnect()
        session.setConnected(false)
    }

    private func beginConnection(to server: VO1DServer) {
        guard hasActiveSubscription else {
            presentPaywall()
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
                guard let token = self.sessionToken else {
                    throw APIClientError.server(
                        "Session expired. Please activate your key again."
                    )
                }

                let routeAttempts =
                    options.stealthMode
                    ? min(max(server.nodes, 1), 3)
                    : 1
                var routeConnected = false
                var lastRouteError: Error?

                for routeAttempt in 0..<routeAttempts {
                    try Task.checkCancellation()
                    guard id == self.connectionID else { return }

                    if routeAttempt > 0 {
                        self.switching = true
                        self.phase = .switching
                        self.vpn.disconnect()
                        try? await self.vpn.waitUntilDisconnected()
                    } else if !self.switching {
                        self.phase = .routing
                    }

                    do {
                        let tunnel = try await self.api.tunnel(
                            token: token,
                            country: server.code,
                            attempt: routeAttempt,
                            stealth: options.stealthMode
                        )
                        try Task.checkCancellation()
                        guard id == self.connectionID else { return }

                        self.phase = .securing
                        try await self.vpn.connect(
                            tunnel: tunnel,
                            options: options
                        )
                        try await self.vpn.waitUntilConnected()
                        routeConnected = true
                        break
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        lastRouteError = error
                        self.vpn.disconnect()

                        if routeAttempt + 1 < routeAttempts {
                            try? await self.vpn.waitUntilDisconnected()
                            continue
                        }
                    }
                }

                guard routeConnected else {
                    throw lastRouteError
                        ?? APIClientError.server(
                            "No working route was available."
                        )
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
            startTrafficPolling()
            Haptics.play(.success, enabled: preferences.haptics)
        case .reasserting:
            stopTrafficPolling()
            phase = .securing
        case .connecting:
            if !switching && !phase.isBusy { phase = .securing }
        case .disconnecting:
            stopTrafficPolling()
            if !switching && phase != .failed { phase = .disconnecting }
        case .disconnected, .invalid:
            stopTrafficPolling()
            activeServer = nil
            if !switching && (phase == .disconnecting || phase == .connected) { phase = .ready }
        @unknown default: phase = .ready
        }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        session.setForeground(active)

        if active {
            pings.start(live: preferences.livePing && sessionToken != nil)
            if vpn.isConnected { startTrafficPolling() }
            if sessionToken == nil {
                Task { await resumePendingPaymentIfNeeded() }
            }
        } else {
            pings.stop()
            stopTrafficPolling()
        }
    }

    private func startTrafficPolling() {
        #if !targetEnvironment(simulator)
        guard foreground, vpn.isConnected else { return }
        trafficTask?.cancel()
        trafficTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                if let delta = await self.vpn.trafficDelta() {
                    self.session.applyTransfer(delta)
                }

                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
        #endif
    }

    private func stopTrafficPolling() {
        trafficTask?.cancel()
        trafficTask = nil
    }
    func enterGuestMode() {
        guard sessionToken == nil else { return }

        setupGuestCatalog()
        isGuestMode = true
        paywallRequested = false
        errorMessage = nil
    }

    func presentPaywall() {
        guard sessionToken == nil || !hasActiveSubscription else { return }

        paywallRequested = true
        errorMessage = nil
        Haptics.play(
            .selection,
            enabled: preferences.haptics
        )
    }

    func dismissPaywall() {
        paywallRequested = false
        errorMessage = nil
    }

    private func setupGuestCatalog() {
        let countries = [
            ("DE", "Germany", "🇩🇪"),
            ("NL", "Netherlands", "🇳🇱"),
            ("RU", "Russia", "🇷🇺"),
            ("FI", "Finland", "🇫🇮"),
            ("FR", "France", "🇫🇷"),
            ("UK", "United Kingdom", "🇬🇧"),
            ("TR", "Turkey", "🇹🇷"),
            ("US", "United States", "🇺🇸"),
            ("CA", "Canada", "🇨🇦"),
            ("SG", "Singapore", "🇸🇬"),
            ("JP", "Japan", "🇯🇵")
        ]

        let routes = countries.map { code, name, flag in
            VO1DServer(
                id: code,
                code: code,
                name: name,
                flag: flag,
                label: "VO1D · \(code)",
                nodes: 0,
                probeHost: "",
                probePort: 443,
                protocolName: "VLESS · Reality"
            )
        }

        servers = routes.sorted { $0.name < $1.name }

        if let selectedServer {
            self.selectedServer = servers.first {
                $0.code == selectedServer.code
            }
        }

        if selectedServer == nil {
            selectedServer = servers.first
        }

        activeServer = nil
        pings.configure(servers)
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
        errorMessage = nil
        paywallRequested = false
        setupGuestCatalog()
        isGuestMode = true
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
    deinit {
        connectionTask?.cancel()
        trafficTask?.cancel()
    }
}
