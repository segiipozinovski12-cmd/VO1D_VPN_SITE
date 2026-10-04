using System.Text;
using System.Text.Json;
using VO1D.Vpn.Core;

var output = args.Length > 0 ? args[0] : Path.Combine(Path.GetTempPath(), "vo1d-config-tests");
Directory.CreateDirectory(output);
Directory.CreateDirectory(Path.Combine(output, "xray"));
int checks = 0;
void Check(bool condition, string name) { if (!condition) throw new Exception(name); checks++; }
void Reject(Action action, string name) { try { action(); } catch (Exception e) when (e is FormatException or NotSupportedException) { checks++; return; } throw new Exception("Did not reject: " + name); }
string B64(string text) => Convert.ToBase64String(Encoding.UTF8.GetBytes(text)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
const string uuid = "bf000d23-0752-40b4-affe-68f7707a9661";
const string pubkey = "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0";
var activation = Activation.Resolve($"VO1D1.{B64("https://example.com")}.VOID-AAAA-BBBB-CCCC", "");
Check(activation.ApiUrl == "https://example.com" && activation.Key == "VOID-AAAA-BBBB-CCCC", "iOS activation envelope compatibility");
Reject(() => Activation.Resolve("VOID-AAAA-BBBB-CCCC", "http://example.com"), "HTTP API");
Reject(() => Activation.Resolve("VOID-AAAA-BBBB-CCCC", "https://REPLACE_ME.invalid"), "placeholder API");
Reject(() => Activation.Resolve("VO1D1.bad.void", ""), "corrupt envelope");
Reject(() => Activation.Resolve("VOID-AAAA-BBBB-CCCC", "https://user:pass@example.com"), "credentialed API URL");
var fixtures = new Dictionary<string,string> {
    ["vless-reality"] = $"vless://{uuid}@192.0.2.1:443?security=reality&sni=example.com&pbk={pubkey}&sid=abcd&flow=xtls-rprx-vision&type=tcp#Test",
    ["vless-ws"] = $"vless://{uuid}@example.com:443?security=tls&sni=example.com&type=ws&host=example.com&path=%2Fvpn%3Fed%3D2048",
    ["vless-grpc"] = $"vless://{uuid}@example.com:443?security=tls&type=grpc&serviceName=service",
    ["vless-xhttp-reality"] = $"vless://{uuid}@192.0.2.1:443?security=reality&sni=example.com&pbk={pubkey}&sid=abcd&type=xhttp&path=%2Fxhttp-proxy&mode=auto&extra=%7B%22noSSEHeader%22%3Atrue%2C%22scMaxEachPostBytes%22%3A1000000%7D#RU",
    ["trojan"] = "trojan://secret%3Acolon@example.com:443?security=tls&sni=example.com#Trojan",
    ["hy2"] = "hysteria2://test@example.com:443?sni=example.com&obfs=salamander&obfs-password=test",
    ["ss"] = "ss://" + B64("aes-256-gcm:secret:colon") + "@192.0.2.2:8388#SS",
    ["vmess"] = "vmess://" + B64(JsonSerializer.Serialize(new { v="2", ps="Test", add="example.com", port="443", id=uuid, aid="0", scy="auto", net="ws", path="/vpn", host="example.com", tls="tls", sni="example.com" }))
};
foreach (var (name, uri) in fixtures)
{
    var p = ProxyProfile.Parse(uri);
    Check(p.Port > 0 && p.Host.Length > 0, name + " endpoint");
    var config = TunnelConfig.Build(p, 29880, 29881, "test-secret", "test-password", outbound: p.XrayOutbound == null ? null : XrayConfig.LocalOutbound(29882, "xray-test"));
    Check(config["route"]!["final"]!.ToString() == "proxy", name + " no direct fallback");
    File.WriteAllText(Path.Combine(output, name + ".json"), config.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    if (p.XrayOutbound != null) File.WriteAllText(Path.Combine(output, "xray", name + ".json"), XrayConfig.Build(p, 29882, "xray-test").ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
}
var ws = ProxyProfile.Parse(fixtures["vless-ws"]);
Check(ws.Outbound["transport"]!["path"]!.ToString() == "/vpn", "WS path / early data split");
Check(ws.Outbound["transport"]!["max_early_data"]!.GetValue<int>() == 2048, "WS early data");
Check(ProxyProfile.Parse(fixtures["trojan"]).Outbound["password"]!.ToString() == "secret:colon", "percent encoded password");
Check(ProxyProfile.Parse(fixtures["ss"]).Outbound["password"]!.ToString() == "secret:colon", "SS password containing colon");
Reject(() => ProxyProfile.Parse($"vless://{uuid}@example.com:443?security=none"), "unencrypted VLESS");
Reject(() => ProxyProfile.Parse($"vless://{uuid}@example.com:443?security=tls&allowInsecure=1"), "insecure TLS");
Reject(() => ProxyProfile.Parse($"vless://{uuid}@example.com:443?security=reality"), "missing REALITY key");
var ru = ProxyProfile.Parse(fixtures["vless-xhttp-reality"]);
Check(ru.XrayOutbound!["streamSettings"]!["network"]!.ToString() == "xhttp", "pinned RU uses actual Xray XHTTP");
Check(ru.XrayOutbound["streamSettings"]!["xhttpSettings"]!["extra"]!["noSSEHeader"]!.GetValue<bool>(), "pinned RU extra retained");
Check(ru.XrayOutbound["streamSettings"]!["xhttpSettings"]!["path"]!.ToString() == "/xhttp-proxy", "pinned RU path retained");
ru.SetEndpoint("192.0.2.20");
Check(ru.XrayOutbound["settings"]!["vnext"]![0]!["address"]!.ToString() == "192.0.2.20", "Xray endpoint resolved before TUN");
Check(TunnelConfig.Build(ru, 29880, 29881, "secret", "pass", outbound: XrayConfig.LocalOutbound(29882,"pass"))["inbounds"]![0]!["route_exclude_address"]![0]!.ToString() == "192.0.2.20/32", "Xray endpoint excluded from capture loop");
Reject(() => ProxyProfile.Parse($"vless://{uuid}@example.com:443?security=tls&type=xhttp&extra=broken"), "invalid XHTTP extra");
Reject(() => ProxyProfile.Parse($"vless://{uuid}@example.com:443?security=tls&type=xhttp&mode=unknown"), "invalid XHTTP mode");
Check(new Preferences().ApiUrl == "https://sincere-commitment-production-8e4e.up.railway.app", "same live backend as reference iOS");
Reject(() => ProxyProfile.Parse("vless://bad@example.com:443?security=tls"), "invalid UUID");
Reject(() => ProxyProfile.Parse("https://example.com"), "unsupported scheme");
var tun = TunnelConfig.Build(ProxyProfile.Parse(fixtures["vless-reality"]), 29880, 29881, "secret", "password");
Check(tun["inbounds"]![0]!["address"]!.AsArray().Count == 2, "IPv4 and IPv6 TUN");
Check(tun["dns"]!["servers"]![0]!["detour"]!.ToString() == "proxy", "DNS over VPN");
Check(tun["inbounds"]![0]!["strict_route"]!.GetValue<bool>(), "Windows strict DNS route");
Check(tun["experimental"]!["clash_api"]!["secret"]!.ToString() == "secret", "local API authenticated");
Check(tun["log"]!["disabled"]!.GetValue<bool>(), "no connection logging");
Console.WriteLine($"{checks} protocol / activation / routing checks passed.");
