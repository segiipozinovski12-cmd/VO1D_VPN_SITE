using System.Net;
using System.Text.Json.Nodes;

namespace VO1D.Vpn.Core;

public sealed class ProxyProfile
{
    public JsonObject Outbound { get; private set; } = new();
    public string Host => Outbound["server"]!.GetValue<string>();
    public int Port => Outbound["server_port"]!.GetValue<int>();
    public string Name { get; private set; } = "Импортированный сервер";
    public string Protocol => Outbound["type"]!.GetValue<string>().ToUpperInvariant();

    public static ProxyProfile Parse(string text, bool allowPlaintextForLocalTest = false)
    {
        text = System.Net.WebUtility.HtmlDecode(text.Trim());
        if (text.Length > 32768) throw new FormatException("VPN-ссылка слишком длинная.");
        if (text.StartsWith("vmess://", StringComparison.OrdinalIgnoreCase)) return ParseVmess(text);
        if (text.StartsWith("ss://", StringComparison.OrdinalIgnoreCase)) return ParseShadowsocks(text);
        if (!Uri.TryCreate(text, UriKind.Absolute, out var uri) || string.IsNullOrEmpty(uri.Host))
            throw new FormatException("Некорректная VPN-ссылка.");
        var q = Query(uri.Query);
        var user = Uri.UnescapeDataString(uri.UserInfo);
        var port = uri.Port > 0 ? uri.Port : 443;
        var o = new JsonObject { ["tag"] = "proxy", ["server"] = uri.DnsSafeHost, ["server_port"] = port, ["connect_timeout"] = "8s" };
        switch (uri.Scheme.ToLowerInvariant())
        {
            case "vless":
                o["type"] = "vless";
                if (!Guid.TryParse(user, out var uuid)) throw new FormatException("В VLESS-ссылке неверный UUID.");
                o["uuid"] = uuid.ToString();
                var encryption = Get(q, "encryption", "none");
                if (encryption != "none") throw new NotSupportedException("Эта ссылка использует новый VLESS Encryption. Выберите другой маршрут.");
                var flow = Get(q, "flow");
                if (flow.Length > 0 && flow != "xtls-rprx-vision") throw new NotSupportedException("Этот режим VLESS пока не поддерживается.");
                if (flow.Length > 0) o["flow"] = flow;
                o["packet_encoding"] = "xudp";
                AddTls(o, q, uri.DnsSafeHost, false);
                AddTransport(o, q);
                break;
            case "trojan":
                o["type"] = "trojan";
                if (string.IsNullOrEmpty(user)) throw new FormatException("В Trojan-ссылке нет пароля.");
                o["password"] = user;
                AddTls(o, q, uri.DnsSafeHost, true);
                AddTransport(o, q);
                break;
            case "hy2": case "hysteria2":
                o["type"] = "hysteria2"; o["password"] = user;
                AddTls(o, q, uri.DnsSafeHost, true);
                if (Get(q, "obfs") == "salamander") o["obfs"] = new JsonObject { ["type"] = "salamander", ["password"] = Get(q, "obfs-password") };
                break;
            default: throw new NotSupportedException("Поддерживаются VLESS, VMess, Trojan, Shadowsocks и Hysteria2.");
        }
        if (o["type"]?.ToString() == "vless" && o["tls"] == null && !allowPlaintextForLocalTest)
            throw new NotSupportedException("Для VLESS нужен TLS или REALITY. Выберите защищённый маршрут.");
        return Create(o, Uri.UnescapeDataString(uri.Fragment.TrimStart('#')));
    }

    private static ProxyProfile ParseVmess(string text)
    {
        JsonObject data;
        try { data = JsonNode.Parse(Encoding.UTF8.GetString(Activation.DecodeBase64(text[8..].Split('#')[0])))!.AsObject(); }
        catch (Exception e) when (e is FormatException or JsonException or InvalidOperationException) { throw new FormatException("VMess-ссылка повреждена."); }
        string Str(string key, string fallback = "") => data[key]?.ToString() ?? fallback;
        if (!Guid.TryParse(Str("id"), out var uuid) || !int.TryParse(Str("port"), out var port)) throw new FormatException("Неверные параметры VMess.");
        var o = new JsonObject { ["type"] = "vmess", ["tag"] = "proxy", ["server"] = Str("add"), ["server_port"] = port, ["uuid"] = uuid.ToString(), ["security"] = Str("scy", "auto"), ["alter_id"] = int.TryParse(Str("aid"), out var aid) ? aid : 0, ["connect_timeout"] = "8s" };
        var q = new Dictionary<string, string> { ["security"] = Str("tls", "none"), ["sni"] = Str("sni", Str("host", Str("add"))), ["type"] = Str("net", "tcp"), ["host"] = Str("host"), ["path"] = Str("path"), ["serviceName"] = Str("path").TrimStart('/'), ["alpn"] = Str("alpn") };
        AddTls(o, q, Str("add"), false); AddTransport(o, q);
        return Create(o, Str("ps"));
    }

    private static ProxyProfile ParseShadowsocks(string text)
    {
        var raw = text[5..];
        var split = raw.Split('#', 2);
        var name = split.Length == 2 ? Uri.UnescapeDataString(split[1]) : "Shadowsocks";
        raw = split[0];
        if (!raw.Contains('@')) raw = Encoding.UTF8.GetString(Activation.DecodeBase64(raw));
        if (!Uri.TryCreate("ss://" + raw, UriKind.Absolute, out var uri) || uri.Port < 1) throw new FormatException("Shadowsocks-ссылка повреждена.");
        if (Query(uri.Query).ContainsKey("plugin")) throw new NotSupportedException("Shadowsocks-плагины не поддерживаются. Выберите другой маршрут.");
        var auth = Uri.UnescapeDataString(uri.UserInfo);
        if (!auth.Contains(':')) auth = Encoding.UTF8.GetString(Activation.DecodeBase64(auth));
        var parts = auth.Split(':', 2);
        if (parts.Length != 2 || parts.Any(string.IsNullOrEmpty)) throw new FormatException("Неверный пароль Shadowsocks.");
        return Create(new JsonObject { ["type"] = "shadowsocks", ["tag"] = "proxy", ["server"] = uri.DnsSafeHost, ["server_port"] = uri.Port, ["method"] = parts[0], ["password"] = parts[1], ["connect_timeout"] = "8s" }, name);
    }

    private static ProxyProfile Create(JsonObject outbound, string name)
    {
        var host = outbound["server"]?.ToString();
        var port = outbound["server_port"]?.GetValue<int>() ?? 0;
        if (string.IsNullOrWhiteSpace(host) || host.Any(char.IsControl) || port is < 1 or > 65535) throw new FormatException("Неверный адрес VPN-сервера.");
        return new() { Outbound = outbound, Name = string.IsNullOrWhiteSpace(name) ? "Импортированный сервер" : name[..Math.Min(name.Length, 100)] };
    }

    private static void AddTls(JsonObject outbound, Dictionary<string, string> q, string host, bool defaultTls)
    {
        var security = Get(q, "security", defaultTls ? "tls" : "none");
        if (security is "none" or "") return;
        if (security is not ("tls" or "reality")) throw new NotSupportedException("Этот режим TLS не поддерживается.");
        if (Get(q, "allowInsecure") == "1" || Get(q, "insecure") == "1")
            throw new NotSupportedException("Ссылка отключает проверку TLS-сертификата. Нужен безопасный маршрут.");
        var tls = new JsonObject { ["enabled"] = true, ["server_name"] = Get(q, "sni", Get(q, "serverName", host)) };
        var alpn = Get(q, "alpn");
        if (alpn.Length > 0) tls["alpn"] = new JsonArray(alpn.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(x => (JsonNode?)JsonValue.Create(x)).ToArray());
        if (outbound["type"]?.ToString() != "hysteria2")
            tls["utls"] = new JsonObject { ["enabled"] = true, ["fingerprint"] = Get(q, "fp", "chrome") };
        if (security == "reality")
        {
            var key = Get(q, "pbk");
            if (string.IsNullOrEmpty(key)) throw new FormatException("В REALITY-ссылке нет публичного ключа.");
            tls["reality"] = new JsonObject { ["enabled"] = true, ["public_key"] = key, ["short_id"] = Get(q, "sid") };
        }
        outbound["tls"] = tls;
    }

    private static void AddTransport(JsonObject outbound, Dictionary<string, string> q)
    {
        var type = Get(q, "type", "tcp").ToLowerInvariant();
        if (type is "tcp" or "raw" or "")
        {
            if (Get(q, "headerType", "none") != "none") throw new NotSupportedException("TCP HTTP camouflage не поддерживается. Выберите другой маршрут.");
            return;
        }
        JsonObject t;
        switch (type)
        {
            case "ws":
                var path = Get(q, "path", "/");
                var host = Get(q, "host");
                t = new() { ["type"] = "ws", ["path"] = path.Split('?')[0] };
                var query = Query(path.Contains('?') ? path[(path.IndexOf('?') + 1)..] : "");
                if (int.TryParse(Get(query, "ed"), out var early) && early > 0) { t["max_early_data"] = early; t["early_data_header_name"] = "Sec-WebSocket-Protocol"; }
                else t["path"] = path;
                if (host.Length > 0) t["headers"] = new JsonObject { ["Host"] = host };
                break;
            case "grpc": t = new() { ["type"] = "grpc", ["service_name"] = Get(q, "serviceName") }; break;
            case "http": case "h2":
                t = new() { ["type"] = "http", ["path"] = Get(q, "path", "/") };
                if (Get(q, "host").Length > 0) t["host"] = new JsonArray(Get(q, "host").Split(',').Select(x => (JsonNode?)JsonValue.Create(x)).ToArray());
                break;
            case "httpupgrade": t = new() { ["type"] = "httpupgrade", ["host"] = Get(q, "host"), ["path"] = Get(q, "path", "/") }; break;
            default: throw new NotSupportedException($"Транспорт {type} пока не поддерживается. Приложение попробует другой маршрут.");
        }
        outbound["transport"] = t;
    }

    public static Dictionary<string, string> Query(string text)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in text.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = item.Split('=', 2);
            result[Uri.UnescapeDataString(parts[0])] = parts.Length == 2 ? Uri.UnescapeDataString(parts[1]) : "";
        }
        return result;
    }
    private static string Get(Dictionary<string, string> q, string key, string fallback = "") => q.TryGetValue(key, out var value) && value.Length > 0 ? value : fallback;
}
