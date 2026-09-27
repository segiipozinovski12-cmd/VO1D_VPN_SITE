import Foundation

struct AccountState: Codable {
    let id: Int64
    let active: Bool
    let banned: Bool
    let until: Int64
    let remainingSeconds: Int64
}

struct VO1DServer: Codable, Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let flag: String
    let label: String
    let nodes: Int
    let probeHost: String
    let probePort: Int
    let protocolName: String

    enum CodingKeys: String, CodingKey {
        case id, code, name, flag, label, nodes
        case probeHost = "probe_host"
        case probePort = "probe_port"
        case protocolName = "protocol"
    }
}

struct ServerCollection: Codable {
    let countries: [VO1DServer]
    let totalCountries: Int
}

struct AppStateResponse: Codable {
    let ok: Bool
    let account: AccountState
    let servers: ServerCollection
    let supportURL: String
}

struct ActivateResponse: Codable {
    let ok: Bool
    let token: String
    let account: AccountState
    let servers: ServerCollection
    let supportURL: String
}

struct TunnelResponse: Codable {
    let ok: Bool
    let country: String
    let uri: String
    let label: String
    let issuedAt: Int64
    let expiresAt: Int64
}

struct BasicResponse: Codable {
    let ok: Bool
}

struct APIErrorEnvelope: Codable {
    let ok: Bool?
    let error: String?
    let message: String?
}
