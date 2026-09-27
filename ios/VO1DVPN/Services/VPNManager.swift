import Foundation
import NetworkExtension

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var isConnected: Bool {
        status == .connected
    }

    var isBusy: Bool {
        status == .connecting || status == .disconnecting || status == .reasserting
    }

    func prepare() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let existing = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier ==
                AppConfig.tunnelBundleIdentifier
        }

        if let existing {
            manager = existing
        } else {
            let created = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = AppConfig.tunnelBundleIdentifier
            proto.serverAddress = "VO1D"
            created.protocolConfiguration = proto
            created.localizedDescription = "VO1D_VPN"
            created.isEnabled = true
            try await created.saveToPreferences()
            try await created.loadFromPreferences()
            manager = created
        }

        refreshStatus()
    }

    func connect(tunnel: TunnelResponse, killSwitch: Bool) async throws {
        if manager == nil {
            try await prepare()
        }

        guard let manager else {
            throw APIClientError.invalidResponse
        }

        let proto =
            (manager.protocolConfiguration as? NETunnelProviderProtocol) ??
            NETunnelProviderProtocol()

        proto.providerBundleIdentifier = AppConfig.tunnelBundleIdentifier
        proto.serverAddress = tunnel.country
        proto.providerConfiguration = [
            "tunnelURI": tunnel.uri,
            "country": tunnel.country,
            "label": tunnel.label,
            "expiresAt": tunnel.expiresAt
        ]

        if #available(iOS 14.2, *) {
            proto.includeAllNetworks = killSwitch
            proto.excludeLocalNetworks = false
        }

        manager.protocolConfiguration = proto
        manager.localizedDescription = "VO1D_VPN"
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        try manager.connection.startVPNTunnel()
        refreshStatus()
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        refreshStatus()
    }

    private func refreshStatus() {
        status = manager?.connection.status ?? .invalid
    }
}
