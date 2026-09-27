import Foundation
import NetworkExtension

protocol TunnelCoreAdapter: AnyObject {
    func start(uri: String, packetFlow: NEPacketTunnelFlow) async throws
    func stop() async
}

enum TunnelCoreError: LocalizedError {
    case coreNotLinked

    var errorDescription: String? {
        switch self {
        case .coreNotLinked:
            return "VO1D packet-tunnel core is not linked yet."
        }
    }
}

final class PlaceholderTunnelCore: TunnelCoreAdapter {
    func start(uri: String, packetFlow: NEPacketTunnelFlow) async throws {
        _ = uri
        _ = packetFlow
        throw TunnelCoreError.coreNotLinked
    }

    func stop() async {}
}
