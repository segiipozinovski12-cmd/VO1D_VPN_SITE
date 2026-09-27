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

    private let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.keyDecodingStrategy = .convertFromSnakeCase
        return value
    }()

    private init() {}

    func activate(key: String) async throws -> ActivateResponse {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let body: [String: String] = [
            "key": key,
            "device_id": deviceID,
            "device_name": UIDevice.current.name
        ]
        return try await request(
            path: "/api/app/activate",
            method: "POST",
            body: body,
            token: nil,
            as: ActivateResponse.self
        )
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

        let (data, response) = try await URLSession.shared.data(for: request)
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
