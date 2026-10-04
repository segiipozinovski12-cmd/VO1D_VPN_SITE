using System.Diagnostics;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using VO1D.Vpn.Core;

namespace VO1D.Vpn.Views;

// Native vector visuals: no video, browser or simulated connection state.
public abstract class AnimatedVisual : FrameworkElement
{
    public static readonly DependencyProperty ReduceMotionProperty = DependencyProperty.Register(nameof(ReduceMotion), typeof(bool), typeof(AnimatedVisual), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, Changed));
    public bool ReduceMotion { get => (bool)GetValue(ReduceMotionProperty); set => SetValue(ReduceMotionProperty, value); }
    private readonly DispatcherTimer _frames = new(DispatcherPriority.Background) { Interval = TimeSpan.FromMilliseconds(40) };
    private readonly Stopwatch _clock = Stopwatch.StartNew();
    protected double Time => ReduceMotion ? 0 : _clock.Elapsed.TotalSeconds;
    protected AnimatedVisual()
    {
        _frames.Tick += (_, _) => { if (Window.GetWindow(this)?.WindowState != WindowState.Minimized) InvalidateVisual(); };
        Loaded += (_, _) => UpdateFrames(); Unloaded += (_, _) => _frames.Stop(); IsVisibleChanged += (_, _) => UpdateFrames();
        IsHitTestVisible = false;
    }
    private static void Changed(DependencyObject d, DependencyPropertyChangedEventArgs e) => ((AnimatedVisual)d).UpdateFrames();
    private void UpdateFrames() { if (IsLoaded && IsVisible && !ReduceMotion) _frames.Start(); else _frames.Stop(); InvalidateVisual(); }
    protected static SolidColorBrush White(double alpha) { var b = new SolidColorBrush(Color.FromArgb((byte)Math.Clamp(alpha * 255, 0, 255), 255, 255, 255)); b.Freeze(); return b; }
    protected static Pen Line(double alpha, double width = 1) { var p = new Pen(White(alpha), width) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }; p.Freeze(); return p; }
}

public sealed class AmbientField : AnimatedVisual
{
    protected override void OnRender(DrawingContext dc)
    {
        var w = ActualWidth; var h = ActualHeight; if (w <= 0 || h <= 0) return;
        dc.DrawRectangle(Brushes.Black, null, new Rect(0, 0, w, h));
        for (var row = 0; row < 14; row++)
        {
            var y = h * (.04 + row * .058); var phase = Time * .16 + row * .8;
            var geometry = new StreamGeometry();
            using (var ctx = geometry.Open()) { ctx.BeginFigure(new Point(-80, y), false, false); ctx.BezierTo(new Point(w * .28, y - 30 + Math.Sin(phase) * 14), new Point(w * .66, y + 24), new Point(w + 80, y - 50), true, false); }
            geometry.Freeze(); dc.DrawGeometry(null, Line(.012 + (row % 4) * .004, .6), geometry);
        }
        for (var i = 0; i < 42; i++)
        {
            var x = ((i * 173.31 + 47) % 997) / 997 * w; var y = ((i * 137.71 + 18) % 991) / 991 * h;
            var alpha = .055 + (.5 + .5 * Math.Sin(Time * .4 + i)) * .10;
            dc.DrawEllipse(White(alpha), null, new Point(x, y), i % 6 == 0 ? 1.2 : .6, i % 6 == 0 ? 1.2 : .6);
        }
    }
}

public sealed class ConnectionVortex : AnimatedVisual
{
    public static readonly DependencyProperty StateProperty = DependencyProperty.Register(nameof(State), typeof(TunnelState), typeof(ConnectionVortex), new FrameworkPropertyMetadata(TunnelState.Disconnected, FrameworkPropertyMetadataOptions.AffectsRender));
    public TunnelState State { get => (TunnelState)GetValue(StateProperty); set => SetValue(StateProperty, value); }
    public static readonly DependencyProperty DecorativeProperty = DependencyProperty.Register(nameof(Decorative), typeof(bool), typeof(ConnectionVortex), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));
    public bool Decorative { get => (bool)GetValue(DecorativeProperty); set => SetValue(DecorativeProperty, value); }
    protected override void OnRender(DrawingContext dc)
    {
        var size = Math.Min(ActualWidth, ActualHeight); if (size <= 0) return;
        var c = new Point(ActualWidth / 2, ActualHeight / 2); var r = size * .35;
        var active = State == TunnelState.Connected; var busy = State is TunnelState.Connecting or TunnelState.Disconnecting;
        var intensity = active ? 1 : busy ? .84 : .52;
        var t = Time * (busy ? 1.7 : .30); var breathe = 1 + Math.Sin(Time * 1.6) * (active ? .018 : .008);
        dc.PushTransform(new ScaleTransform(breathe, breathe, c.X, c.Y));
        var glow = new RadialGradientBrush { Center = new Point(.5, .5), GradientOrigin = new Point(.5, .5), RadiusX = .5, RadiusY = .5 };
        glow.GradientStops.Add(new GradientStop(Color.FromArgb(0, 255, 255, 255), 0)); glow.GradientStops.Add(new GradientStop(Color.FromArgb(0, 255, 255, 255), .46));
        glow.GradientStops.Add(new GradientStop(Color.FromArgb((byte)(active ? 35 : busy ? 26 : 12), 255, 255, 255), .72)); glow.GradientStops.Add(new GradientStop(Colors.Transparent, 1));
        dc.DrawEllipse(glow, null, c, size * .49, size * .49);
        for (var i = 0; i < 64; i++)
        {
            var radius = r * (.78 + (i % 23) * .0105); var angle = i * 2.399 + t * (i % 2 == 0 ? 1 : -.73);
            var length = .23 + (i % 9) * .09;
            var p1 = Polar(c, radius, angle); var p2 = Polar(c, radius + 3, angle + length);
            var geometry = new StreamGeometry(); using (var ctx = geometry.Open()) { ctx.BeginFigure(p1, false, false); ctx.ArcTo(p2, new Size(radius, radius), 0, false, SweepDirection.Clockwise, true, false); } geometry.Freeze();
            var alpha = intensity * (.075 + i % 7 * .055);
            if (i % 4 == 0) dc.DrawGeometry(null, Line(alpha * .13, 6), geometry);
            dc.DrawGeometry(null, Line(alpha, i % 5 == 0 ? 1.1 : .65), geometry);
        }
        dc.DrawEllipse(null, Line(active ? .90 : .22, active ? 1.3 : .8), c, r * .765, r * .765);
        dc.DrawEllipse(null, Line(.09, .7), c, r * 1.15, r * 1.15);
        for (var i = 0; i < 72; i++) { var a = i * Math.PI / 36; dc.DrawLine(Line(i % 6 == 0 ? .24 : .08, .7), Polar(c, r * 1.20, a), Polar(c, r * (i % 6 == 0 ? 1.24 : 1.215), a)); }
        if (busy || active)
        {
            for (var n = 0; n < 2; n++)
            {
                var angle = Time * (busy ? 3.1 : .8) + n * Math.PI; var radius = r * (n == 0 ? 1.09 : .70);
                var geometry = new StreamGeometry(); using (var ctx = geometry.Open()) { ctx.BeginFigure(Polar(c, radius, angle), false, false); ctx.ArcTo(Polar(c, radius, angle + (n == 0 ? .8 : .5)), new Size(radius, radius), 0, false, SweepDirection.Clockwise, true, false); }
                dc.DrawGeometry(null, Line(n == 0 ? .93 : .35, n == 0 ? 2 : 1), geometry);
                dc.DrawEllipse(White(.95), null, Polar(c, radius, angle + .8), 2, 2);
            }
        }
        var fill = new RadialGradientBrush(Color.FromRgb(12, 12, 12), Colors.Black) { GradientOrigin = new Point(.35, .2) };
        dc.DrawEllipse(fill, Line(.13), c, r * .59, r * .59);
        if (!Decorative)
        {
            var pen = Line(active ? 1 : .85, size * .006); var k = size * .082;
            if (active) { dc.DrawLine(pen, new Point(c.X - k * .7, c.Y), new Point(c.X - k * .13, c.Y + k * .55)); dc.DrawLine(pen, new Point(c.X - k * .13, c.Y + k * .55), new Point(c.X + k * .8, c.Y - k * .55)); }
            else
            {
                var g = new StreamGeometry(); using (var ctx = g.Open()) { ctx.BeginFigure(Polar(c, k, -Math.PI * .32), false, false); ctx.ArcTo(Polar(c, k, -Math.PI * .68), new Size(k, k), 0, true, SweepDirection.Clockwise, true, false); } dc.DrawGeometry(null, pen, g);
                dc.DrawLine(pen, new Point(c.X, c.Y - k * 1.22), new Point(c.X, c.Y - k * .12));
            }
        }
        dc.Pop();
    }
    private static Point Polar(Point c, double radius, double angle) => new(c.X + Math.Cos(angle) * radius, c.Y + Math.Sin(angle) * radius);
}
