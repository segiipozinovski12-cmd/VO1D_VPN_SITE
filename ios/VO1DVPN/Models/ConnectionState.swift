import Foundation

enum ConnectionPhase: String {
    case ready = "READY", preparing = "PREPARING", routing = "ROUTING"
    case securing = "SECURING", connected = "CONNECTED", disconnecting = "DISCONNECTING"
    case switching = "SWITCHING ROUTE", failed = "CONNECTION FAILED"
    var isBusy: Bool {
        switch self {
        case .preparing, .routing, .securing, .disconnecting, .switching: return true
        default: return false
        }
    }
}

struct ConnectionOptions: Equatable {
    var stealthMode: Bool
    var privacyShield: Bool
    var killSwitch: Bool
    var secureDNS: Bool
    var ipv6Protection: Bool
}

/// Stable tie-breaking prevents equal-ping routes shuffling on each refresh.
enum ServerRanking {
    static func sorted(_ servers: [VO1DServer], pings: [String: Int]) -> [VO1DServer] {
        servers.sorted {
            let lhs = pings[$0.code] ?? Int.max
            let rhs = pings[$1.code] ?? Int.max
            return lhs == rhs ? $0.code < $1.code : lhs < rhs
        }
    }
    static func fastest(_ servers: [VO1DServer], pings: [String: Int]) -> VO1DServer? {
        sorted(servers.filter { (pings[$0.code] ?? 0) > 0 }, pings: pings).first
    }
}
