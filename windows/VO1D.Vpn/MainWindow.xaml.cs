using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using VO1D.Vpn.Core;
using VO1D.Vpn.Views;
using Forms = System.Windows.Forms;

namespace VO1D.Vpn;

public partial class MainWindow : Window
{
    private readonly AppViewModel _model;
    private readonly Forms.NotifyIcon _tray;
    private bool _closing;
    public MainWindow(AppViewModel model)
    {
        InitializeComponent(); _model = model; DataContext = model;
        Icon = BitmapFrame.Create(new Uri("pack://application:,,,/Assets/vo1d.ico"));
        using var iconResource = System.Windows.Application.GetResourceStream(new Uri("pack://application:,,,/Assets/vo1d.ico")).Stream;
        _tray = new Forms.NotifyIcon { Icon = new System.Drawing.Icon(iconResource), Text = "VO1D VPN", Visible = true };
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Открыть VO1D", null, (_, _) => Dispatcher.Invoke(Restore));
        menu.Items.Add("Подключить / отключить", null, async (_, _) => await Dispatcher.InvokeAsync(model.ToggleAsync).Task.Unwrap());
        menu.Items.Add("Выйти", null, (_, _) => Dispatcher.Invoke(Close));
        _tray.ContextMenuStrip = menu; _tray.DoubleClick += (_, _) => Dispatcher.Invoke(Restore);
        model.PropertyChanged += ModelChanged; Closing += CloseAsync;
        StateChanged += (_, _) => { if (WindowState == WindowState.Minimized) Hide(); };
        UpdateNavigation();
    }
    public void Reveal()
    {
        if (_model.ReduceAnimations) { StartupOverlay.Visibility = Visibility.Collapsed; return; }
        var animation = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(450));
        animation.Completed += (_, _) => StartupOverlay.Visibility = Visibility.Collapsed;
        StartupOverlay.BeginAnimation(OpacityProperty, animation);
    }
    private void Restore() { Show(); WindowState = WindowState.Normal; Activate(); }
    private void ModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(AppViewModel.State) or nameof(AppViewModel.ReduceAnimations)) UpdateAnimation();
        if (e.PropertyName == nameof(AppViewModel.Page)) { UpdateNavigation(); AnimatePage(); }
    }
    private void UpdateNavigation()
    {
        foreach (var button in new[] { HomeNav, ServersNav, ProfileNav, SettingsNav }) { var selected = button.Tag?.ToString() == _model.Page; button.Background = new SolidColorBrush(selected ? Color.FromRgb(31, 31, 38) : Colors.Transparent); button.Foreground = new SolidColorBrush(selected ? Colors.White : Color.FromRgb(133, 133, 146)); }
    }
    private void AnimatePage() { if (!_model.ReduceAnimations) { var animation = new DoubleAnimation(.65, 1, TimeSpan.FromMilliseconds(220)); BeginAnimation(OpacityProperty, animation); } }
    private void UpdateAnimation()
    {
        var connected = _model.IsConnected;
        PowerSymbol.Visibility = connected ? Visibility.Collapsed : Visibility.Visible;
        CheckSymbol.Visibility = connected ? Visibility.Visible : Visibility.Collapsed;
        ConnectionRing.Stroke = new SolidColorBrush(connected ? Color.FromRgb(241, 241, 249) : Color.FromRgb(63, 63, 73));
        ConnectionRing.StrokeThickness = connected ? 3 : 1.5;
        Halo.Opacity = connected ? .5 : .05;
        Spinner.Visibility = _model.IsConnecting ? Visibility.Visible : Visibility.Collapsed;
        var rotate = (RotateTransform)Spinner.RenderTransform;
        rotate.BeginAnimation(RotateTransform.AngleProperty, null);
        PulseRing.BeginAnimation(OpacityProperty, null);
        var scale = (ScaleTransform)PulseRing.RenderTransform; scale.BeginAnimation(ScaleTransform.ScaleXProperty, null); scale.BeginAnimation(ScaleTransform.ScaleYProperty, null);
        PulseRing.Opacity = 0;
        if (_model.IsConnecting && !_model.ReduceAnimations) rotate.BeginAnimation(RotateTransform.AngleProperty, new DoubleAnimation(0, 360, TimeSpan.FromSeconds(1.35)) { RepeatBehavior = RepeatBehavior.Forever });
        if (connected && !_model.ReduceAnimations)
        {
            PulseRing.BeginAnimation(OpacityProperty, new DoubleAnimation(.4, 0, TimeSpan.FromSeconds(2.3)) { RepeatBehavior = RepeatBehavior.Forever });
            var pulse = new DoubleAnimation(.87, 1.12, TimeSpan.FromSeconds(2.3)) { RepeatBehavior = RepeatBehavior.Forever };
            scale.BeginAnimation(ScaleTransform.ScaleXProperty, pulse); scale.BeginAnimation(ScaleTransform.ScaleYProperty, pulse);
        }
        _tray.Text = "VO1D VPN · " + (connected ? "Подключён" : _model.State == TunnelState.Blocked ? "Трафик заблокирован" : "Отключён");
    }
    private void Navigate(object sender, RoutedEventArgs e) { if (sender is Button button && button.Tag is string page) _model.Page = page; }
    private async void Activate(object sender, RoutedEventArgs e) => await _model.ActivateAsync();
    private async void ToggleVpn(object sender, RoutedEventArgs e) => await _model.ToggleAsync();
    private async void Fastest(object sender, RoutedEventArgs e) => await _model.FastestAsync();
    private async void RefreshPings(object sender, RoutedEventArgs e) => await _model.RefreshPingsAsync();
    private async void RefreshServers(object sender, RoutedEventArgs e) { await _model.RefreshAsync(); await _model.RefreshPingsAsync(); }
    private void ToggleAuto(object sender, RoutedEventArgs e) => _model.AutoConnect = !_model.AutoConnect;
    private void OpenSupport(object sender, RoutedEventArgs e) => OpenUrl("https://t.me/vo1d_root");
    private void OpenPlans(object sender, RoutedEventArgs e) => OpenUrl("https://t.me/VO1D_VPNbot");
    private void OpenUrl(string url) { try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); } catch (Exception ex) { _model.Error = ex.Message; } }
    private async void Logout(object sender, RoutedEventArgs e) => await _model.LogoutAsync();
    private void DismissError(object sender, RoutedEventArgs e) => _model.Error = "";
    private void MinimizeWindow(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void MaximizeWindow(object sender, RoutedEventArgs e) => WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    private void CloseWindow(object sender, RoutedEventArgs e) => Close();
    private async void ActivationKeyDown(object sender, KeyEventArgs e) { if (e.Key == Key.Enter && _model.CanActivate) await _model.ActivateAsync(); }
    private async void CloseAsync(object? sender, CancelEventArgs e)
    {
        if (_closing) return;
        e.Cancel = true; _closing = true; IsEnabled = false;
        try { await _model.DisposeAsync(); }
        finally { _tray.Dispose(); System.Windows.Application.Current.Shutdown(); }
    }
    internal void SaveScreenshot(string path)
    {
        UpdateLayout(); var dpi = VisualTreeHelper.GetDpi(this);
        var bitmap = new RenderTargetBitmap((int)(ActualWidth * dpi.DpiScaleX), (int)(ActualHeight * dpi.DpiScaleY), 96 * dpi.DpiScaleX, 96 * dpi.DpiScaleY, PixelFormats.Pbgra32);
        bitmap.Render(this); var png = new PngBitmapEncoder(); png.Frames.Add(BitmapFrame.Create(bitmap)); using var file = File.Create(path); png.Save(file);
    }
}
