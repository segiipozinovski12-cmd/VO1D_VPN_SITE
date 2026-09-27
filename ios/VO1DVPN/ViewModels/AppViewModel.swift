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
        sessionToken = KeychainStore.loadToken()

        do {
            try await vpn.prepare()
        } catch {
            errorMessage = error.localizedDescription
        }

        guard let token = sessionToken else { return }
        await refresh(token: token)
    }

    func activate(key: String) async {
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
    }

    func refresh(token: String? = nil) async {
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

        do {
            try await connect(to: selectedServer)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ server: VO1DServer) async {
        selectedServer = server

        if vpn.isConnected {
            vpn.disconnect()
            try? await Task.sleep(for: .milliseconds(450))

            do {
                try await connect(to: server)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func logout() async {
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
    }

    private func connect(to server: VO1DServer) async throws {
        guard let token = sessionToken else {
            throw APIClientError.server("Session expired.")
        }

        let tunnel = try await api.tunnel(token: token, country: server.code)
        try await vpn.connect(tunnel: tunnel, killSwitch: killSwitch)
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
    }
}
