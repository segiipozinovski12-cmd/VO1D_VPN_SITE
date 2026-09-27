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

        let settings = makeNetworkSettings(
            remoteAddress: proto.serverAddress ?? "VO1D"
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
                        packetFlow: self.packetFlow
                    )
                    completionHandler(nil)
                } catch {
                    completionHandler(error)
                }
            }
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
        remoteAddress: String
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

        let ipv6 = NEIPv6Settings(
            addresses: ["fd00:1::2"],
            networkPrefixLengths: [64]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        settings.dnsSettings = NEDNSSettings(
            servers: [
                "1.1.1.1",
                "2606:4700:4700::1111"
            ]
        )
        settings.mtu = 1360
        return settings
    }
}
