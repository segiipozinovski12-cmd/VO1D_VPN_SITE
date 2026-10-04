using System.Net.Http;
using System.Net.Sockets;
using System.Diagnostics;
using VO1D.Vpn.Core;
using VO1D.Vpn.Views;

namespace VO1D.Vpn.Services;

public static class LiveNetworkTests
{
    // The same intentionally public feeds used by bot/community_nodes.py.
    // No production subscription keys are consumed by this test.
    private static readonly string[] Feeds = [
        "https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/by-country/v2ray-base64-GB.txt",
        "https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/by-country/v2ray-base64-DE.txt",
        "https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/by-country/v2ray-base64-NL.txt",
        "https://raw.githubusercontent.com/kort0881/vpn-vless-configs-russia/main/data/githubmirror/ru-sni-local/vless.txt"
    ];
    public static async Task RunAsync(AppViewModel model, string output)
    {
        Directory.CreateDirectory(output);
        using var life = new CancellationTokenSource(TimeSpan.FromMinutes(6));
        using var http = new HttpClient(new HttpClientHandler { UseProxy = false }) { Timeout = TimeSpan.FromSeconds(18) };
        http.DefaultRequestHeaders.UserAgent.ParseAdd("VO1D-Windows-Verification/2.0");
        var apiHealthy = false;
        try { using var health = JsonDocument.Parse(await http.GetStringAsync(Preferences.DefaultApiUrl + "/health", life.Token)); apiHealthy = health.RootElement.GetProperty("ok").GetBoolean(); } catch (HttpRequestException) { }
        var candidates = new List<(string Uri, ProxyProfile Profile, long Ping)>();
        foreach (var feed in Feeds)
        {
            var feedCount = 0;
            try
            {
                var body = await http.GetStringAsync(feed, life.Token);
                if (!body.Contains("://")) body = Encoding.UTF8.GetString(Activation.DecodeBase64(body.Trim()));
                foreach (var line in body.Split('\n').Take(80))
                {
                    try
                    {
                        var profile = ProxyProfile.Parse(line);
                        if (candidates.Any(x => x.Profile.Host == profile.Host && x.Profile.Port == profile.Port)) continue;
                        using var tcp = new TcpClient(); using var deadline = CancellationTokenSource.CreateLinkedTokenSource(life.Token); deadline.CancelAfter(TimeSpan.FromSeconds(1.5));
                        var watch = Stopwatch.StartNew(); await tcp.ConnectAsync(profile.Host, profile.Port, deadline.Token);
                        candidates.Add((line.Trim(), profile, watch.ElapsedMilliseconds));
                        if (++feedCount >= 4) break;
                    }
                    catch (Exception e) when (e is FormatException or NotSupportedException or SocketException or OperationCanceledException or JsonException) { }
                }
            }
            catch (Exception e) when (e is HttpRequestException or TaskCanceledException or FormatException) { }
        }
        var attempts = new List<object>(); var success = false; var exitIp = "";
        foreach (var candidate in candidates.OrderBy(x => x.Ping).Take(8))
        {
            try
            {
                await model.Engine.ConnectAsync(candidate.Uri, true, life.Token);
                success = model.Engine.State == TunnelState.Connected && model.Engine.GuardActive;
                exitIp = model.Engine.PublicIp;
                attempts.Add(new { endpoint = candidate.Profile.Host, candidate.Profile.Port, connected = success, transport = candidate.Profile.XrayOutbound?["streamSettings"]?["network"]?.ToString() ?? candidate.Profile.Protocol });
                if (success) break;
            }
            catch (Exception e) { attempts.Add(new { endpoint = candidate.Profile.Host, candidate.Profile.Port, connected = false, error = e.Message }); }
            finally { await model.Engine.DisconnectAsync(); }
        }
        await File.WriteAllTextAsync(Path.Combine(output, "live-network.json"), JsonSerializer.Serialize(new { success, api_healthy = apiHealthy, public_feed_route_tested = true, production_subscription_tested = false, exit_ip = exitIp, candidates = candidates.Count, attempts }, new JsonSerializerOptions { WriteIndented = true }));
        if (!success) throw new IOException("No public route passed the live system VPN test. See live-network.json.");
    }
}
