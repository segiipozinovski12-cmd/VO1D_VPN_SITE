using System.Text.Json.Nodes;

namespace VO1D.Vpn.Core;

public static class XrayConfig
{
    public static JsonObject VlessOutbound(ProxyProfile profile, Dictionary<string, string> query)
    {
        string Q(string key, string fallback = "") => query.TryGetValue(key, out var value) && value.Length > 0 ? value : fallback;
        var user = new JsonObject { ["id"] = profile.Outbound["uuid"]!.ToString(), ["encryption"] = "none" };
        if (Q("flow").Length > 0) user["flow"] = Q("flow");
        var network = Q("type", "tcp").ToLowerInvariant();
        if (network == "raw") network = "tcp";
        if (network == "h2") network = "http";
        var security = Q("security", "none");
        var stream = new JsonObject { ["network"] = network, ["security"] = security };
        var tls = profile.Outbound["tls"];
        if (security == "reality")
            stream["realitySettings"] = new JsonObject { ["serverName"] = tls!["server_name"]!.ToString(), ["fingerprint"] = Q("fp", "chrome"), ["publicKey"] = Q("pbk"), ["shortId"] = Q("sid"), ["spiderX"] = Q("spx", "/") };
        else if (security == "tls")
        {
            stream["tlsSettings"] = new JsonObject { ["serverName"] = tls!["server_name"]!.ToString(), ["fingerprint"] = Q("fp", "chrome"), ["allowInsecure"] = false };
            if (tls["alpn"] != null) stream["tlsSettings"]!["alpn"] = tls["alpn"]!.DeepClone();
        }
        switch (network)
        {
            case "tcp": break;
            case "ws":
                stream["wsSettings"] = new JsonObject { ["path"] = Q("path", "/"), ["host"] = Q("host") }; break;
            case "grpc":
                stream["grpcSettings"] = new JsonObject { ["serviceName"] = Q("serviceName"), ["multiMode"] = Q("mode") == "multi" }; break;
            case "http":
                stream["httpSettings"] = new JsonObject { ["path"] = Q("path", "/"), ["host"] = new JsonArray(Q("host", profile.Host).Split(',').Select(x => (JsonNode?)JsonValue.Create(x)).ToArray()) }; break;
            case "httpupgrade":
                stream["httpupgradeSettings"] = new JsonObject { ["path"] = Q("path", "/"), ["host"] = Q("host") }; break;
            case "xhttp":
                var mode = Q("mode", "auto");
                if (mode is not ("auto" or "packet-up" or "stream-up" or "stream-one")) throw new FormatException("Неверный режим XHTTP.");
                var xhttp = new JsonObject { ["path"] = Q("path", "/"), ["host"] = Q("host"), ["mode"] = mode };
                if (Q("extra").Length > 0)
                {
                    try { xhttp["extra"] = JsonNode.Parse(Q("extra"))!.AsObject(); }
                    catch (Exception e) when (e is JsonException or InvalidOperationException or NullReferenceException) { throw new FormatException("Некорректные параметры XHTTP extra."); }
                    // A server-provided alternate outbound must not override local routing.
                    if (xhttp["extra"]!["downloadSettings"] != null) throw new NotSupportedException("XHTTP с отдельным downloadSettings пока не поддерживается.");
                }
                stream["xhttpSettings"] = xhttp; break;
            default: throw new NotSupportedException("Неподдерживаемый транспорт Xray: " + network);
        }
        return new JsonObject {
            ["tag"] = "proxy", ["protocol"] = "vless",
            ["settings"] = new JsonObject { ["vnext"] = new JsonArray(new JsonObject { ["address"] = profile.Host, ["port"] = profile.Port, ["users"] = new JsonArray(user) }) },
            ["streamSettings"] = stream
        };
    }

    public static JsonObject Build(ProxyProfile profile, int port, string password) => new() {
        ["log"] = new JsonObject { ["loglevel"] = "none" },
        ["inbounds"] = new JsonArray(new JsonObject {
            ["tag"] = "vo1d-local", ["listen"] = "127.0.0.1", ["port"] = port, ["protocol"] = "socks",
            ["settings"] = new JsonObject { ["auth"] = "password", ["accounts"] = new JsonArray(new JsonObject { ["user"] = "vo1d", ["pass"] = password }), ["udp"] = true }
        }),
        ["outbounds"] = new JsonArray(profile.XrayOutbound?.DeepClone() ?? throw new InvalidOperationException("Нет конфигурации Xray."))
    };

    public static JsonObject LocalOutbound(int port, string password) => new() {
        ["type"] = "socks", ["tag"] = "proxy", ["server"] = "127.0.0.1", ["server_port"] = port,
        ["version"] = "5", ["username"] = "vo1d", ["password"] = password
    };
}
