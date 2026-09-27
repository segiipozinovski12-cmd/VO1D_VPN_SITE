import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "VO1D_API_BASE_URL") as? String,
            let url = URL(string: value),
            !value.contains("REPLACE_ME")
        else {
            return URL(string: "https://REPLACE_ME.invalid")!
        }
        return url
    }

    static let tunnelBundleIdentifier = "com.vo1d.vpn.PacketTunnel"
}
