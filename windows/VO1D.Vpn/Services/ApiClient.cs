using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using VO1D.Vpn.Core;

namespace VO1D.Vpn.Services;

public sealed class ApiException(string message, HttpStatusCode status) : Exception(message) { public HttpStatusCode Status { get; } = status; }
public sealed class ApiClient : IDisposable
{
    public static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower, PropertyNameCaseInsensitive = true };
    private readonly HttpClient _http = new(new HttpClientHandler { UseProxy = false }) { Timeout = TimeSpan.FromSeconds(15) };
    private readonly UserStore _store;
    public ApiClient(UserStore store) => _store = store;
    public Task<AppResponse> ActivateAsync(string key, CancellationToken ct) => Send<AppResponse>("/api/app/activate", new { key, device_id = _store.Settings.DeviceId, device_name = "VO1D Windows" }, false, ct);
    public Task<AppResponse> RefreshAsync(CancellationToken ct) => Send<AppResponse>("/api/app/me", null, true, ct);
    public Task<TunnelResponse> TunnelAsync(string country, int attempt, CancellationToken ct) => Send<TunnelResponse>($"/api/app/tunnel?country={Uri.EscapeDataString(country)}&attempt={attempt}&stealth={(_store.Settings.Stealth ? 1 : 0)}", null, true, ct);
    public async Task LogoutAsync() { try { await Send<JsonElement>("/api/app/logout", new { }, true, CancellationToken.None); } catch { } }
    private async Task<T> Send<T>(string path, object? body, bool auth, CancellationToken ct)
    {
        if (!Uri.TryCreate(_store.Settings.ApiUrl, UriKind.Absolute, out var baseUrl) || baseUrl.Scheme != "https") throw new FormatException("Укажите HTTPS-адрес API.");
        using var request = new HttpRequestMessage(body == null ? HttpMethod.Get : HttpMethod.Post, new Uri(baseUrl, path));
        request.Headers.Accept.Add(new("application/json"));
        if (auth) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _store.Secrets.Token);
        if (body != null) request.Content = JsonContent.Create(body);
        using var response = await _http.SendAsync(request, ct);
        var text = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
        {
            string code = "";
            try { using var doc = JsonDocument.Parse(text); code = doc.RootElement.TryGetProperty("error", out var error) ? error.GetString() ?? "" : ""; } catch (JsonException) { }
            var message = code switch {
                "invalid_key" => "Ключ не найден. Проверьте строку активации.",
                "key_in_use" => "Этот ключ уже привязан к другому устройству. Для Windows нужен отдельный ключ.",
                "expired_key" or "subscription_inactive" => "Срок подписки закончился.",
                "blocked" => "Аккаунт заблокирован.",
                "country_unavailable" => "В этой стране сейчас нет маршрутов.",
                _ => $"API недоступен (HTTP {(int)response.StatusCode})."
            };
            throw new ApiException(message, response.StatusCode);
        }
        return JsonSerializer.Deserialize<T>(text, Json) ?? throw new FormatException("API вернул пустой ответ.");
    }
    public void Dispose() => _http.Dispose();
}
