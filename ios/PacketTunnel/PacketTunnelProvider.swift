import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var core: TunnelCoreAdapter = PlaceholderTunnelCore()

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
                        NSLocalizedDescriptionKey: "Missing tunnel configuration."
                    ]
                )
            )
            return
        }

        let settings = NEPacketTunnelNetworkSettings(
            tunnelRemoteAddress: "VO1D"
        )

        let ipv4 = NEIPv4Settings(
            addresses: ["198.18.0.2"],
            subnetMasks: ["255.255.255.0"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]

        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(
            servers: ["1.1.1.1", "1.0.0.1"]
        )
        settings.mtu = 1400

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                completionHandler(error)
                return
            }

            guard let self else {
                completionHandler(
                    NSError(
                        domain: "VO1D.PacketTunnel",
                        code: 500
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
}
