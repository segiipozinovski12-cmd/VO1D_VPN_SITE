using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Security.Cryptography;
using VO1D.Vpn.Core;

namespace VO1D.Vpn.Services;

public sealed class VpnEngine : IAsyncDisposable
{
    public event Action<TunnelState, string>? StateChanged;
    public event Action<TunnelStats>? StatsChanged;
    public TunnelState State { get; private set; }
    public string PublicIp { get; private set; } = "—";
    public bool GuardActive => _guard.Active;
    private readonly KillGuard _guard = new();
    private readonly ProcessJob _job = new();
    private readonly SemaphoreSlim _gate = new(1);
    private bool _disposed;
    private Process? _process;
    private CancellationTokenSource? _monitor;
    private string? _config;
    private int _apiPort;
    private string _secret = "";
    private string _core = "";
    public int? CorePid => _process?.Id;

    private void Change(TunnelState state, string message) { State = state; StateChanged?.Invoke(state, message); }
    public async Task ConnectAsync(string uri, bool killSwitch, CancellationToken ct, Uri? testProbe = null, string? testMarker = null)
    {
        await _gate.WaitAsync(ct);
        try
        {
            await StopCoreAsync(); _guard.Dispose();
            Change(TunnelState.Connecting, "Проверяем защищённый маршрут…");
            var profile = ProxyProfile.Parse(uri, testProbe != null);
            // Resolve only the VPN endpoint before creating the default TUN
            // route. User DNS is resolved exclusively over the encrypted VPN.
            if (!IPAddress.TryParse(profile.Host, out _))
            {
                var ips = await Dns.GetHostAddressesAsync(profile.Host, ct);
                profile.Outbound["server"] = (ips.FirstOrDefault(x => x.AddressFamily == AddressFamily.InterNetwork) ?? ips.FirstOrDefault() ?? throw new IOException("Не удалось найти VPN-сервер.")).ToString();
            }
            if (testProbe != null)
            {
                var loopback = System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces().First(x => x.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Loopback);
                profile.Outbound["bind_interface"] = loopback.Name;
            }
            _core = RuntimeAssets.Ensure();
            var proxyPort = FreePort(); _apiPort = FreePort();
            while (_apiPort == proxyPort) _apiPort = FreePort();
            _secret = Convert.ToHexString(RandomNumberGenerator.GetBytes(24));
            var password = Convert.ToHexString(RandomNumberGenerator.GetBytes(24));
            var config = TunnelConfig.Build(profile, proxyPort, _apiPort, _secret, password);
            _config = Path.Combine(UserStore.Root, "tunnel-" + Guid.NewGuid().ToString("N") + ".json");
            await File.WriteAllTextAsync(_config, config.ToJsonString(), ct);
            var start = new ProcessStartInfo(_core) { UseShellExecute = false, CreateNoWindow = false, WindowStyle = ProcessWindowStyle.Hidden, WorkingDirectory = RuntimeAssets.Root };
            start.ArgumentList.Add("run"); start.ArgumentList.Add("-c"); start.ArgumentList.Add(_config);
            _process = Process.Start(start) ?? throw new IOException("VPN-ядро не запустилось.");
            _job.Add(_process);
            var probe = testProbe ?? new Uri("https://1.1.1.1/cdn-cgi/trace");
            var marker = testMarker ?? "ip=";
            using var proxyClient = new HttpClient(new HttpClientHandler { UseProxy = true, Proxy = new WebProxy($"http://127.0.0.1:{proxyPort}") { Credentials = new NetworkCredential("vo1d", password) } }) { Timeout = TimeSpan.FromSeconds(5) };
            Exception? last = null;
            string trace = "";
            var readiness = Stopwatch.StartNew();
            for (var attempt = 0; attempt < 12 && readiness.Elapsed < TimeSpan.FromSeconds(20); attempt++)
            {
                ct.ThrowIfCancellationRequested();
                if (_process.HasExited) throw new IOException($"VPN-ядро завершилось (код {_process.ExitCode}). Маршрут несовместим или адаптер недоступен.");
                try
                {
                    trace = await proxyClient.GetStringAsync(probe, ct);
                    if (!trace.Contains(marker, StringComparison.Ordinal)) throw new IOException("VPN-сервер не пропускает трафик.");
                    break;
                }
                catch (Exception e) when (e is HttpRequestException or IOException or TaskCanceledException && !ct.IsCancellationRequested) { last = e; }
                await Task.Delay(300, ct);
            }
            if (!trace.Contains(marker, StringComparison.Ordinal)) throw new IOException("Трафик через VPN не проходит. Попробуйте другую страну или маршрут.", last);
            var index = NativeWindows.TunIndex();
            var probeIp = IPAddress.TryParse(probe.Host, out var parsed) ? parsed : IPAddress.Parse("1.1.1.1");
            if (index == 0 || NativeWindows.BestInterface(probeIp) != index) throw new IOException("Windows не направил трафик в VPN-адаптер.");
            if (killSwitch) _guard.Enable(_core, index);
            // A second request without a proxy verifies the computer's actual
            // default route, after the kill-switch filters have been applied.
            using var direct = new HttpClient(new HttpClientHandler { UseProxy = false }) { Timeout = TimeSpan.FromSeconds(8) };
            var systemTrace = await direct.GetStringAsync(probe, ct);
            if (!systemTrace.Contains(marker, StringComparison.Ordinal)) throw new IOException("Системный VPN-маршрут не прошёл проверку.");
            PublicIp = testProbe == null ? ExtractIp(systemTrace) : "LOCAL TEST";
            if (testProbe == null && ExtractIp(trace) != PublicIp) throw new IOException("Системный маршрут и VPN дали разные IP-адреса.");
            Change(TunnelState.Connected, "Туннель проверен · весь трафик через VPN");
            _monitor = new CancellationTokenSource();
            _ = MonitorAsync(_process, _monitor.Token, probe, marker);
        }
        catch (OperationCanceledException)
        {
            await StopCoreAsync(); _guard.Dispose(); Change(TunnelState.Disconnected, "Подключение отменено"); throw;
        }
        catch (Exception e)
        {
            await StopCoreAsync(); _guard.Dispose(); Change(TunnelState.Failed, e.Message); throw;
        }
        finally { _gate.Release(); }
    }

    public async Task DisconnectAsync()
    {
        await _gate.WaitAsync();
        try { Change(TunnelState.Disconnecting, "Отключаем туннель…"); await StopCoreAsync(); _guard.Dispose(); PublicIp = "—"; Change(TunnelState.Disconnected, "Выберите сервер и подключитесь"); }
        finally { _gate.Release(); }
    }
    private async Task StopCoreAsync()
    {
        _monitor?.Cancel(); _monitor?.Dispose(); _monitor = null;
        var process = _process; _process = null;
        if (process != null)
        {
            try
            {
                if (!process.HasExited)
                {
                    NativeWindows.SignalStop(process);
                    using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
                    try { await process.WaitForExitAsync(timeout.Token); }
                    catch (OperationCanceledException) { process.Kill(true); await process.WaitForExitAsync(); }
                }
            }
            catch (InvalidOperationException) { }
            finally { process.Dispose(); await NativeWindows.CleanupOwnedRoutesAsync(); }
        }
        if (_config != null) { try { File.Delete(_config); } catch (IOException) { } _config = null; }
    }
    private async Task MonitorAsync(Process process, CancellationToken ct, Uri probe, string marker)
    {
        using var http = new HttpClient(new HttpClientHandler { UseProxy = false }) { Timeout = TimeSpan.FromSeconds(2) };
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _secret);
        long previousUp = 0, previousDown = 0;
        var healthTicks = 0; var failedHealth = 0;
        var timer = Stopwatch.StartNew();
        using var health = new HttpClient(new HttpClientHandler { UseProxy = false }) { Timeout = TimeSpan.FromSeconds(5) };
        try
        {
            while (!ct.IsCancellationRequested)
            {
                await Task.Delay(1000, ct);
                if (process.HasExited)
                {
                    Change(_guard.Active ? TunnelState.Blocked : TunnelState.Failed, _guard.Active ? "VPN оборвался. Kill Switch блокирует выход в сеть. Переподключитесь или отключите защиту." : "VPN оборвался. Подключитесь снова.");
                    return;
                }
                if (++healthTicks % 15 == 0)
                {
                    try { var result = await health.GetStringAsync(probe, ct); failedHealth = result.Contains(marker, StringComparison.Ordinal) ? 0 : failedHealth + 1; }
                    catch (Exception e) when (e is HttpRequestException or TaskCanceledException) { failedHealth++; }
                    if (failedHealth >= 3)
                    {
                        Change(_guard.Active ? TunnelState.Blocked : TunnelState.Failed, _guard.Active ? "VPN перестал передавать данные. Kill Switch активен. Переподключитесь." : "VPN перестал передавать данные. Переподключитесь.");
                        return;
                    }
                }
                try
                {
                    var json = await http.GetStringAsync($"http://127.0.0.1:{_apiPort}/connections", ct);
                    using var doc = JsonDocument.Parse(json);
                    var up = doc.RootElement.GetProperty("uploadTotal").GetInt64();
                    var down = doc.RootElement.GetProperty("downloadTotal").GetInt64();
                    var seconds = Math.Max(timer.Elapsed.TotalSeconds, .01); timer.Restart();
                    StatsChanged?.Invoke(new(up, down, Math.Max(0, up - previousUp) * 8 / seconds / 1_000_000, Math.Max(0, down - previousDown) * 8 / seconds / 1_000_000));
                    previousUp = up; previousDown = down;
                }
                catch (Exception e) when (e is HttpRequestException or JsonException or TaskCanceledException or KeyNotFoundException) { }
            }
        }
        catch (OperationCanceledException) { }
        catch (InvalidOperationException) { }
    }
    private static string ExtractIp(string trace) => trace.Split('\n').FirstOrDefault(x => x.StartsWith("ip="))?[3..].Trim() ?? throw new IOException("Не удалось проверить внешний IP.");
    public static int FreePort() { var listener = new TcpListener(IPAddress.Loopback, 0); listener.Start(); var port = ((IPEndPoint)listener.LocalEndpoint).Port; listener.Stop(); return port; }
    public void AbortCoreForTest() { if (_process is { HasExited: false }) _process.Kill(true); }
    public async ValueTask DisposeAsync() { if (_disposed) return; _disposed = true; await DisconnectAsync(); _guard.Dispose(); _job.Dispose(); _gate.Dispose(); }
}
