import Foundation

enum AppConfig {
    private static let storedBaseURLKey = "vo1d.apiBaseURL"
    static let tunnelBundleIdentifier = "com.vo1d.vpn.PacketTunnel"

    static var apiBaseURL: URL? {
        if let stored = UserDefaults.standard.string(forKey: storedBaseURLKey),
           let url = validatedURL(stored) {
            return url
        }

        if let bundled = Bundle.main.object(
            forInfoDictionaryKey: "VO1D_API_BASE_URL"
        ) as? String,
           let url = validatedURL(bundled) {
            return url
        }

        return nil
    }

    /// Accepts either a normal VOID-... key or the full activation string
    /// produced by the Telegram bot:
    /// VO1D1.<base64url-backend>.<VOID-key>
    static func resolveActivation(_ input: String) throws -> String {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.hasPrefix("VO1D1.") {
            let parts = clean.split(separator: ".", maxSplits: 2).map(String.init)
            guard parts.count == 3,
                  let urlData = decodeBase64URL(parts[1]),
                  let rawURL = String(data: urlData, encoding: .utf8),
                  let url = validatedURL(rawURL) else {
                throw APIClientError.badURL
            }

            UserDefaults.standard.set(
                url.absoluteString,
                forKey: storedBaseURLKey
            )
            return parts[2]
        }

        guard apiBaseURL != nil else {
            throw APIClientError.badURL
        }
        return clean
    }

    private static func validatedURL(_ value: String) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              !clean.contains("REPLACE_ME"),
              let url = URL(string: clean),
              url.scheme == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
