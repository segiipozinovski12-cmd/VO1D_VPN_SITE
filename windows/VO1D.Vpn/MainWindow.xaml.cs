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
    public async Task RevealAsync()
    {
        var started = Stopwatch.StartNew();
        BootStatus.Text = "Загружаем локальный профиль…"; BootProgress.Value = 18;
        if (!_model.ReduceAnimations) await Task.Delay(180);
        BootStatus.Text = "Проверяем Xray и сетевой модуль…"; BootProgress.Value = 42;
        await Task.Run(VO1D.Vpn.Services.RuntimeAssets.Ensure);
        BootStatus.Text = "VPN-ядра готовы. Открываем интерфейс…";
        BootProgress.BeginAnimation(System.Windows.Controls.Primitives.RangeBase.ValueProperty, new DoubleAnimation(42, 100, TimeSpan.FromMilliseconds(_model.ReduceAnimations ? 1 : 700)));
        if (!_model.ReduceAnimations && started.ElapsedMilliseconds < 1400) await Task.Delay((int)(1400 - started.ElapsedMilliseconds));
        if (_model.ReduceAnimations) StartupOverlay.Visibility = Visibility.Collapsed;
        else
        {
            var animation = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(450));
            animation.Completed += (_, _) => StartupOverlay.Visibility = Visibility.Collapsed;
            StartupOverlay.BeginAnimation(OpacityProperty, animation);
            AnimatePage();
        }
        UpdateAnimation();
    }
    private void Restore() { Show(); WindowState = WindowState.Normal; Activate(); }
    private void ModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(AppViewModel.State) or nameof(AppViewModel.ReduceAnimations) or nameof(AppViewModel.Busy)) UpdateAnimation();
        if (e.PropertyName == nameof(AppViewModel.Page)) { UpdateNavigation(); AnimatePage(); }
        if (e.PropertyName == nameof(AppViewModel.HasAccess)) AnimatePage();
        if (e.PropertyName == nameof(AppViewModel.Error) && !_model.ReduceAnimations)
            ErrorToast.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(220)));
    }
    private void UpdateNavigation()
    {
        foreach (var button in new[] { HomeNav, ServersNav, ProfileNav, SettingsNav })
        {
            var selected = button.Tag?.ToString() == _model.Page;
            button.Background = new SolidColorBrush(selected ? Color.FromRgb(29, 29, 29) : Colors.Transparent);
            button.BorderBrush = new SolidColorBrush(selected ? Color.FromRgb(93, 93, 93) : Colors.Transparent);
            button.Foreground = new SolidColorBrush(selected ? Colors.White : Color.FromRgb(121, 121, 121));
        }
    }
    private void AnimatePage()
    {
        if (_model.ReduceAnimations) return;
        var page = _model.HasAccess ? (FrameworkElement)PageSurface : LoginSurface;
        page.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(380)));
        var move = new TranslateTransform(); page.RenderTransform = move;
        move.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(15, 0, TimeSpan.FromMilliseconds(420)) { EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } });
    }
    private void UpdateAnimation()
    {
        var connected = _model.IsConnected;
        StatusDot.Fill = new SolidColorBrush(connected ? Colors.White : Color.FromRgb(106, 106, 106));
        StatusDot.BeginAnimation(OpacityProperty, null);
        if (_model.IsConnecting && !_model.ReduceAnimations)
            StatusDot.BeginAnimation(OpacityProperty, new DoubleAnimation(.2, 1, TimeSpan.FromMilliseconds(650)) { AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever });
        LoginArrow.Visibility = _model.Busy ? Visibility.Collapsed : Visibility.Visible;
        var rotate = (RotateTransform)LoginSpinner.RenderTransform;
        rotate.BeginAnimation(RotateTransform.AngleProperty, null);
        if (_model.Busy && !_model.ReduceAnimations)
            rotate.BeginAnimation(RotateTransform.AngleProperty, new DoubleAnimation(0, 360, TimeSpan.FromMilliseconds(950)) { RepeatBehavior = RepeatBehavior.Forever });
        if (!_model.ReduceAnimations)
            ConnectionTitle.BeginAnimation(OpacityProperty, new DoubleAnimation(.3, 1, TimeSpan.FromMilliseconds(300)));
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
