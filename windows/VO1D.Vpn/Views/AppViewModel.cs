using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Windows;
using System.Windows.Threading;
using VO1D.Vpn.Core;
using VO1D.Vpn.Services;

namespace VO1D.Vpn.Views;

public sealed class AppViewModel : ObservableObject, IAsyncDisposable
{
    public UserStore Store { get; } = new();
    public VpnEngine Engine { get; } = new();
    private readonly ApiClient _api;
    private readonly CancellationTokenSource _lifetime = new();
    private bool _disposed;
    private CancellationTokenSource? _connect;
    private readonly DispatcherTimer _clock = new() { Interval = TimeSpan.FromSeconds(1) };
    public ObservableCollection<VpnServer> Servers { get; } = [];
    public ObservableCollection<VpnServer> FilteredServers { get; } = [];
    public IEnumerable<VpnServer> PreviewServers => Servers.OrderByDescending(x => x.Selected).ThenBy(x => x.Ping ?? int.MaxValue).Take(2);
    public Account? Account { get; private set; }
    private string _page = "home";
    public string Page { get => _page; set { Set(ref _page, value); Notify(nameof(HomeVisible)); Notify(nameof(ServersVisible)); Notify(nameof(ProfileVisible)); Notify(nameof(SettingsVisible)); } }
    public Visibility HomeVisible => Page == "home" ? Visibility.Visible : Visibility.Collapsed;
    public Visibility ServersVisible => Page == "servers" ? Visibility.Visible : Visibility.Collapsed;
    public Visibility ProfileVisible => Page == "profile" ? Visibility.Visible : Visibility.Collapsed;
    public Visibility SettingsVisible => Page == "settings" ? Visibility.Visible : Visibility.Collapsed;
    private bool _authenticated;
    public bool HasAccess { get => _authenticated; private set { Set(ref _authenticated, value); Notify(nameof(LoginVisible)); Notify(nameof(AppVisible)); } }
    public Visibility LoginVisible => HasAccess ? Visibility.Collapsed : Visibility.Visible;
    public Visibility AppVisible => HasAccess ? Visibility.Visible : Visibility.Collapsed;
    private bool _busy;
    public bool Busy { get => _busy; private set { Set(ref _busy, value); Notify(nameof(CanActivate)); Notify(nameof(ActivationLabel)); } }
    public string ActivationLabel => Busy ? "Проверяем ключ…" : "Активировать доступ";
    public bool CanActivate => !Busy;
    private string _error = "";
    public string Error { get => _error; set { Set(ref _error, value); Notify(nameof(ErrorVisible)); } }
    public Visibility ErrorVisible => Error.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
    private string _input = "";
    public string ActivationInput { get => _input; set => Set(ref _input, value); }
    public string Nickname { get => Store.Settings.Nickname; set { Store.Settings.Nickname = value; Store.SaveSettings(); Notify(); Notify(nameof(AvatarLetter)); } }
    public string AvatarLetter => string.IsNullOrWhiteSpace(Nickname) ? "V" : Nickname.Trim()[..1].ToUpperInvariant();
    public string ApiUrl { get => Store.Settings.ApiUrl; set { Store.Settings.ApiUrl = value.Trim(); Store.SaveSettings(); Notify(); } }
    public bool AutoConnect { get => Store.Settings.AutoConnect; set { Store.Settings.AutoConnect = value; Store.SaveSettings(); Notify(); Notify(nameof(AutoLabel)); } }
    public string AutoLabel => AutoConnect ? "ВКЛЮЧЕНО" : "ВЫКЛЮЧЕНО";
    public bool KillSwitch { get => Store.Settings.KillSwitch; set { Store.Settings.KillSwitch = value; Store.SaveSettings(); Notify(); } }
    public bool Stealth { get => Store.Settings.Stealth; set { Store.Settings.Stealth = value; Store.SaveSettings(); Notify(); } }
    public bool ReduceAnimations { get => Store.Settings.ReduceAnimations; set { Store.Settings.ReduceAnimations = value; Store.SaveSettings(); Notify(); } }
    private VpnServer? _selected;
    public VpnServer? Selected { get => _selected; private set { if (_selected != null) _selected.Selected = false; Set(ref _selected, value); if (value != null) value.Selected = true; NotifyRoute(); } }
    public string Location => Selected?.Name ?? "Выберите страну";
    public string LocationCode => Selected?.Code ?? "—";
    public string Protocol => Selected?.ProtocolName.ToUpperInvariant() ?? "—";
    public string Ping => Selected?.PingText ?? "— ms";
    public string CountryCount => $"{Servers.Count} локаций";
    public string Subscription => Account == null ? "Личная конфигурация" : !Account.Active ? "Подписка неактивна" : $"До {DateTimeOffset.FromUnixTimeSeconds(Account.Until).ToLocalTime():dd.MM.yyyy}";
    public string AccountId => Account?.Id.ToString() ?? "Локальный профиль";
    private TunnelState _state;
    private bool _connectionOperation;
    public TunnelState State { get => _state; private set { Set(ref _state, value); Notify(nameof(IsConnected)); Notify(nameof(IsConnecting)); Notify(nameof(StatusTitle)); Notify(nameof(PowerGlyph)); Notify(nameof(StatusLabel)); Notify(nameof(Protection)); } }
    public bool IsConnected => State == TunnelState.Connected;
    public bool IsConnecting => _connectionOperation || State is TunnelState.Connecting or TunnelState.Disconnecting;
    public string StatusTitle => State switch { TunnelState.Connected => "Вы в VO1D", TunnelState.Connecting => "Подключение…", TunnelState.Disconnecting => "Отключение…", TunnelState.Blocked => "Трафик заблокирован", TunnelState.Failed => "Подключение не удалось", _ => "Нажмите, чтобы подключиться" };
    public string PowerGlyph => IsConnected ? "✓" : "⏻";
    public string StatusLabel => State switch { TunnelState.Connected => "CONNECTED", TunnelState.Connecting => "CONNECTING", TunnelState.Disconnecting => "DISCONNECTING", TunnelState.Blocked => "KILL SWITCH ACTIVE", TunnelState.Failed => "CONNECTION ERROR", _ => "NOT CONNECTED" };
    public string Protection => IsConnected ? "IPv4 + IPv6 · DNS через VPN" : State == TunnelState.Blocked ? "Выход в сеть остановлен" : "Защита включится после подключения";
    private string _detail = "Выберите сервер и подключитесь";
    public string StatusDetail { get => _detail; private set => Set(ref _detail, value); }
    private string _ip = "—";
    public string PublicIp { get => _ip; private set => Set(ref _ip, value); }
    public string GuardLabel => Engine.GuardActive ? "Включён" : "Не активен";
    private string _download = "0.00", _upload = "0.00", _traffic = "0.00 MB";
    public string Download { get => _download; private set => Set(ref _download, value); }
    public string Upload { get => _upload; private set => Set(ref _upload, value); }
    public string Traffic { get => _traffic; private set => Set(ref _traffic, value); }
    private DateTimeOffset? _connectedAt;
    public string Duration => _connectedAt is { } start && IsConnected ? (DateTimeOffset.Now - start).ToString(@"hh\:mm\:ss") : "00:00:00";
    private string _search = "";
    public string Search { get => _search; set { Set(ref _search, value); FilterServers(); } }
    private bool _favoritesOnly;
    public bool FavoritesOnly { get => _favoritesOnly; set { Set(ref _favoritesOnly, value); FilterServers(); } }
    private bool _pinging;
    public bool Pinging { get => _pinging; private set { Set(ref _pinging, value); Notify(nameof(PingAction)); } }
    public string PingAction => Pinging ? "ПРОВЕРЯЕМ" : "ОБНОВИТЬ";
    public AppViewModel()
    {
        _api = new(Store);
        Engine.StateChanged += (state, detail) => OnUi(() => { State = state == TunnelState.Failed && _connectionOperation ? TunnelState.Connecting : state; StatusDetail = detail; PublicIp = Engine.PublicIp; Notify(nameof(GuardLabel)); if (state == TunnelState.Connected) { _connectedAt = DateTimeOffset.Now; Error = ""; } if (state == TunnelState.Blocked || state == TunnelState.Failed && !_connectionOperation) Error = detail; });
        Engine.StatsChanged += stats => OnUi(() => { Download = stats.DownloadMbps.ToString("F2"); Upload = stats.UploadMbps.ToString("F2"); Traffic = $"{(stats.Download + stats.Upload) / 1_000_000.0:F2} MB"; });
        _clock.Tick += (_, _) => Notify(nameof(Duration)); _clock.Start();
    }
    private static void OnUi(Action action) { if (Application.Current.Dispatcher.CheckAccess()) action(); else Application.Current.Dispatcher.BeginInvoke(action); }
    private void NotifyRoute() { Notify(nameof(Location)); Notify(nameof(LocationCode)); Notify(nameof(Protocol)); Notify(nameof(Ping)); Notify(nameof(PreviewServers)); }
    public async Task BootstrapAsync()
    {
        LoadImported();
        if (Store.Secrets.Token.Length > 0 && Store.Settings.ApiUrl.Length > 0) await RefreshAsync();
        HasAccess = Servers.Count > 0 || Account != null;
        await RefreshPingsAsync();
        _ = PingLoopAsync();
        if (AutoConnect && Selected != null && (Account?.Active == true || Selected.ImportedUri != null)) await ToggleAsync();
    }
    public async Task ActivateAsync()
    {
        Busy = true; Error = "";
        try
        {
            var text = ActivationInput.Trim();
            if (text.Contains("://") && !text.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                var profile = ProxyProfile.Parse(text);
                if (!Store.Secrets.ImportedUris.Contains(text)) { Store.Secrets.ImportedUris.Add(text); Store.SaveSecrets(); }
                LoadImported(); HasAccess = true;
            }
            else
            {
                var resolved = Activation.Resolve(text, ApiUrl); ApiUrl = resolved.ApiUrl;
                var response = await _api.ActivateAsync(resolved.Key, _lifetime.Token);
                Store.Secrets.Token = response.Token; Store.SaveSecrets(); Apply(response); HasAccess = true;
            }
            ActivationInput = ""; Page = "home"; await RefreshPingsAsync();
        }
        catch (Exception e) { Error = Friendly(e); }
        finally { Busy = false; }
    }
    public async Task RefreshAsync()
    {
        if (Store.Secrets.Token.Length == 0) return;
        try { Apply(await _api.RefreshAsync(_lifetime.Token)); HasAccess = true; }
        catch (ApiException e) when (e.Status == HttpStatusCode.Unauthorized) { Store.ClearSession(); Account = null; foreach (var server in Servers.Where(x => x.ImportedUri == null).ToArray()) Servers.Remove(server); HasAccess = Servers.Count > 0; Error = e.Message; }
        catch (Exception e) { Error = Friendly(e); } // Offline errors preserve the session.
    }
    private void Apply(AppResponse response)
    {
        Account = response.Account;
        foreach (var server in Servers.Where(x => x.ImportedUri == null).ToArray()) Servers.Remove(server);
        foreach (var server in response.Servers.Countries) { server.Id = "api:" + server.Code; server.Favorite = Store.Settings.Favorites.Contains(server.Id); Servers.Add(server); }
        RestoreSelection(); Notify(nameof(Subscription)); Notify(nameof(AccountId)); Notify(nameof(CountryCount)); FilterServers();
    }
    private void LoadImported()
    {
        foreach (var server in Servers.Where(x => x.ImportedUri != null).ToArray()) Servers.Remove(server);
        foreach (var text in Store.Secrets.ImportedUris)
        {
            try { var p = ProxyProfile.Parse(text); var id = "import:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)))[..16]; Servers.Add(new() { Id = id, Code = "CUSTOM", Name = p.Name, Label = "Личная конфигурация", ProbeHost = p.Host, ProbePort = p.Port, ProtocolName = p.Protocol, ImportedUri = text, Nodes = 1, Favorite = Store.Settings.Favorites.Contains(id) }); }
            catch (Exception e) when (e is FormatException or NotSupportedException or JsonException) { Error = e.Message; }
        }
        RestoreSelection(); Notify(nameof(CountryCount)); FilterServers();
    }
    private void RestoreSelection() => Selected = Servers.FirstOrDefault(x => x.Id == Store.Settings.SelectedId) ?? Servers.OrderBy(x => x.Name).FirstOrDefault();
    public void FilterServers()
    {
        FilteredServers.Clear();
        foreach (var server in Servers.Where(x => (!FavoritesOnly || x.Favorite) && (x.Name.Contains(Search, StringComparison.OrdinalIgnoreCase) || x.Code.Contains(Search, StringComparison.OrdinalIgnoreCase))).OrderBy(x => x.Ping ?? int.MaxValue).ThenBy(x => x.Name)) FilteredServers.Add(server);
        Notify(nameof(PreviewServers));
    }
    public void Favorite(VpnServer server) { server.Favorite = !server.Favorite; Store.Settings.Favorites = Servers.Where(x => x.Favorite).Select(x => x.Id).ToList(); Store.SaveSettings(); FilterServers(); }
    public async Task SelectAsync(VpnServer server)
    {
        if (IsConnecting) return;
        var reconnect = IsConnected || State == TunnelState.Blocked;
        if (reconnect) await Engine.DisconnectAsync();
        Selected = server; Store.Settings.SelectedId = server.Id; Store.SaveSettings();
        if (reconnect) await ToggleAsync();
    }
    public async Task FastestAsync()
    {
        await RefreshPingsAsync(); var best = Servers.Where(x => x.Ping != null).MinBy(x => x.Ping);
        if (best == null) { Error = "Не удалось проверить доступность серверов."; return; }
        await SelectAsync(best); if (!IsConnected) await ToggleAsync();
    }
    public async Task ToggleAsync()
    {
        Error = "";
        if (IsConnecting) { _connect?.Cancel(); return; }
        if (IsConnected || State == TunnelState.Blocked) { await Engine.DisconnectAsync(); return; }
        if (Selected == null) { Error = "Нет доступных серверов. Обновите список или добавьте VPN-ссылку."; return; }
        if (Selected.ImportedUri == null && Account?.Active != true) { Error = "Подписка не активна."; return; }
        _connect?.Dispose(); _connect = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var ct = _connect.Token;
        _connectionOperation = true;
        State = TunnelState.Connecting; StatusDetail = "Получаем маршрут…";
        try
        {
            if (Selected.ImportedUri is { } imported) { await Engine.ConnectAsync(imported, KillSwitch, ct); return; }
            var limit = Math.Min(Selected.Nodes, 4); Exception? last = null;
            for (var attempt = 0; attempt < Math.Max(limit, 1); attempt++)
            {
                ct.ThrowIfCancellationRequested();
                try { var tunnel = await _api.TunnelAsync(Selected.Code, attempt, ct); await Engine.ConnectAsync(tunnel.Uri, KillSwitch, ct); return; }
                catch (Exception e) when (e is not OperationCanceledException && e is not ApiException) { last = e; }
            }
            throw last ?? new IOException("В выбранной стране нет рабочего маршрута.");
        }
        catch (OperationCanceledException) { await Engine.DisconnectAsync(); }
        catch (Exception e) { State = TunnelState.Failed; Error = Friendly(e); }
        finally { _connectionOperation = false; Notify(nameof(IsConnecting)); }
    }
    public async Task RefreshPingsAsync()
    {
        if (Pinging || IsConnecting || State == TunnelState.Blocked) return;
        Pinging = true;
        var list = Servers.ToArray();
        using var cap = new SemaphoreSlim(6);
        try
        {
            await Task.WhenAll(list.Select(async server => {
                await cap.WaitAsync(_lifetime.Token);
                int? ping = null;
                try { using var tcp = new TcpClient(); using var timeout = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token); timeout.CancelAfter(TimeSpan.FromSeconds(2)); var timer = Stopwatch.StartNew(); await tcp.ConnectAsync(server.ProbeHost, server.ProbePort, timeout.Token); ping = (int)timer.ElapsedMilliseconds; }
                catch (Exception e) when (e is SocketException or OperationCanceledException or ArgumentException) { }
                finally { cap.Release(); }
                OnUi(() => server.Ping = ping);
            }));
            NotifyRoute(); FilterServers();
        }
        catch (OperationCanceledException) { }
        finally { Pinging = false; }
    }
    private async Task PingLoopAsync() { try { while (!_lifetime.IsCancellationRequested) { await Task.Delay(TimeSpan.FromSeconds(30), _lifetime.Token); await RefreshPingsAsync(); } } catch (OperationCanceledException) { } }
    public async Task LogoutAsync()
    {
        _connect?.Cancel(); await Engine.DisconnectAsync(); await _api.LogoutAsync(); Store.ClearSession(); Account = null; Servers.Clear(); LoadImported(); HasAccess = Servers.Count > 0;
        Notify(nameof(Subscription)); Notify(nameof(AccountId));
    }
    public async Task DeleteImportedAsync(VpnServer server)
    {
        if (server.ImportedUri == null) return;
        if (Selected == server) await Engine.DisconnectAsync();
        Store.Secrets.ImportedUris.Remove(server.ImportedUri); Store.SaveSecrets(); LoadImported(); HasAccess = Servers.Count > 0 || Account != null;
    }
    public void AddAccess() { Page = "profile"; }
    internal void LoadTestRoute(string uri)
    {
        var p = ProxyProfile.Parse(uri, true);
        Servers.Add(new() { Id = "local-test", Code = "TEST", Name = "Локальная проверка VPN", Label = "WINDOWS TUN TEST", ProbeHost = p.Host, ProbePort = p.Port, ProtocolName = p.Protocol, Nodes = 1 });
        Selected = Servers.Last(); HasAccess = true; FilterServers(); Notify(nameof(CountryCount));
    }
    private static string Friendly(Exception e) => e is System.Net.Http.HttpRequestException ? "Не удалось связаться с сервером. Проверьте интернет и адрес API." : e is TaskCanceledException ? "Сервер не ответил вовремя. Попробуйте снова." : e.Message;
    public async ValueTask DisposeAsync() { if (_disposed) return; _disposed = true; _clock.Stop(); _lifetime.Cancel(); _connect?.Cancel(); await Engine.DisposeAsync(); _api.Dispose(); _connect?.Dispose(); _lifetime.Dispose(); }
}
