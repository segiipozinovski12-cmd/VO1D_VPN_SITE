using System.Text.Json.Nodes;

namespace VO1D.Vpn.Core;

public static class TunnelConfig
{
    public const string InterfaceName = "VO1D";
    public static JsonObject Build(ProxyProfile profile, int proxyPort, int apiPort, string secret, string proxyPassword, bool tun = true, JsonObject? outbound = null)
    {
        var inbounds = new JsonArray();
        if (tun) inbounds.Add(new JsonObject {
            ["type"] = "tun", ["tag"] = "tun-in", ["interface_name"] = InterfaceName,
            ["address"] = new JsonArray("172.31.255.1/30", "fdfe:dcba:9876::1/126"),
            ["mtu"] = 1400, ["auto_route"] = true, ["strict_route"] = true, ["stack"] = "mixed"
        });
        inbounds.Add(new JsonObject { ["type"] = "mixed", ["tag"] = "probe-in", ["listen"] = "127.0.0.1", ["listen_port"] = proxyPort, ["users"] = new JsonArray(new JsonObject { ["username"] = "vo1d", ["password"] = proxyPassword }) });
        if (tun && profile.XrayOutbound != null && System.Net.IPAddress.TryParse(profile.Host, out var endpoint) && !System.Net.IPAddress.IsLoopback(endpoint))
            inbounds[0]!["route_exclude_address"] = new JsonArray(endpoint + (endpoint.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork ? "/32" : "/128"));
        return new JsonObject {
            ["log"] = new JsonObject { ["disabled"] = true },
            ["dns"] = new JsonObject {
                ["servers"] = new JsonArray(new JsonObject { ["type"] = "https", ["tag"] = "dns-protected", ["server"] = "1.1.1.1", ["path"] = "/dns-query", ["detour"] = "proxy" }),
                ["final"] = "dns-protected", ["strategy"] = "prefer_ipv4"
            },
            ["inbounds"] = inbounds,
            ["outbounds"] = new JsonArray((outbound ?? profile.Outbound).DeepClone()),
            ["route"] = new JsonObject {
                ["auto_detect_interface"] = true,
                ["rules"] = new JsonArray(new JsonObject { ["action"] = "sniff" }, new JsonObject { ["protocol"] = "dns", ["action"] = "hijack-dns" }),
                ["final"] = "proxy", ["default_domain_resolver"] = "dns-protected"
            },
            ["experimental"] = new JsonObject { ["clash_api"] = new JsonObject { ["external_controller"] = $"127.0.0.1:{apiPort}", ["secret"] = secret, ["access_control_allow_origin"] = new JsonArray("http://127.0.0.1") } }
        };
    }
}
