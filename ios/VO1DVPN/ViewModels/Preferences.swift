import Foundation
import Combine

@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var nickname: String { didSet { save(nickname, "nickname") } }
    @Published var avatar: String { didSet { save(avatar, "avatar") } }
    @Published var autoConnect: Bool { didSet { save(autoConnect, "autoconnect") } }
    @Published var autoFastest: Bool { didSet { save(autoFastest, "autoFastest") } }
    @Published var privacyShield: Bool {
        didSet {
            save(privacyShield, "privacyShield")
            if privacyShield {
                killSwitch = true
                secureDNS = true
                ipv6Protection = true
            }
        }
    }
    @Published var killSwitch: Bool { didSet { save(killSwitch, "killswitch") } }
    @Published var secureDNS: Bool { didSet { save(secureDNS, "secureDNS") } }
    @Published var ipv6Protection: Bool { didSet { save(ipv6Protection, "ipv6Protection") } }
    @Published var livePing: Bool { didSet { save(livePing, "showLivePing") } }
    @Published var reduceAnimations: Bool { didSet { save(reduceAnimations, "reduceAnimations") } }
    @Published var compactServers: Bool { didSet { save(compactServers, "compactServers") } }
    @Published var haptics: Bool { didSet { save(haptics, "haptics") } }
    static let avatars = ["person.fill", "person.crop.square", "sparkle", "moon.stars.fill", "paperplane.fill", "bolt.fill"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, fallback: Bool) -> Bool {
            defaults.object(forKey: "vo1d.\(key)") as? Bool ?? fallback
        }
        nickname = defaults.string(forKey: "vo1d.nickname") ?? "VO1D USER"
        let storedAvatar = defaults.string(forKey: "vo1d.avatar") ?? "person.fill"
        avatar = Self.avatars.contains(storedAvatar) ? storedAvatar : "person.fill"
        autoConnect = bool("autoconnect", fallback: false)
        autoFastest = bool("autoFastest", fallback: true)
        privacyShield = bool("privacyShield", fallback: true)
        killSwitch = bool("killswitch", fallback: true)
        secureDNS = bool("secureDNS", fallback: true)
        ipv6Protection = bool("ipv6Protection", fallback: true)
        livePing = bool("showLivePing", fallback: true)
        reduceAnimations = bool("reduceAnimations", fallback: false)
        compactServers = bool("compactServers", fallback: false)
        haptics = bool("haptics", fallback: true)
    }
    var connectionOptions: ConnectionOptions {
        ConnectionOptions(
            privacyShield: privacyShield,
            killSwitch: privacyShield || killSwitch,
            secureDNS: privacyShield || secureDNS,
            ipv6Protection: privacyShield || ipv6Protection
        )
    }
    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: "vo1d.\(key)") }
}
