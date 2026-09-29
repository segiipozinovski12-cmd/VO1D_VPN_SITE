import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var core: TunnelCoreAdapter = XrayTunnelCore()

    override func startTunnel(
        options: [String : NSObject]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let config = proto.providerConfiguration,
            let uri = config["tunnelURI"] as? String,
            !uri.isEmpty
        else {
            completionHandler(
                NSError(
                    domain: "VO1D.PacketTunnel",
                    code: 400,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Missing VO1D tunnel configuration."
                    ]
                )
            )
            return
        }

        let privacyShield =
            config["privacyShield"] as? Bool ?? false

        let settings = makeNetworkSettings(
            remoteAddress: proto.serverAddress ?? "VO1D",
            privacyShield: privacyShield,
            secureDNS: config["secureDNS"] as? Bool ?? true,
            ipv6Protection: config["ipv6Protection"] as? Bool ?? true
        )

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                completionHandler(error)
                return
            }

            guard let self else {
                completionHandler(
                    NSError(
                        domain: "VO1D.PacketTunnel",
                        code: 500,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "VO1D tunnel provider was released."
                        ]
                    )
                )
                return
            }

            Task {
                do {
                    try await self.core.start(
                        uri: uri,
                        packetFlow: self.packetFlow,
                        privacyShield: privacyShield
                    )
                    completionHandler(nil)
                } catch {
                    await self.core.stop()
                    completionHandler(error)
                }
            }
        }
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)? = nil
    ) {
        guard let command = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        switch command {
        case "stats":
            let snapshot = core.getAndClearStats()
            completionHandler?(try? JSONEncoder().encode(snapshot))
        case "health":
            completionHandler?(Data("ok".utf8))
        default:
            completionHandler?(nil)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        Task { [core] in
            await core.stop()
            completionHandler()
        }
    }

    override func sleep(
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    override func wake() {}

    private func makeNetworkSettings(
        remoteAddress: String,
        privacyShield: Bool,
        secureDNS: Bool,
        ipv6Protection: Bool
    ) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(
            tunnelRemoteAddress: remoteAddress
        )

        let ipv4 = NEIPv4Settings(
            addresses: ["198.18.0.2"],
            subnetMasks: ["255.255.255.252"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        if privacyShield || ipv6Protection {
            let ipv6 = NEIPv6Settings(
                addresses: ["fd00:1::2"],
                networkPrefixLengths: [64]
            )
            ipv6.includedRoutes = [NEIPv6Route.default()]
            settings.ipv6Settings = ipv6
        }

        if privacyShield || secureDNS {
            let dns = NEDNSOverHTTPSSettings(
                servers: ["1.1.1.1", "1.0.0.1"]
            )
            dns.serverURL = URL(
                string: "https://cloudflare-dns.com/dns-query"
            )
            // The empty match domain makes this the resolver for all names.
            dns.matchDomains = [""]
            settings.dnsSettings = dns
        } else {
            settings.dnsSettings = NEDNSSettings(
                servers: ["1.1.1.1", "1.0.0.1"]
            )
        }
        settings.mtu = 1360
        return settings
    }
}
