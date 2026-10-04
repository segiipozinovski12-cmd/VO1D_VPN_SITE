using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using VO1D.Vpn.Core;
using VO1D.Vpn.Services;
using VO1D.Vpn.Views;

namespace VO1D.Vpn;

public partial class App : System.Windows.Application
{
    private Mutex? _singleInstance;
    public AppViewModel? Model { get; private set; }
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _singleInstance = new Mutex(true, "Local\\VO1D_VPN.Windows", out var created);
        if (!created) { MessageBox.Show("VO1D уже запущен. Откройте его из трея.", "VO1D"); Shutdown(0); return; }
        DispatcherUnhandledException += (_, args) => { args.Handled = true; if (Model != null) Model.Error = "Ошибка приложения: " + args.Exception.Message; };
        try
        {
            if (e.Args.Length >= 2 && e.Args[0] == "--smoke-test") System.Windows.Media.RenderOptions.ProcessRenderMode = System.Windows.Interop.RenderMode.SoftwareOnly;
            Model = new AppViewModel();
            var window = new MainWindow(Model); MainWindow = window; window.Show();
            if (e.Args.Length >= 2 && e.Args[0] == "--smoke-test")
            {
                await SmokeTests.RunAsync(Model, window, e.Args[1]);
                await Model.DisposeAsync(); Shutdown(0); return;
            }
            // Never hold the initial screen on backend network requests.
            window.Reveal();
            await Model.BootstrapAsync();
        }
        catch (Exception error)
        {
            if (e.Args.Length >= 2 && e.Args[0] == "--smoke-test")
            {
                Directory.CreateDirectory(e.Args[1]); await File.WriteAllTextAsync(Path.Combine(e.Args[1], "failure.txt"), error.ToString());
                if (Model != null) { try { await Model.DisposeAsync(); } catch { } }
                Shutdown(1); return;
            }
            MessageBox.Show(error.Message, "Не удалось открыть VO1D", MessageBoxButton.OK, MessageBoxImage.Error); Shutdown(1);
        }
    }
    private async void SelectServer(object sender, RoutedEventArgs e) { if (sender is System.Windows.Controls.Button { Tag: VpnServer server } && Model != null) await Model.SelectAsync(server); }
    private void FavoriteServer(object sender, RoutedEventArgs e) { if (sender is System.Windows.Controls.Button { Tag: VpnServer server }) Model?.Favorite(server); }
    protected override void OnExit(ExitEventArgs e) { _singleInstance?.Dispose(); base.OnExit(e); }
}
