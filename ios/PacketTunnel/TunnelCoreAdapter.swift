import Foundation
import NetworkExtension
import SwiftyXrayKit

protocol TunnelCoreAdapter: AnyObject {
    func start(uri: String, packetFlow: NEPacketTunnelFlow) async throws
    func stop() async
}

enum TunnelCoreError: LocalizedError {
    case invalidWorkingDirectory

    var errorDescription: String? {
        switch self {
        case .invalidWorkingDirectory:
            return "VO1D could not create the tunnel working directory."
        }
    }
}

/// Real Xray/VLESS implementation for the iOS Packet Tunnel.
///
/// SwiftyXrayKit bridges NEPacketTunnelFlow directly into Xray-core's TUN
/// inbound, so there is no WebView, external configurator, or local SOCKS
/// handoff in the VO1D app.
final class XrayTunnelCore: TunnelCoreAdapter {
    private var bridge: XrayBridge?

    func start(uri: String, packetFlow: NEPacketTunnelFlow) async throws {
        await stop()

        let fm = FileManager.default
        guard let base = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw TunnelCoreError.invalidWorkingDirectory
        }

        let dataDir = base.appendingPathComponent(
            "VO1D/Xray",
            isDirectory: true
        )
        try fm.createDirectory(
            at: dataDir,
            withIntermediateDirectories: true
        )

        let finalConfig = dataDir.appendingPathComponent(
            "runtime-config.json",
            isDirectory: false
        )

        let newBridge = XrayBridge(packetFlow: packetFlow)
        let sniffing = SniffingConfiguration(
            destOverride: ["http", "tls", "quic"],
            enabled: true,
            routeOnly: false,
            domainsExcluded: [],
            metadataOnly: true
        )

        try newBridge.start(
            config: .url(uri),
            dataDir: dataDir,
            finalConfigPath: finalConfig,
            sniffing: sniffing,
            preset: .mobile,
            configTransform: { config in
                var final = config
                final["log"] = ["loglevel": "warning"]

                // Use encrypted tunnel routing for DNS requests as well.
                final["dns"] = [
                    "servers": [
                        "1.1.1.1",
                        "2606:4700:4700::1111"
                    ],
                    "queryStrategy": "UseIP"
                ]
                return final
            }
        )

        bridge = newBridge
    }

    func stop() async {
        bridge?.stop()
        bridge = nil
    }
}
