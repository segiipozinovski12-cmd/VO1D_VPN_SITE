using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace VO1D.Vpn.Core;

public class ObservableObject : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    protected void Notify([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new(name));
    protected bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value; Notify(name); return true;
    }
}

public sealed class VpnServer : ObservableObject
{
    public string Id { get; set; } = "";
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string Flag { get; set; } = "";
    public string Label { get; set; } = "";
    public int Nodes { get; set; }
    public string ProbeHost { get; set; } = "";
    public int ProbePort { get; set; }
    public string ProtocolName { get; set; } = "";
    [System.Text.Json.Serialization.JsonIgnore] public string? ImportedUri { get; set; }
    private int? _ping;
    [System.Text.Json.Serialization.JsonIgnore] public int? Ping { get => _ping; set { Set(ref _ping, value); Notify(nameof(PingText)); } }
    [System.Text.Json.Serialization.JsonIgnore] public string PingText => Ping is int p ? $"{p} ms" : "— ms";
    private bool _favorite;
    [System.Text.Json.Serialization.JsonIgnore] public bool Favorite { get => _favorite; set { Set(ref _favorite, value); Notify(nameof(Star)); } }
    [System.Text.Json.Serialization.JsonIgnore] public string Star => Favorite ? "★" : "☆";
    private bool _selected;
    [System.Text.Json.Serialization.JsonIgnore] public bool Selected { get => _selected; set => Set(ref _selected, value); }
}

public sealed class Account { public long Id { get; set; } public bool Active { get; set; } public bool Banned { get; set; } public long Until { get; set; } public long RemainingSeconds { get; set; } }
public sealed class ServerCollection { public List<VpnServer> Countries { get; set; } = []; public int TotalCountries { get; set; } }
public sealed class AppResponse { public bool Ok { get; set; } public string Token { get; set; } = ""; public Account Account { get; set; } = new(); public ServerCollection Servers { get; set; } = new(); public string SupportUrl { get; set; } = ""; }
public sealed class TunnelResponse { public bool Ok { get; set; } public string Uri { get; set; } = ""; public string Label { get; set; } = ""; public long ExpiresAt { get; set; } public int RouteCount { get; set; } = 1; }
public sealed class Preferences
{
    public string DeviceId { get; set; } = Guid.NewGuid().ToString();
    public string Nickname { get; set; } = "VO1D USER";
    public string ApiUrl { get; set; } = "";
    public string SelectedId { get; set; } = "";
    public bool AutoConnect { get; set; }
    public bool KillSwitch { get; set; } = true;
    public bool ReduceAnimations { get; set; }
    public bool Stealth { get; set; } = true;
    public List<string> Favorites { get; set; } = [];
}
public sealed class Secrets { public string Token { get; set; } = ""; public List<string> ImportedUris { get; set; } = []; }
public enum TunnelState { Disconnected, Connecting, Connected, Disconnecting, Blocked, Failed }
public record TunnelStats(long Upload, long Download, double UploadMbps, double DownloadMbps);
