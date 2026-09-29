import Foundation
import Combine
import NetworkExtension

struct TunnelTrafficDelta: Decodable, Equatable {
    let received: Int64
    let sent: Int64
}

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
        return ConnectionOptions(
            privacyShield:
                proto.providerConfiguration?["privacyShield"] as? Bool ?? false,
            killSwitch: proto.includeAllNetworks,
            secureDNS:
                proto.providerConfiguration?["secureDNS"] as? Bool ?? true,
            ipv6Protection:
                proto.providerConfiguration?["ipv6Protection"] as? Bool ?? true
        )
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
        let effectiveKillSwitch =
            options.privacyShield || options.killSwitch
        let effectiveSecureDNS =
            options.privacyShield || options.secureDNS
        let effectiveIPv6Protection =
            options.privacyShield || options.ipv6Protection

        proto.providerConfiguration = [
            "tunnelURI": tunnel.uri,
            "country": tunnel.country,
            "label": tunnel.label,
            "expiresAt": tunnel.expiresAt,
            "privacyShield": options.privacyShield,
            "secureDNS": effectiveSecureDNS,
            "ipv6Protection": effectiveIPv6Protection
        ]
        proto.includeAllNetworks = effectiveKillSwitch
        // Privacy Shield intentionally keeps local-network traffic inside
        // the tunnel instead of exempting it from the full-tunnel route.
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

    func trafficDelta() async -> TunnelTrafficDelta? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard status == .connected,
              let session = manager?.connection as? NETunnelProviderSession else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(Data("stats".utf8)) { data in
                    guard let data else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(
                        returning: try? JSONDecoder().decode(
                            TunnelTrafficDelta.self,
                            from: data
                        )
                    )
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
        #endif
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
            guard ContinuousClock.now < deadline else {
                throw APIClientError.server("The previous route is still closing. Please try again.")
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// A tunnel that enters connecting/reasserting and then falls back to
    /// disconnected has already failed. Surface that immediately instead of
    /// leaving the UI in SECURING until the full timeout expires.
    func waitUntilConnected() async throws {
        let clock = ContinuousClock()
        let started = clock.now
        let deadline = started.advanced(by: .seconds(25))
        let launchGrace = started.advanced(by: .seconds(1))
        var sawProgress = status == .connecting || status == .reasserting

        while status != .connected {
            try Task.checkCancellation()

            if status == .connecting || status == .reasserting {
                sawProgress = true
            }

            if status == .disconnected || status == .invalid {
                if sawProgress {
                    throw APIClientError.server("The VPN tunnel stopped before the connection was established.")
                }

                if clock.now >= launchGrace {
                    throw APIClientError.server("The VPN tunnel did not start. Please try again.")
                }
            }

            guard clock.now < deadline else {
                throw APIClientError.server("Connection timed out. Please try another location.")
            }

            try await Task.sleep(for: .milliseconds(100))
        }
    }

    #if targetEnvironment(simulator)
    func connectDemo(stage: @escaping (ConnectionPhase) -> Void) async throws {
        demoDisconnect?.cancel()
        let generation = UUID()
        demoGeneration = generation
        status = .connecting
        let sequence: [(ConnectionPhase, Int)] = [
            (.preparing, 270),
            (.routing, 300),
            (.securing, 340)
        ]
        for (phase, delay) in sequence {
            stage(phase)
            try await Task.sleep(for: .milliseconds(delay))
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
