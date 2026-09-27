import Foundation
import SwiftUI
import NetworkExtension

@MainActor
final class AppViewModel: ObservableObject {
    @Published var sessionToken: String?
    @Published var account: AccountState?
    @Published var servers: [VO1DServer] = []
    @Published var selectedServer: VO1DServer?
    @Published var pingByCode: [String: Int?] = [:]
    @Published var errorMessage: String?
    @Published var isActivating = false
    @Published var showingProfile = false
    @Published var isRefreshingPings = false
    @Published var liveStats = LiveStats()
    @Published var favoriteCodes: Set<String>

    @AppStorage("vo1d.nickname") var nickname = "VO1D USER"
    @AppStorage("vo1d.autoconnect") var autoConnect = false
    @AppStorage("vo1d.killswitch") var killSwitch = true

    let vpn = VPNManager()

    private let api = APIClient.shared
    private let pinger = PingService()
    private var pingTask: Task<Void, Never>?
    private var statsTask: Task<Void, Never>?

    private let favoritesKey = "vo1d.favoriteServers"

    init() {
        favoriteCodes = Set(
            UserDefaults.standard.stringArray(forKey: favoritesKey) ?? ["RU"]
        )
    }

    var connectionText: String {
        switch vpn.status {
        case .connected: return "CONNECTED"
        case .connecting, .reasserting: return "CONNECTING…"
        case .disconnecting: return "DISCONNECTING…"
        default: return "CONNECT"
        }
    }

    var fastestServer: VO1DServer? {
        servers
            .compactMap { server -> (VO1DServer, Int)? in
                guard let wrapped = pingByCode[server.code],
                      let ping = wrapped else { return nil }
                return (server, ping)
            }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    var currentPing: Int? {
        guard let code = selectedServer?.code,
              let wrapped = pingByCode[code] else {
            return nil
        }
        return wrapped
    }

    var connectionQuality: String {
        guard let ping = currentPing else { return "CHECKING" }
        if ping < 50 { return "EXCELLENT" }
        if ping < 80 { return "GOOD" }
        if ping < 120 { return "FAIR" }
        return "HIGH LATENCY"
    }

    var isDemoMode: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    func bootstrap() async {
#if targetEnvironment(simulator)
        setupSimulatorDemo()
        try? await vpn.prepare()
        startPingLoop()
        return
#else
        sessionToken = KeychainStore.loadToken()

        do {
            try await vpn.prepare()
        } catch {
            errorMessage = error.localizedDescription
        }

        guard let token = sessionToken else { return }
        await refresh(token: token)
#endif
    }

    func activate(key: String) async {
#if targetEnvironment(simulator)
        setupSimulatorDemo()
        startPingLoop()
        return
#else
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isActivating = true
        errorMessage = nil
        defer { isActivating = false }

        do {
            let resolvedKey = try AppConfig.resolveActivation(clean)
            let response = try await api.activate(key: resolvedKey)
            KeychainStore.saveToken(response.token)
            sessionToken = response.token
            apply(account: response.account, serverCollection: response.servers)
            startPingLoop()
        } catch {
            errorMessage = error.localizedDescription
        }
#endif
    }

    func refresh(token: String? = nil) async {
#if targetEnvironment(simulator)
        if account == nil { setupSimulatorDemo() }
        return
#else
        guard let token = token ?? sessionToken else { return }

        do {
            let response = try await api.me(token: token)
            apply(account: response.account, serverCollection: response.servers)
            startPingLoop()

            if autoConnect,
               vpn.status == .disconnected || vpn.status == .invalid,
               account?.active == true,
               let selectedServer {
                try? await connect(to: selectedServer)
            }
        } catch {
            KeychainStore.deleteToken()
            sessionToken = nil
            account = nil
            servers = []
            stopPingLoop()
            stopStatsLoop(reset: true)
            errorMessage = error.localizedDescription
        }
#endif
    }

    func toggleConnection() async {
        if vpn.isConnected || vpn.isBusy {
            vpn.disconnect()
            stopStatsLoop(reset: false)
            return
        }

        guard account?.active == true else {
            errorMessage = "Подписка не активна."
            return
        }

        guard let selectedServer else {
            errorMessage = "Нет доступных серверов."
            return
        }

#if targetEnvironment(simulator)
        await vpn.connectDemo()
        startStatsLoop()
#else
        do {
            try await connect(to: selectedServer)
            startStatsLoop()
        } catch {
            errorMessage = error.localizedDescription
        }
#endif
    }

    func connectFastest() async {
        guard let fastestServer else {
            await refreshPingsNow()
            guard let fastestServer else { return }
            selectedServer = fastestServer
            await toggleConnection()
            return
        }

        if selectedServer?.code != fastestServer.code {
            await select(fastestServer)
            if !vpn.isConnected && !vpn.isBusy {
                await toggleConnection()
            }
        } else if !vpn.isConnected && !vpn.isBusy {
            await toggleConnection()
        }
    }

    func select(_ server: VO1DServer) async {
        guard selectedServer?.code != server.code else { return }

        selectedServer = server

        if vpn.isConnected {
            vpn.disconnect()
            stopStatsLoop(reset: false)
            try? await Task.sleep(for: .milliseconds(260))

#if targetEnvironment(simulator)
            await vpn.connectDemo()
            startStatsLoop()
#else
            do {
                try await connect(to: server)
                startStatsLoop()
            } catch {
                errorMessage = error.localizedDescription
            }
#endif
        }
    }

    func toggleFavorite(_ server: VO1DServer) {
        if favoriteCodes.contains(server.code) {
            favoriteCodes.remove(server.code)
        } else {
            favoriteCodes.insert(server.code)
        }

        UserDefaults.standard.set(
            Array(favoriteCodes).sorted(),
            forKey: favoritesKey
        )
    }

    func isFavorite(_ server: VO1DServer) -> Bool {
        favoriteCodes.contains(server.code)
    }

    func refreshPingsNow() async {
        guard !isRefreshingPings else { return }
        isRefreshingPings = true
        await refreshPings()
        try? await Task.sleep(for: .milliseconds(180))
        isRefreshingPings = false
    }

    func logout() async {
#if targetEnvironment(simulator)
        vpn.disconnect()
        stopStatsLoop(reset: true)
        setupSimulatorDemo()
        startPingLoop()
        return
#else
        if let sessionToken {
            await api.logout(token: sessionToken)
        }

        vpn.disconnect()
        KeychainStore.deleteToken()
        sessionToken = nil
        account = nil
        servers = []
        selectedServer = nil
        stopPingLoop()
        stopStatsLoop(reset: true)
#endif
    }

    private func connect(to server: VO1DServer) async throws {
#if targetEnvironment(simulator)
        await vpn.connectDemo()
#else
        guard let token = sessionToken else {
            throw APIClientError.server("Session expired.")
        }

        let tunnel = try await api.tunnel(token: token, country: server.code)
        try await vpn.connect(tunnel: tunnel, killSwitch: killSwitch)
#endif
    }

    private func apply(account: AccountState, serverCollection: ServerCollection) {
        self.account = account
        servers = serverCollection.countries

        if let current = selectedServer,
           let refreshed = servers.first(where: { $0.code == current.code }) {
            selectedServer = refreshed
        } else {
            selectedServer =
                servers.first(where: { $0.code == "RU" }) ??
                servers.first
        }
    }

    private func startPingLoop() {
        stopPingLoop()

        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshPings()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    private func stopPingLoop() {
        pingTask?.cancel()
        pingTask = nil
    }

    private func refreshPings() async {
#if targetEnvironment(simulator)
        let base: [String: Int] = [
            "RU": 32, "DE": 48, "NL": 51, "FI": 62, "UK": 67,
            "FR": 71, "TR": 78, "US": 82, "CA": 86, "SG": 121, "JP": 132
        ]

        var next = pingByCode
        for server in servers {
            let basePing = base[server.code] ?? 75
            next[server.code] = max(8, basePing + Int.random(in: -3...4))
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            pingByCode = next
        }
#else
        let current = servers
        var next: [String: Int?] = [:]

        await withTaskGroup(of: (String, Int?).self) { group in
            for server in current {
                group.addTask { [pinger] in
                    let value = await pinger.ping(
                        host: server.probeHost,
                        port: server.probePort
                    )
                    return (server.code, value)
                }
            }

            for await (code, value) in group {
                next[code] = value
            }
        }

        pingByCode = next
#endif
    }

    private func startStatsLoop() {
        stopStatsLoop(reset: false)

        statsTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                if self.vpn.isConnected {
#if targetEnvironment(simulator)
                    let previous = self.liveStats
                    let down = max(8, previous.downloadMbps * 0.58 + Double.random(in: 42...118) * 0.42)
                    let up = max(2, previous.uploadMbps * 0.62 + Double.random(in: 8...34) * 0.38)

                    self.liveStats = LiveStats(
                        downloadMbps: down,
                        uploadMbps: up,
                        downloadedMB: previous.downloadedMB + down / 8,
                        uploadedMB: previous.uploadedMB + up / 8,
                        sessionSeconds: previous.sessionSeconds + 1
                    )
#else
                    self.liveStats.sessionSeconds += 1
#endif
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopStatsLoop(reset: Bool) {
        statsTask?.cancel()
        statsTask = nil

        if reset {
            liveStats = LiveStats()
        }
    }

#if targetEnvironment(simulator)
    private func setupSimulatorDemo() {
        let expiry = Int64(
            Date()
                .addingTimeInterval(90 * 24 * 60 * 60)
                .timeIntervalSince1970
        )
        let remaining = max(
            0,
            expiry - Int64(Date().timeIntervalSince1970)
        )

        sessionToken = "VO1D-SIMULATOR-DEMO"
        account = AccountState(
            id: 1024,
            active: true,
            banned: false,
            until: expiry,
            remainingSeconds: remaining
        )

        servers = [
            demoServer("RU", "Russia", "🇷🇺", "VLESS (Reality)"),
            demoServer("DE", "Germany", "🇩🇪", "VLESS (Reality)"),
            demoServer("NL", "Netherlands", "🇳🇱", "VLESS (Reality)"),
            demoServer("FI", "Finland", "🇫🇮", "VLESS (Reality)"),
            demoServer("UK", "United Kingdom", "🇬🇧", "VLESS (Reality)"),
            demoServer("FR", "France", "🇫🇷", "VLESS (Reality)"),
            demoServer("TR", "Turkey", "🇹🇷", "VLESS (Reality)"),
            demoServer("US", "United States", "🇺🇸", "VLESS (Reality)"),
            demoServer("CA", "Canada", "🇨🇦", "VLESS (Reality)"),
            demoServer("SG", "Singapore", "🇸🇬", "VLESS (Reality)"),
            demoServer("JP", "Japan", "🇯🇵", "VLESS (Reality)")
        ]

        if let current = selectedServer,
           let same = servers.first(where: { $0.code == current.code }) {
            selectedServer = same
        } else {
            selectedServer = servers.first
        }
    }

    private func demoServer(
        _ code: String,
        _ name: String,
        _ flag: String,
        _ protocolName: String
    ) -> VO1DServer {
        VO1DServer(
            id: code,
            code: code,
            name: name,
            flag: flag,
            label: "VO1D · \(code)",
            nodes: 1,
            probeHost: "demo.local",
            probePort: 443,
            protocolName: protocolName
        )
    }
#endif
}
