using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Automation.Provider;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Foundation;
using Windows.System;

namespace SquooshPro.Windows;

// Only transforms and the viewport mask change during a gesture, never the decoded images.
public sealed class ComparisonPreview : Grid
{
    private readonly Grid viewport = new() { Background = Brush("ControlFillColorSecondaryBrush"), MinHeight = 80 };
    private readonly Canvas originalLayer = new();
    private readonly Canvas outputLayer = new();
    private readonly Image original = new() { Stretch = Stretch.Fill };
    private readonly Image output = new() { Stretch = Stretch.Fill };
    private readonly RectangleGeometry viewportClip = new();
    private readonly RectangleGeometry outputClip = new();
    private readonly Border line = new() { Width = 2, Background = new SolidColorBrush(Microsoft.UI.Colors.White), IsHitTestVisible = false };
    private readonly DividerHandle handle;
    private readonly TextBlock percentage = new() { VerticalAlignment = VerticalAlignment.Center, MinWidth = 48, TextAlignment = TextAlignment.Center };
    private readonly TextBlock ready = new() { Text = "等待预览", FontSize = 12, TextWrapping = TextWrapping.Wrap };
    private double split = .5;
    private double pixelWidth = 1, pixelHeight = 1, scale = 1, offsetX, offsetY;
    private bool fit = true, draggingDivider, draggingPan;
    private Point lastPoint;
    public bool IsReady { get; private set; }
    protected override AutomationPeer OnCreateAutomationPeer() => new ComparisonPeer(this);
    public double Split { get => split; set { split = Math.Clamp(value, .02, .98); LayoutImages(); } }

    public ComparisonPreview()
    {
        AutomationProperties.SetAutomationId(this, "preview.comparison");
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var tools = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Margin = new Thickness(0, 0, 0, 10) };
        tools.Children.Add(Command("适应窗口", "preview.fit", Fit));
        tools.Children.Add(Command("100%", "preview.actualSize", ShowActualSize));
        tools.Children.Add(Command("−", "preview.zoomOut", () => Zoom(1 / 1.25)));
        tools.Children.Add(percentage);
        tools.Children.Add(Command("+", "preview.zoomIn", () => Zoom(1.25)));
        Children.Add(tools);
        originalLayer.Children.Add(original);
        outputLayer.Children.Add(output);
        outputLayer.Clip = outputClip;
        viewport.Clip = viewportClip;
        viewport.Children.Add(originalLayer);
        viewport.Children.Add(outputLayer);
        viewport.Children.Add(line);
        handle = new DividerHandle(this) { Width = 44, Height = 44 };
        AutomationProperties.SetAutomationId(handle, "preview.divider");
        AutomationProperties.SetName(handle, "拖动分界线对比原图和输出");
        viewport.Children.Add(handle);
        var badges = new Grid { Padding = new Thickness(12), IsHitTestVisible = false, VerticalAlignment = VerticalAlignment.Top };
        badges.ColumnDefinitions.Add(new ColumnDefinition());
        badges.ColumnDefinitions.Add(new ColumnDefinition());
        badges.Children.Add(Badge("原图", HorizontalAlignment.Left));
        var after = Badge("输出", HorizontalAlignment.Right);
        Grid.SetColumn(after, 1);
        badges.Children.Add(after);
        viewport.Children.Add(badges);
        Grid.SetRow(viewport, 1);
        Children.Add(viewport);
        ready.Margin = new Thickness(0, 8, 0, 0);
        ready.Foreground = Brush("TextFillColorSecondaryBrush");
        AutomationProperties.SetAutomationId(ready, "preview.ready");
        Grid.SetRow(ready, 2);
        Children.Add(ready);
        viewport.SizeChanged += (_, _) => LayoutImages();
        viewport.PointerPressed += Press;
        viewport.PointerMoved += Move;
        viewport.PointerReleased += Release;
        viewport.PointerCanceled += Release;
        viewport.PointerCaptureLost += (_, _) => { draggingDivider = draggingPan = false; };
        viewport.PointerWheelChanged += (_, e) => { Zoom(e.GetCurrentPoint(viewport).Properties.MouseWheelDelta > 0 ? 1.15 : 1 / 1.15, e.GetCurrentPoint(viewport).Position); e.Handled = true; };
    }

    internal static Brush Brush(string key) => (Brush)Application.Current.Resources[key];
    private static Border Badge(string text, HorizontalAlignment alignment)
    {
        var label = new TextBlock { Text = text, Foreground = new SolidColorBrush(Microsoft.UI.Colors.White), FontSize = 12 };
        AutomationProperties.SetAutomationId(label, text == "原图" ? "preview.originalLabel" : "preview.outputLabel");
        return new Border { HorizontalAlignment = alignment, Padding = new Thickness(9, 4, 9, 4), CornerRadius = new CornerRadius(10), Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(205, 25, 31, 35)), Child = label };
    }
    private static Button Command(string label, string id, Action action)
    {
        var button = new Button { Content = label, Padding = new Thickness(10, 6, 10, 6), MinHeight = 32 };
        AutomationProperties.SetAutomationId(button, id);
        AutomationProperties.SetName(button, id == "preview.zoomIn" ? "放大预览" : id == "preview.zoomOut" ? "缩小预览" : label);
        button.Click += (_, _) => action();
        return button;
    }

    public void SetOriginal(BitmapImage image)
    {
        original.Source = image;
        output.Source = null;
        pixelWidth = image.PixelWidth;
        pixelHeight = image.PixelHeight;
        fit = true;
        offsetX = offsetY = 0;
        IsReady = false;
        ready.Text = "正在加载预览";
        LayoutImages();
    }
    public void SetOutput(BitmapImage image, int width, int height)
    {
        output.Source = image;
        pixelWidth = width;
        pixelHeight = height;
        IsReady = original.Source is not null && image.PixelWidth > 0 && image.PixelHeight > 0;
        ready.Text = IsReady ? $"预览已加载 · {width}×{height} · 拖动分界线对比，放大后可拖动画面" : "预览加载失败";
        LayoutImages();
    }
    public void Clear()
    {
        original.Source = output.Source = null;
        IsReady = false;
        ready.Text = "等待预览";
    }
    public void ShowLoading() { IsReady = false; ready.Text = "正在加载预览"; }
    public void Failed() { IsReady = false; output.Source = null; ready.Text = "预览加载失败"; }
    private double FitScale => Math.Min(viewport.ActualWidth / Math.Max(1, pixelWidth), viewport.ActualHeight / Math.Max(1, pixelHeight));
    private void Fit() { fit = true; offsetX = offsetY = 0; LayoutImages(); }
    private void ShowActualSize() { fit = false; scale = 1 / (XamlRoot?.RasterizationScale ?? 1); offsetX = offsetY = 0; LayoutImages(); }
    private void Zoom(double factor, Point? anchor = null)
    {
        var previous = fit ? FitScale : scale;
        fit = false;
        scale = Math.Clamp(previous * factor, Math.Min(FitScale, .05), 8 / (XamlRoot?.RasterizationScale ?? 1));
        var center = anchor ?? new Point(viewport.ActualWidth / 2, viewport.ActualHeight / 2);
        var ratio = scale / Math.Max(.0001, previous);
        offsetX = (offsetX - center.X + viewport.ActualWidth / 2) * ratio + center.X - viewport.ActualWidth / 2;
        offsetY = (offsetY - center.Y + viewport.ActualHeight / 2) * ratio + center.Y - viewport.ActualHeight / 2;
        LayoutImages();
    }
    private void LayoutImages()
    {
        var w = viewport.ActualWidth; var h = viewport.ActualHeight;
        if (w <= 0 || h <= 0) return;
        viewportClip.Rect = new Rect(0, 0, w, h);
        if (fit) scale = FitScale;
        var iw = pixelWidth * scale; var ih = pixelHeight * scale;
        offsetX = Math.Clamp(offsetX, -Math.Max(0, (iw - w) / 2), Math.Max(0, (iw - w) / 2));
        offsetY = Math.Clamp(offsetY, -Math.Max(0, (ih - h) / 2), Math.Max(0, (ih - h) / 2));
        foreach (var image in new[] { original, output })
        {
            image.Width = Math.Max(1, iw); image.Height = Math.Max(1, ih);
            Canvas.SetLeft(image, (w - iw) / 2 + offsetX); Canvas.SetTop(image, (h - ih) / 2 + offsetY);
        }
        var x = w * split;
        outputClip.Rect = new Rect(x, 0, w - x, h);
        line.HorizontalAlignment = HorizontalAlignment.Left;
        line.Margin = new Thickness(x - 1, 0, 0, 0);
        handle.HorizontalAlignment = HorizontalAlignment.Left;
        handle.VerticalAlignment = VerticalAlignment.Top;
        handle.Margin = new Thickness(Math.Clamp(x - 22, 0, Math.Max(0, w - 44)), Math.Max(0, h / 2 - 22), 0, 0);
        percentage.Text = $"{scale * (XamlRoot?.RasterizationScale ?? 1) * 100:0}%";
        AutomationProperties.SetName(percentage, $"预览缩放 {percentage.Text}");
        AutomationProperties.SetAutomationId(percentage, "preview.zoomValue");
    }
    private void Press(object sender, PointerRoutedEventArgs e)
    {
        var source = e.OriginalSource as DependencyObject;
        while (source is not null) { if (source == handle) return; source = VisualTreeHelper.GetParent(source); }
        var p = e.GetCurrentPoint(viewport);
        if (!p.Properties.IsLeftButtonPressed) return;
        draggingDivider = Math.Abs(p.Position.X - viewport.ActualWidth * split) <= 24;
        draggingPan = !draggingDivider && !fit;
        if (!draggingDivider && !draggingPan) return;
        lastPoint = p.Position;
        viewport.CapturePointer(e.Pointer);
        e.Handled = true;
    }
    private void Move(object sender, PointerRoutedEventArgs e)
    {
        var p = e.GetCurrentPoint(viewport).Position;
        if (draggingDivider) Split = p.X / Math.Max(1, viewport.ActualWidth);
        else if (draggingPan) { offsetX += p.X - lastPoint.X; offsetY += p.Y - lastPoint.Y; LayoutImages(); }
        else return;
        lastPoint = p; e.Handled = true;
    }
    private void Release(object sender, PointerRoutedEventArgs e) { draggingDivider = draggingPan = false; viewport.ReleasePointerCaptures(); }

    private sealed class DividerHandle : UserControl
    {
        private readonly ComparisonPreview owner;
        public DividerHandle(ComparisonPreview owner)
        {
            this.owner = owner;
            Content = new Border
            {
                Background = new SolidColorBrush(Microsoft.UI.Colors.White),
                BorderBrush = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(36, 0, 0, 0)),
                BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(22),
                Child = new TextBlock { Text = "↔", FontSize = 20, Foreground = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 24, 38, 45)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, IsHitTestVisible = false }
            };
            var dragging = false;
            PointerPressed += (_, e) =>
            {
                if (!e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) return;
                dragging = CapturePointer(e.Pointer);
                e.Handled = true;
            };
            PointerMoved += (_, e) =>
            {
                if (!dragging) return;
                owner.Split = e.GetCurrentPoint(owner.viewport).Position.X / Math.Max(1, owner.viewport.ActualWidth);
                e.Handled = true;
            };
            PointerReleased += (_, e) => { dragging = false; ReleasePointerCaptures(); e.Handled = true; };
            PointerCaptureLost += (_, _) => dragging = false;
            PointerCanceled += (_, _) => dragging = false;
            IsTabStop = true;
        }
        protected override AutomationPeer OnCreateAutomationPeer() => new DividerPeer(this, owner);
        protected override void OnKeyDown(KeyRoutedEventArgs e)
        {
            if (e.Key is VirtualKey.Left or VirtualKey.Right or VirtualKey.Home or VirtualKey.End)
            {
                owner.Split = e.Key switch { VirtualKey.Home => .02, VirtualKey.End => .98, VirtualKey.Left => owner.Split - .05, _ => owner.Split + .05 };
                e.Handled = true;
            }
            else base.OnKeyDown(e);
        }
    }
    private sealed class ComparisonPeer(ComparisonPreview owner) : FrameworkElementAutomationPeer(owner)
    {
        protected override AutomationControlType GetAutomationControlTypeCore() => AutomationControlType.Group;
        protected override string GetClassNameCore() => "ComparisonPreview";
    }
    private sealed class DividerPeer(DividerHandle control, ComparisonPreview owner) : FrameworkElementAutomationPeer(control), IRangeValueProvider
    {
        protected override AutomationControlType GetAutomationControlTypeCore() => AutomationControlType.Slider;
        protected override string GetClassNameCore() => "ComparisonDivider";
        protected override object GetPatternCore(PatternInterface pattern) => pattern == PatternInterface.RangeValue ? this : base.GetPatternCore(pattern);
        public bool IsReadOnly => false;
        public double LargeChange => 10;
        public double SmallChange => 1;
        public double Maximum => 98;
        public double Minimum => 2;
        public double Value => owner.Split * 100;
        public void SetValue(double value) => owner.Split = value / 100;
    }
}
