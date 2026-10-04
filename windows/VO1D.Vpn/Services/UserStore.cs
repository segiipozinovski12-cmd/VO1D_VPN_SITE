using System.Runtime.InteropServices;
using VO1D.Vpn.Core;

namespace VO1D.Vpn.Services;

public sealed class UserStore
{
    public static readonly string Root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VO1D_VPN");
    private static readonly JsonSerializerOptions Json = new() { WriteIndented = true };
    public Preferences Settings { get; }
    public Secrets Secrets { get; private set; }
    public UserStore()
    {
        Directory.CreateDirectory(Root);
        Settings = Read<Preferences>("settings.json") ?? new();
        try { Secrets = File.Exists(Path.Combine(Root, "session.bin")) ? JsonSerializer.Deserialize<Secrets>(Unprotect(File.ReadAllBytes(Path.Combine(Root, "session.bin")))) ?? new() : new(); }
        catch { Secrets = new(); }
    }
    private static T? Read<T>(string file) { try { return JsonSerializer.Deserialize<T>(File.ReadAllText(Path.Combine(Root, file))); } catch { return default; } }
    public void SaveSettings() => AtomicWrite("settings.json", Encoding.UTF8.GetBytes(JsonSerializer.Serialize(Settings, Json)));
    public void SaveSecrets() => AtomicWrite("session.bin", Protect(JsonSerializer.SerializeToUtf8Bytes(Secrets)));
    public void ClearSession() { Secrets.Token = ""; SaveSecrets(); }
    private static void AtomicWrite(string name, byte[] data)
    {
        var path = Path.Combine(Root, name);
        var temporary = path + ".tmp";
        File.WriteAllBytes(temporary, data); File.Move(temporary, path, true);
    }
    [StructLayout(LayoutKind.Sequential)] private struct Blob { public int Size; public IntPtr Data; }
    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)] private static extern bool CryptProtectData(ref Blob input, string description, IntPtr entropy, IntPtr reserved, IntPtr prompt, uint flags, out Blob output);
    [DllImport("crypt32.dll", SetLastError = true)] private static extern bool CryptUnprotectData(ref Blob input, IntPtr description, IntPtr entropy, IntPtr reserved, IntPtr prompt, uint flags, out Blob output);
    [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr value);
    private static byte[] Protect(byte[] value) => Transform(value, true);
    private static byte[] Unprotect(byte[] value) => Transform(value, false);
    private static byte[] Transform(byte[] data, bool protect)
    {
        var input = new Blob { Size = data.Length, Data = Marshal.AllocHGlobal(data.Length) };
        Blob output = default;
        try
        {
            Marshal.Copy(data, 0, input.Data, data.Length);
            var ok = protect ? CryptProtectData(ref input, "VO1D session", IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, 1, out output) : CryptUnprotectData(ref input, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, 1, out output);
            if (!ok) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            var result = new byte[output.Size]; Marshal.Copy(output.Data, result, 0, result.Length); return result;
        }
        finally { Marshal.FreeHGlobal(input.Data); if (output.Data != IntPtr.Zero) LocalFree(output.Data); }
    }
}
