import Foundation
import UIKit

enum APIClientError: LocalizedError {
    case badURL
    case invalidResponse
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .badURL: return "VO1D API URL is not configured."
        case .invalidResponse: return "Invalid server response."
        case .server(let message): return message
        case .decoding: return "Could not read VO1D response."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.keyDecodingStrategy = .convertFromSnakeCase
        return value
    }()

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func activate(key: String) async throws -> ActivateResponse {
        let (deviceID, deviceName) = await deviceContext()
        let body: [String: String] = [
            "key": key,
            "device_id": deviceID,
            "device_name": deviceName
        ]
        return try await request(
            path: "/api/app/activate",
            method: "POST",
            body: body,
            token: nil,
            as: ActivateResponse.self
        )
    }

    func createPayment(
        planDays: Int,
        paymentMethod: String
    ) async throws -> PaymentCreateResponse {
        let (deviceID, deviceName) = await deviceContext()

        return try await request(
            path: "/api/app/payments/create",
            method: "POST",
            body: [
                "plan_days": String(planDays),
                "method": paymentMethod,
                "device_id": deviceID,
                "device_name": deviceName
            ],
            token: nil,
            as: PaymentCreateResponse.self
        )
    }

    func paymentStatus(
        orderID: String,
        pollToken: String
    ) async throws -> PaymentStatusResponse {
        let (deviceID, deviceName) = await deviceContext()

        return try await request(
            path: "/api/app/payments/status",
            method: "POST",
            body: [
                "order_id": orderID,
                "poll_token": pollToken,
                "device_id": deviceID,
                "device_name": deviceName
            ],
            token: nil,
            as: PaymentStatusResponse.self
        )
    }

    private func deviceContext() async -> (String, String) {
        await MainActor.run {
            (
                UIDevice.current.identifierForVendor?.uuidString
                    ?? UUID().uuidString,
                UIDevice.current.name
            )
        }
    }

    func me(token: String) async throws -> AppStateResponse {
        try await request(path: "/api/app/me", token: token, as: AppStateResponse.self)
    }

    func tunnel(token: String, country: String) async throws -> TunnelResponse {
        let escaped = country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? country
        return try await request(
            path: "/api/app/tunnel?country=\(escaped)",
            token: token,
            as: TunnelResponse.self
        )
    }

    func logout(token: String) async {
        _ = try? await request(
            path: "/api/app/logout",
            method: "POST",
            body: [String: String](),
            token: token,
            as: BasicResponse.self
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: String]? = nil,
        token: String?,
        as: Response.Type
    ) async throws -> Response {
        guard let baseURL = AppConfig.apiBaseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIClientError.badURL
        }

        let incoming = URLComponents(string: path)
        components.path = incoming?.path ?? path
        components.query = incoming?.query

        guard let url = components.url else { throw APIClientError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                throw APIClientError.server("No internet connection.")
            case .timedOut:
                throw APIClientError.server("VO1D server timed out. Try again.")
            default:
                throw APIClientError.server("Could not reach the VO1D server.")
            }
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let server = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIClientError.server(server?.message ?? server?.error ?? "VO1D request failed.")
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decoding
        }
    }
}
