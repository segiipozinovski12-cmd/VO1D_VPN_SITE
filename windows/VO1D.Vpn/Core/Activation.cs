namespace VO1D.Vpn.Core;

public static class Activation
{
    public static (string Key, string ApiUrl) Resolve(string input, string storedUrl)
    {
        var value = input.Trim();
        var url = storedUrl.Trim();
        if (value.StartsWith("VO1D1.", StringComparison.Ordinal))
        {
            var parts = value.Split('.', 3);
            if (parts.Length != 3) throw new FormatException("Строка активации повреждена.");
            try { url = Encoding.UTF8.GetString(DecodeBase64(parts[1])); }
            catch (FormatException) { throw new FormatException("Строка активации повреждена."); }
            value = parts[2];
        }
        if (!Uri.TryCreate(url, UriKind.Absolute, out var api) || api.Scheme != "https" ||
            string.IsNullOrWhiteSpace(api.Host) || !string.IsNullOrEmpty(api.UserInfo) ||
            api.Host.Contains("REPLACE_ME", StringComparison.OrdinalIgnoreCase) || api.Host.EndsWith(".invalid"))
            throw new FormatException("Вставьте полную строку VO1D1… или укажите HTTPS-адрес API в настройках.");
        if (value.Length < 8 || value.Length > 256 || value.Any(char.IsControl))
            throw new FormatException("Введите действующий ключ VO1D.");
        return (value, api.GetLeftPart(UriPartial.Authority));
    }

    public static byte[] DecodeBase64(string value)
    {
        var text = value.Replace('-', '+').Replace('_', '/');
        return Convert.FromBase64String(text.PadRight((text.Length + 3) / 4 * 4, '='));
    }
}
