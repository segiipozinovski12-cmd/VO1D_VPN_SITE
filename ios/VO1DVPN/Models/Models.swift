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
}

struct ServerCollection: Codable {
    let countries: [VO1DServer]
    let totalCountries: Int
}

struct AppStateResponse: Codable {
    let ok: Bool
    let account: AccountState
    let servers: ServerCollection
    let supportUrl: String
}

struct ActivateResponse: Codable {
    let ok: Bool
    let token: String
    let account: AccountState
    let servers: ServerCollection
    let supportUrl: String
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

struct PaymentCreateResponse: Codable {
    let ok: Bool
    let orderId: String
    let pollToken: String
    let paymentId: String
    let payUrl: String
    let status: String
    let amountRub: String
    let planDays: Int
    let method: String
    let test: Bool
}

struct PaymentStatusResponse: Codable {
    let ok: Bool
    let orderId: String
    let status: String
    let amountRub: String
    let planDays: Int
    let method: String
    let token: String?
    let account: AccountState?
    let servers: ServerCollection?
    let supportUrl: String?
}

struct APIErrorEnvelope: Codable {
    let ok: Bool?
    let error: String?
    let message: String?
}


struct LiveStats: Equatable {
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var downloadedMB: Double = 0
    var uploadedMB: Double = 0
    var sessionSeconds: Int = 0
}

extension LiveStats {
    var durationText: String {
        String(format: "%02d:%02d:%02d", sessionSeconds / 3600, (sessionSeconds % 3600) / 60, sessionSeconds % 60)
    }
    var trafficValue: String {
        let total = downloadedMB + uploadedMB
        return String(format: total < 1024 ? "%.0f" : "%.1f", total < 1024 ? total : total / 1024)
    }
    var trafficUnit: String { downloadedMB + uploadedMB < 1024 ? "MB" : "GB" }
}
