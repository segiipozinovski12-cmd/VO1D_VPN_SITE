import Foundation
import Combine
import NetworkExtension

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private var demoDisconnect: Task<Void, Never>?
    private var demoGeneration = UUID()

    init() {
        #if !targetEnvironment(simulator)
        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
        #endif
    }
    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        demoDisconnect?.cancel()
    }
    var isConnected: Bool { status == .connected }
    var isBusy: Bool { status == .connecting || status == .disconnecting || status == .reasserting }
    var connectedDate: Date? { manager?.connection.connectedDate }
    var currentCountry: String? {
        (manager?.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration?["country"] as? String
    }
    var currentOptions: ConnectionOptions? {
        guard let proto = manager?.protocolConfiguration as? NETunnelProviderProtocol else { return nil }
        return ConnectionOptions(killSwitch: proto.includeAllNetworks,
                                 secureDNS: proto.providerConfiguration?["secureDNS"] as? Bool ?? true,
                                 ipv6Protection: proto.providerConfiguration?["ipv6Protection"] as? Bool ?? true)
    }

    /// Read preferences at launch; ask to install a VPN configuration only on Connect.
    func prepare(createIfMissing: Bool = false) async throws {
        #if targetEnvironment(simulator)
        if status == .invalid { status = .disconnected }
        #else
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        manager = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == AppConfig.tunnelBundleIdentifier
        }
        if manager == nil, createIfMissing {
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
        #endif
    }

    func connect(tunnel: TunnelResponse, options: ConnectionOptions) async throws {
        if manager == nil { try await prepare(createIfMissing: true) }
        try Task.checkCancellation()
        guard let manager else { throw APIClientError.invalidResponse }
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConfig.tunnelBundleIdentifier
        proto.serverAddress = tunnel.country
        proto.providerConfiguration = [
            "tunnelURI": tunnel.uri, "country": tunnel.country, "label": tunnel.label,
            "expiresAt": tunnel.expiresAt, "secureDNS": options.secureDNS,
            "ipv6Protection": options.ipv6Protection
        ]
        proto.includeAllNetworks = options.killSwitch
        proto.excludeLocalNetworks = false
        manager.protocolConfiguration = proto
        manager.localizedDescription = "VO1D_VPN"
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try Task.checkCancellation()
        try await manager.loadFromPreferences()
        try Task.checkCancellation()
        try manager.connection.startVPNTunnel()
        refreshStatus()
    }

    func disconnect() {
        #if targetEnvironment(simulator)
        demoGeneration = UUID()
        demoDisconnect?.cancel()
        guard status != .disconnected && status != .invalid else { return }
        status = .disconnecting
        demoDisconnect = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            self?.status = .disconnected
        }
        #else
        manager?.connection.stopVPNTunnel()
        refreshStatus()
        #endif
    }

    /// Wait for the actual status, never guess with a fixed route-switch delay.
    func waitUntilDisconnected() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while status != .disconnected && status != .invalid {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw APIClientError.server("The previous route is still closing. Please try again.") }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    #if targetEnvironment(simulator)
    func connectDemo(stage: @escaping (ConnectionPhase) -> Void) async throws {
        demoDisconnect?.cancel()
        let generation = UUID()
        demoGeneration = generation
        status = .connecting
        for phase in [ConnectionPhase.preparing, .routing, .securing] {
            stage(phase)
            try await Task.sleep(for: .milliseconds(380))
            try Task.checkCancellation()
            guard generation == demoGeneration else { throw CancellationError() }
        }
        status = .connected
    }
    #endif

    private func refreshStatus() {
        #if !targetEnvironment(simulator)
        let next = manager?.connection.status ?? .disconnected
        if status != next { status = next }
        #endif
    }
}
