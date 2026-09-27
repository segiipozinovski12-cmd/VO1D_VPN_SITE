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

    @AppStorage("vo1d.nickname") var nickname = "VO1D USER"
    @AppStorage("vo1d.autoconnect") var autoConnect = false
    @AppStorage("vo1d.killswitch") var killSwitch = true

    let vpn = VPNManager()
    private let api = APIClient.shared
    private let pinger = PingService()
    private var pingTask: Task<Void, Never>?

    var connectionText: String {
        switch vpn.status {
        case .connected:
            return "CONNECTED"
        case .connecting, .reasserting:
            return "CONNECTING…"
        case .disconnecting:
            return "DISCONNECTING…"
        default:
            return "CONNECT"
        }
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
            errorMessage = error.localizedDescription
        }
#endif
    }

    func toggleConnection() async {
        if vpn.isConnected || vpn.isBusy {
            vpn.disconnect()
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
#else
        do {
            try await connect(to: selectedServer)
        } catch {
            errorMessage = error.localizedDescription
        }
#endif
    }

    func select(_ server: VO1DServer) async {
        selectedServer = server

        if vpn.isConnected {
            vpn.disconnect()
            try? await Task.sleep(for: .milliseconds(450))

#if targetEnvironment(simulator)
            await vpn.connectDemo()
#else
            do {
                try await connect(to: server)
            } catch {
                errorMessage = error.localizedDescription
            }
#endif
        }
    }

    func logout() async {
#if targetEnvironment(simulator)
        vpn.disconnect()
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
                try? await Task.sleep(for: .seconds(5))
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

        for server in servers {
            let basePing = base[server.code] ?? 75
            pingByCode[server.code] = max(8, basePing + Int.random(in: -4...5))
        }
#else
        let current = servers

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
                pingByCode[code] = value
            }
        }
#endif
    }

#if targetEnvironment(simulator)
    private func setupSimulatorDemo() {
        let expiry = Int64(Date().addingTimeInterval(90 * 24 * 60 * 60).timeIntervalSince1970)
        let remaining = max(0, expiry - Int64(Date().timeIntervalSince1970))

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
