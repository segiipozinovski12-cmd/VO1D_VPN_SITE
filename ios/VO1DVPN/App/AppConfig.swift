import Foundation

enum AppConfig {
    static let tunnelBundleIdentifier = "com.vo1d.vpn.PacketTunnel"

    private static let fallbackProductionAPI =
        URL(string: "https://sincere-commitment-production-8e4e.up.railway.app")!

    static var apiBaseURL: URL? {
        if let bundled = Bundle.main.object(
            forInfoDictionaryKey: "VO1D_API_BASE_URL"
        ) as? String,
           let url = validatedURL(bundled) {
            return url
        }

        return fallbackProductionAPI
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
}
