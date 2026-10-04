using System.Reflection;
using System.Security.Cryptography;

namespace VO1D.Vpn.Services;

public static class RuntimeAssets
{
    public const string Version = "1.14.2";
    public static string Root => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "VO1D_VPN", "runtime", Version);
    public static string Ensure()
    {
        // Program Files is protected from modification by unelevated processes.
        // Never load elevated code from a user-writable extraction directory.
        Directory.CreateDirectory(Root);
        for (var dir = new DirectoryInfo(Root); dir != null; dir = dir.Parent)
            if (dir.Attributes.HasFlag(FileAttributes.ReparsePoint)) throw new IOException("Каталог VPN содержит небезопасную ссылку.");
        var assembly = Assembly.GetExecutingAssembly();
        var names = assembly.GetManifestResourceNames().Where(x => x.Contains(".Assets.runtime.")).ToArray();
        if (!names.Any(x => x.EndsWith("sing-box.exe")) || !names.Any(x => x.EndsWith("wintun.dll")) || !names.Any(x => x.EndsWith("vo1d-guard.dll")))
            throw new IOException("В сборке отсутствует VPN-ядро. Скачайте полный VO1D_VPN.exe.");
        foreach (var name in names)
        {
            var filename = name[(name.IndexOf(".Assets.runtime.", StringComparison.Ordinal) + ".Assets.runtime.".Length)..];
            var target = Path.Combine(Root, filename);
            if (File.Exists(target) && File.GetAttributes(target).HasFlag(FileAttributes.ReparsePoint)) throw new IOException("Небезопасный файл VPN-ядра.");
            using var source = assembly.GetManifestResourceStream(name)!;
            using var buffer = new MemoryStream(); source.CopyTo(buffer);
            var bytes = buffer.ToArray();
            var expected = SHA256.HashData(bytes);
            if (File.Exists(target) && SHA256.HashData(File.ReadAllBytes(target)).SequenceEqual(expected)) continue;
            var temp = target + ".new";
            if (File.Exists(temp) && File.GetAttributes(temp).HasFlag(FileAttributes.ReparsePoint)) throw new IOException("Небезопасный временный файл VPN.");
            File.WriteAllBytes(temp, bytes); File.Move(temp, target, true);
        }
        return Path.Combine(Root, "sing-box.exe");
    }
}
