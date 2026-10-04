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
            if (e.Args.Length >= 2 && e.Args[0] == "--live-network")
            {
                try { await window.RevealAsync(); await LiveNetworkTests.RunAsync(Model, e.Args[1]); await Model.DisposeAsync(); Shutdown(0); }
                catch (Exception error) { Directory.CreateDirectory(e.Args[1]); await File.WriteAllTextAsync(Path.Combine(e.Args[1], "live-failure.txt"), error.ToString()); await Model.DisposeAsync(); Shutdown(2); }
                return;
            }
            if (e.Args.Length >= 2 && e.Args[0] == "--smoke-test")
            {
                await SmokeTests.RunAsync(Model, window, e.Args[1]);
                await Model.DisposeAsync(); Shutdown(0); return;
            }
            // Never hold the initial screen on backend network requests.
            await window.RevealAsync();
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
    private void ButtonDown(object sender, System.Windows.Input.MouseButtonEventArgs e) => AnimateButton(sender, .965, 100);
    private void ButtonUp(object sender, System.Windows.Input.MouseButtonEventArgs e) => AnimateButton(sender, 1, 260);
    private void AnimateButton(object sender, double scale, int duration)
    {
        if (Model?.ReduceAnimations == true || sender is not System.Windows.Controls.Button button) return;
        if (button.RenderTransform is not System.Windows.Media.ScaleTransform transform) { transform = new System.Windows.Media.ScaleTransform(); button.RenderTransform = transform; }
        var animation = new System.Windows.Media.Animation.DoubleAnimation(scale, TimeSpan.FromMilliseconds(duration)) { EasingFunction = new System.Windows.Media.Animation.CubicEase { EasingMode = System.Windows.Media.Animation.EasingMode.EaseOut } };
        transform.BeginAnimation(System.Windows.Media.ScaleTransform.ScaleXProperty, animation); transform.BeginAnimation(System.Windows.Media.ScaleTransform.ScaleYProperty, animation);
    }
    private async void SelectServer(object sender, RoutedEventArgs e) { if (sender is System.Windows.Controls.Button { Tag: VpnServer server } && Model != null) await Model.SelectAsync(server); }
    private void FavoriteServer(object sender, RoutedEventArgs e) { if (sender is System.Windows.Controls.Button { Tag: VpnServer server }) Model?.Favorite(server); }
    protected override void OnExit(ExitEventArgs e) { _singleInstance?.Dispose(); base.OnExit(e); }
}
