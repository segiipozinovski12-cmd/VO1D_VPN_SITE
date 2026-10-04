using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text.Json.Nodes;
using VO1D.Vpn.Core;
using VO1D.Vpn.Views;

namespace VO1D.Vpn.Services;

public static class SmokeTests
{
    // This mode uses an ephemeral local VLESS server and a destination that
    // cannot be reached directly. It neither redeems keys nor uses production
    // credentials. Screenshots containing the test route are labelled TEST.
    public static async Task RunAsync(AppViewModel model, MainWindow window, string output)
    {
        Directory.CreateDirectory(output); window.SaveScreenshot(Path.Combine(output, "boot.png")); await window.RevealAsync(); await Task.Delay(700);
        window.SaveScreenshot(Path.Combine(output, "login.png"));
        var core = RuntimeAssets.Ensure();
        var serverPort = VpnEngine.FreePort(); var httpPort = VpnEngine.FreePort();
        var marker = "VO1D_TUN_" + Guid.NewGuid().ToString("N");
        using var httpServer = new HttpListener(); httpServer.Prefixes.Add($"http://127.0.0.1:{httpPort}/"); httpServer.Start();
        using var life = new CancellationTokenSource();
        var serve = Task.Run(async () => { while (!life.IsCancellationRequested) { try { var ctx = await httpServer.GetContextAsync().WaitAsync(life.Token); var bytes = Encoding.UTF8.GetBytes(marker); ctx.Response.ContentLength64 = bytes.Length; await ctx.Response.OutputStream.WriteAsync(bytes); ctx.Response.Close(); } catch (OperationCanceledException) { return; } } });
        var uuid = Guid.NewGuid().ToString();
        var serverConfig = new JsonObject {
            ["log"] = new JsonObject { ["disabled"] = true },
            ["inbounds"] = new JsonArray(new JsonObject { ["type"] = "vless", ["listen"] = "127.0.0.1", ["listen_port"] = serverPort, ["users"] = new JsonArray(new JsonObject { ["uuid"] = uuid }) }),
            ["outbounds"] = new JsonArray(new JsonObject { ["type"] = "direct", ["tag"] = "direct" }),
            ["route"] = new JsonObject { ["rules"] = new JsonArray(new JsonObject { ["ip_cidr"] = new JsonArray("198.18.0.2/32"), ["action"] = "route", ["outbound"] = "direct", ["override_address"] = "127.0.0.1", ["override_port"] = httpPort }), ["final"] = "direct" }
        };
        var configPath = Path.Combine(output, "test-server.json"); await File.WriteAllTextAsync(configPath, serverConfig.ToJsonString());
        using var localCore = Process.Start(new ProcessStartInfo(core) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = RuntimeAssets.Root, ArgumentList = { "run", "-c", configPath } }) ?? throw new IOException("Test server did not launch");
        using var serverJob = new ProcessJob(); serverJob.Add(localCore);
        try
        {
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(120));
            var ct = timeout.Token;
            var physicalIndex = NativeWindows.BestInterface(IPAddress.Parse("1.1.1.1"));
            var physical = NetworkInterface.GetAllNetworkInterfaces().First(x => x.NetworkInterfaceType != NetworkInterfaceType.Loopback && x.GetIPProperties().GetIPv4Properties()?.Index == physicalIndex);
            var physicalIp = physical.GetIPProperties().UnicastAddresses.First(x => x.Address.AddressFamily == AddressFamily.InterNetwork).Address;
            await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, false, ct);
            await Task.Delay(700, ct);
            if (localCore.HasExited) throw new IOException("Local VLESS server exited");
            var uri = $"vless://{uuid}@127.0.0.1:{serverPort}?security=none&type=tcp#LOCAL%20TEST";
            model.LoadTestRoute(uri);
            await model.Engine.ConnectAsync(uri, true, ct, new Uri($"http://198.18.0.2:{httpPort}/"), marker);
            Assert(model.Engine.State == TunnelState.Connected, "Connected state requires working data plane");
            Assert(model.Engine.GuardActive, "Native WFP kill switch enabled");
            Assert(NativeWindows.TunIndex() == NativeWindows.BestInterface(IPAddress.Parse("198.18.0.2")), "IPv4 default route enters VO1D TUN");
            Assert(NativeWindows.TunIndex() == NativeWindows.BestInterface(IPAddress.Parse("2606:4700:4700::1111")), "IPv6 default route enters VO1D TUN");
            await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, true, ct);
            await Task.Delay(1200, ct); window.SaveScreenshot(Path.Combine(output, "connected.png"));
            model.Page = "servers"; await Task.Delay(400, ct); window.SaveScreenshot(Path.Combine(output, "servers.png"));
            model.Page = "settings"; await Task.Delay(400, ct); window.SaveScreenshot(Path.Combine(output, "settings.png"));
            model.Page = "profile"; await Task.Delay(400, ct); window.SaveScreenshot(Path.Combine(output, "profile.png"));
            model.Engine.AbortCoreForTest();
            for (var i = 0; i < 20 && model.Engine.State != TunnelState.Blocked; i++) await Task.Delay(200, ct);
            Assert(model.Engine.State == TunnelState.Blocked && model.Engine.GuardActive, "Core crash leaves kill switch armed");
            await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, true, ct);
            await model.Engine.DisconnectAsync();
            Assert(!model.Engine.GuardActive, "Explicit disconnect removes dynamic WFP rules");
            await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, false, ct);
            Assert(NativeWindows.BestInterface(IPAddress.Parse("1.1.1.1")) != NativeWindows.TunIndex() || NativeWindows.TunIndex() == 0, "Physical route restored");
            Assert(!Directory.EnumerateFiles(UserStore.Root, "tunnel-*.json").Any(), "Tunnel credentials removed after disconnect");
            var xhttpPort = VpnEngine.FreePort();
            var xhttpServer = new JsonObject {
                ["log"] = new JsonObject { ["loglevel"] = "none" },
                ["inbounds"] = new JsonArray(new JsonObject {
                    ["listen"] = "127.0.0.1", ["port"] = xhttpPort, ["protocol"] = "vless",
                    ["settings"] = new JsonObject { ["clients"] = new JsonArray(new JsonObject { ["id"] = uuid }), ["decryption"] = "none" },
                    ["streamSettings"] = new JsonObject { ["network"] = "xhttp", ["security"] = "none", ["xhttpSettings"] = new JsonObject { ["path"] = "/vo1d-xhttp", ["mode"] = "auto" } }
                }),
                ["outbounds"] = new JsonArray(new JsonObject { ["protocol"] = "freedom", ["settings"] = new JsonObject { ["redirect"] = $"127.0.0.1:{httpPort}" } })
            };
            var xhttpPath = Path.Combine(output, "test-xhttp.json"); await File.WriteAllTextAsync(xhttpPath, xhttpServer.ToJsonString(), ct);
            using var xhttpCore = Process.Start(new ProcessStartInfo(Path.Combine(RuntimeAssets.Root, "xray.exe")) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = RuntimeAssets.Root, ArgumentList = { "run", "-config", xhttpPath } }) ?? throw new IOException("XHTTP server did not launch");
            serverJob.Add(xhttpCore);
            try
            {
                await Task.Delay(700, ct);
                model.Page = "home";
                await model.Engine.ConnectAsync($"vless://{uuid}@127.0.0.1:{xhttpPort}?security=none&type=xhttp&path=%2Fvo1d-xhttp&mode=auto", true, ct, new Uri($"http://198.18.0.2:{httpPort}/"), marker);
                Assert(model.Engine.State == TunnelState.Connected, "XHTTP data plane verified through actual Xray + TUN");
                await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, true, ct);
                await Task.Delay(600, ct); window.SaveScreenshot(Path.Combine(output, "xhttp-connected.png")); window.SaveVortexScreenshot(Path.Combine(output, "vortex-a.png"));
                await Task.Delay(600, ct); window.SaveScreenshot(Path.Combine(output, "motion-frame.png")); window.SaveVortexScreenshot(Path.Combine(output, "vortex-b.png"));
                Assert(!File.ReadAllBytes(Path.Combine(output, "vortex-a.png")).SequenceEqual(File.ReadAllBytes(Path.Combine(output, "vortex-b.png"))), "Connected vortex animates between real frames");
                model.Engine.AbortXrayForTest();
                for (var i = 0; i < 20 && model.Engine.State != TunnelState.Blocked; i++) await Task.Delay(200, ct);
                Assert(model.Engine.State == TunnelState.Blocked && model.Engine.GuardActive, "Xray crash leaves kill switch armed");
                await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, true, ct);
                await model.Engine.DisconnectAsync();
                await CheckPhysicalConnectionAsync(physicalIp, physicalIndex, false, ct);
                Assert(!Directory.EnumerateFiles(UserStore.Root, "xray-*.json").Any(), "Xray credentials removed after disconnect");
            }
            finally { if (!xhttpCore.HasExited) xhttpCore.Kill(true); await model.Engine.DisconnectAsync(); File.Delete(xhttpPath); }
            await File.WriteAllTextAsync(Path.Combine(output, "results.json"), JsonSerializer.Serialize(new { success = true, executable_started = true, local_vless_data_plane = true, xray_xhttp_data_plane = true, ipv4_tun = true, ipv6_tun = true, wfp_bypass_blocked = true, core_crash_blocks_traffic = true, xray_crash_blocks_traffic = true, disconnect_restores_network = true, animations_rendered = true, production_endpoint_tested = false }, new JsonSerializerOptions { WriteIndented = true }), ct);
        }
        finally
        {
            life.Cancel(); httpServer.Stop();
            if (!localCore.HasExited) localCore.Kill(true);
            await model.Engine.DisconnectAsync();
            try { File.Delete(configPath); } catch { }
        }
    }
    private static async Task CheckPhysicalConnectionAsync(IPAddress source, uint index, bool shouldBlock, CancellationToken ct)
    {
        using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        socket.Bind(new IPEndPoint(source, 0));
        // IP_UNICAST_IF = 31 in the Windows SDK; .NET 8 does not expose a
        // named SocketOptionName value for this Windows-only option.
        socket.SetSocketOption(SocketOptionLevel.IP, (SocketOptionName)31, IPAddress.HostToNetworkOrder((int)index));
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(TimeSpan.FromSeconds(7));
        try { await socket.ConnectAsync(new IPEndPoint(IPAddress.Parse("1.1.1.1"), 443), timeout.Token); Assert(!shouldBlock, "Physical-interface bypass must be blocked"); }
        catch (Exception e) when (e is SocketException or OperationCanceledException) { if (!shouldBlock) throw new IOException("Physical internet connection was not restored / baseline failed", e); }
    }
    private static void Assert(bool condition, string description) { if (!condition) throw new IOException("SMOKE TEST: " + description); }
}
