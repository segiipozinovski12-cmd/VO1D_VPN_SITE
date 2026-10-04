using System.Diagnostics;
using System.Net;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;

namespace VO1D.Vpn.Services;

public sealed class KillGuard : IDisposable
{
    private IntPtr _engine;
    private static IntPtr _library;
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)] private delegate uint StartDelegate([MarshalAs(UnmanagedType.LPWStr)] string core, [MarshalAs(UnmanagedType.LPWStr)] string xray, uint index, out IntPtr handle);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate void StopDelegate(IntPtr handle);
    private static StartDelegate? _start;
    private static StopDelegate? _stop;
    public bool Active => _engine != IntPtr.Zero;
    public void Enable(string core, uint index, string xray = "")
    {
        if (_library == IntPtr.Zero)
        {
            _library = NativeLibrary.Load(Path.Combine(RuntimeAssets.Root, "vo1d-guard.dll"));
            _start = Marshal.GetDelegateForFunctionPointer<StartDelegate>(NativeLibrary.GetExport(_library, "Vo1dGuardStart"));
            _stop = Marshal.GetDelegateForFunctionPointer<StopDelegate>(NativeLibrary.GetExport(_library, "Vo1dGuardStop"));
        }
        Dispose();
        var error = _start!(core, xray, index, out _engine);
        if (error != 0) throw new System.ComponentModel.Win32Exception((int)error, "Windows не удалось включить Kill Switch.");
    }
    public void Dispose() { if (_engine != IntPtr.Zero) { _stop!(_engine); _engine = IntPtr.Zero; } }
}

public static class NativeWindows
{
    [DllImport("iphlpapi.dll")] private static extern uint GetBestInterfaceEx(IntPtr destination, out uint index);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll")] private static extern bool FreeConsole();
    [DllImport("kernel32.dll")] private static extern bool SetConsoleCtrlHandler(IntPtr handler, bool add);
    [DllImport("kernel32.dll")] private static extern bool GenerateConsoleCtrlEvent(uint signal, uint group);
    public static uint BestInterface(IPAddress ip)
    {
        var socket = new System.Net.IPEndPoint(ip, 443).Serialize();
        var bytes = new byte[socket.Size]; for (var i = 0; i < bytes.Length; i++) bytes[i] = socket[i];
        var pointer = Marshal.AllocHGlobal(bytes.Length);
        try { Marshal.Copy(bytes, 0, pointer, bytes.Length); var error = GetBestInterfaceEx(pointer, out var index); return error == 0 ? index : 0; }
        finally { Marshal.FreeHGlobal(pointer); }
    }
    public static uint TunIndex()
    {
        var nic = NetworkInterface.GetAllNetworkInterfaces().FirstOrDefault(x => x.Name == Core.TunnelConfig.InterfaceName && x.OperationalStatus == OperationalStatus.Up);
        return nic == null ? 0 : (uint)nic.GetIPProperties().GetIPv4Properties().Index;
    }
    public static bool SignalStop(Process process)
    {
        if (!AttachConsole((uint)process.Id)) return false;
        try { SetConsoleCtrlHandler(IntPtr.Zero, true); return GenerateConsoleCtrlEvent(0, 0); }
        finally { FreeConsole(); SetConsoleCtrlHandler(IntPtr.Zero, false); }
    }
    public static async Task CleanupOwnedRoutesAsync()
    {
        // Only our named virtual adapter is touched, never physical adapters.
        var ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
        using var process = Process.Start(new ProcessStartInfo(ps) {
            UseShellExecute = false, CreateNoWindow = true,
            ArgumentList = { "-NoProfile", "-NonInteractive", "-Command", "Get-NetRoute -InterfaceAlias 'VO1D' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue; Get-NetAdapter -Name 'VO1D' -ErrorAction SilentlyContinue | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction SilentlyContinue" }
        });
        if (process != null) { using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(8)); try { await process.WaitForExitAsync(timeout.Token); } catch (OperationCanceledException) { try { process.Kill(); } catch { } } }
    }
}

public sealed class ProcessJob : IDisposable
{
    private IntPtr _handle;
    [StructLayout(LayoutKind.Sequential)] private struct Basic { public long UserTime, JobTime; public uint Flags; public UIntPtr MinWorking, MaxWorking; public uint ActiveProcesses; public UIntPtr Affinity; public uint Priority, Scheduling; }
    [StructLayout(LayoutKind.Sequential)] private struct Io { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
    [StructLayout(LayoutKind.Sequential)] private struct Extended { public Basic Basic; public Io Io; public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr CreateJobObject(IntPtr attrs, string? name);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref Extended info, uint length);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    public ProcessJob()
    {
        _handle = CreateJobObject(IntPtr.Zero, null);
        var info = new Extended { Basic = new Basic { Flags = 0x2000 } };
        if (_handle == IntPtr.Zero || !SetInformationJobObject(_handle, 9, ref info, (uint)Marshal.SizeOf<Extended>())) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
    public void Add(Process process) { if (!AssignProcessToJobObject(_handle, process.Handle)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
    public void Dispose() { if (_handle != IntPtr.Zero) { CloseHandle(_handle); _handle = IntPtr.Zero; } }
}
