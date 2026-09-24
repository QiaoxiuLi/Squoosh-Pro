using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using SquooshPro.Core;
using Windows.ApplicationModel.DataTransfer;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Storage.Streams;
using WinRT.Interop;

namespace SquooshPro.Windows;

public sealed class MainWindow : Window
{
    private static readonly string[] SupportedExtensions = [".jpg", ".jpeg", ".png", ".webp", ".avif", ".heic", ".heif", ".ppm"];
    private readonly CompressionEngine engine = new();
    private readonly PreviewCache previewCache = new();
    private readonly ObservableCollection<WorkspaceItem> items = [];
    private readonly List<CompressionPreset> userPresets;
    private readonly AppPreferences preferences;
    private readonly string[] startupArguments;
    private readonly NavigationView navigation = new();
    private readonly Grid pageHost = new();
    private readonly Grid compressionBody = new();
    private readonly ListView queueList = new();
    private readonly AutoSuggestBox searchBox = new();
    private readonly TabView detailTabs = new();
    private readonly Image originalImage = new();
    private readonly Image outputImage = new();
    private readonly Grid previewCanvas = new();
    private readonly RectangleGeometry outputClip = new();
    private readonly Slider previewDivider = new();
    private readonly TextBlock previewStatus = new();
    private readonly TextBlock previewMetrics = new();
    private readonly ComboBox presetBox = new();
    private readonly ComboBox formatBox = new();
    private readonly ComboBox strategyBox = new();
    private readonly Slider qualitySlider = new();
    private readonly TextBlock qualityValue = new();
    private readonly NumberBox targetSize = new();
    private readonly ComboBox resizeBox = new();
    private readonly NumberBox widthBox = new();
    private readonly NumberBox heightBox = new();
    private readonly CheckBox noUpscale = new();
    private readonly ComboBox metadataBox = new();
    private readonly CheckBox progressive = new();
    private readonly CheckBox optimizeCoding = new();
    private readonly CheckBox baseline = new();
    private readonly TextBlock outputLocation = new();
    private readonly TextBlock batchStatus = new();
    private readonly ProgressBar batchProgress = new();
    private readonly AppBarButton startButton = new();
    private readonly AppBarButton pauseButton = new();
    private readonly AppBarButton cancelButton = new();
    private readonly AppBarButton clearButton = new();
    private readonly Button retryButton = new();
    private readonly Button openOutputButton = new();
    private readonly CompressionPreset initialPreset = Presets.WebJpeg150Kb;
    private CompressionPreset selectedPreset;
    private WorkspaceItem? selectedItem;
    private EncodedImageResult? selectedPreview;
    private string? selectedPreviewKey;
    private string? currentOutputDirectory;
    private CancellationTokenSource? previewCancellation;
    private CancellationTokenSource? batchCancellation;
    private bool isRunning;
    private bool isPaused;
    private bool syncingSettings;
    private bool refreshingQueue;
    private FrameworkElement? workspaceView;
    private FrameworkElement? compressionPageView;
    private DispatcherTimer? testRenderTimer;
    private string? testRenderDirectory;
    private bool testRenderCaptureRunning;
    private bool? compactNavigation;

    public MainWindow(string[] startupArguments)
    {
        this.startupArguments = startupArguments;
        preferences = UserStorage.LoadPreferences();
        userPresets = UserStorage.LoadPresets();
        selectedPreset = initialPreset.DeepClone();
        Title = "Squoosh Pro";
        BuildWindow();
        ConfigureWindow();
        MarkPreviewStartup();
        Closed += (_, _) =>
        {
            testRenderTimer?.Stop();
            batchCancellation?.Cancel();
            previewCancellation?.Cancel();
            previewCache.Clear();
            TryDeleteStartupMarker();
        };
        Activated += OnFirstActivated;
    }

    private void ConfigureWindow()
    {
        var handle = WindowNative.GetWindowHandle(this);
        var id = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(handle);
        var appWindow = AppWindow.GetFromWindowId(id);
        appWindow.Resize(new global::Windows.Graphics.SizeInt32(1280, 800));
    }

    private void BuildWindow()
    {
        navigation.IsBackButtonVisible = NavigationViewBackButtonVisible.Collapsed;
        navigation.IsSettingsVisible = false;
        navigation.PaneDisplayMode = NavigationViewPaneDisplayMode.LeftCompact;
        navigation.OpenPaneLength = 190;
        navigation.CompactPaneLength = 48;
        navigation.SizeChanged += (_, args) => UpdateNavigationForWidth(args.NewSize.Width);
        navigation.Header = "压缩";
        navigation.MenuItems.Add(NavigationItem("压缩", Symbol.Edit, "compress"));
        navigation.MenuItems.Add(NavigationItem("预设", Symbol.Library, "presets"));
        navigation.MenuItems.Add(NavigationItem("历史记录", Symbol.Clock, "history"));
        navigation.MenuItems.Add(NavigationItem("设置", Symbol.Setting, "settings"));
        navigation.SelectedItem = navigation.MenuItems[0];
        navigation.SelectionChanged += NavigationSelectionChanged;
        navigation.Content = pageHost;
        Content = navigation;
        ShowCompressionPage();
    }

    private static NavigationViewItem NavigationItem(string title, Symbol symbol, string tag)
    {
        var item = new NavigationViewItem { Content = title, Icon = new SymbolIcon(symbol), Tag = tag };
        AutomationProperties.SetAutomationId(item, $"nav.{tag}");
        return item;
    }

    private void UpdateNavigationForWidth(double width)
    {
        var compact = width < 1100;
        if (compactNavigation == compact) return;
        compactNavigation = compact;
        navigation.IsPaneOpen = !compact;
    }

    private void NavigationSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItemContainer?.Tag is not string tag) return;
        navigation.Header = args.SelectedItemContainer.Content;
        switch (tag)
        {
            case "compress": ShowCompressionPage(); break;
            case "presets": ShowPresetsPage(); break;
            case "history": ShowHistoryPage(); break;
            case "settings": ShowApplicationSettingsPage(); break;
        }
    }

    private void ShowCompressionPage()
    {
        pageHost.Children.Clear();
        if (compressionPageView is null)
        {
            var root = new Grid();
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.Children.Add(BuildCommandBar());
            BuildCompressionBody();
            Grid.SetRow(compressionBody, 1);
            root.Children.Add(compressionBody);
            var summary = BuildBatchSummary();
            Grid.SetRow(summary, 2);
            root.Children.Add(summary);
            compressionPageView = root;
        }
        pageHost.Children.Add(compressionPageView);
        RefreshCompressionBody();
    }

    private CommandBar BuildCommandBar()
    {
        var bar = new CommandBar
        {
            DefaultLabelPosition = CommandBarDefaultLabelPosition.Right,
            IsDynamicOverflowEnabled = false,
            OverflowButtonVisibility = CommandBarOverflowButtonVisibility.Collapsed
        };
        var addImages = AppBar("添加图片", Symbol.Add, "toolbar.addImages", async () => await ChooseImagesAsync());
        var addFolder = AppBar("添加文件夹", Symbol.Folder, "toolbar.addFolder", async () => await ChooseFolderAsync());
        clearButton.Label = "清空";
        clearButton.Icon = new SymbolIcon(Symbol.Delete);
        clearButton.IsCompact = false;
        AutomationProperties.SetAutomationId(clearButton, "toolbar.clear");
        clearButton.Click += (_, _) => ClearItems();
        startButton.Label = "开始压缩";
        startButton.Icon = new SymbolIcon(Symbol.Play);
        startButton.IsCompact = false;
        AutomationProperties.SetAutomationId(startButton, "toolbar.start");
        startButton.Click += async (_, _) => await StartBatchAsync();
        pauseButton.Label = "暂停";
        pauseButton.Icon = new SymbolIcon(Symbol.Pause);
        pauseButton.IsCompact = false;
        pauseButton.Visibility = Visibility.Collapsed;
        AutomationProperties.SetAutomationId(pauseButton, "toolbar.pauseResume");
        pauseButton.Click += (_, _) => TogglePause();
        cancelButton.Label = "取消";
        cancelButton.Icon = new SymbolIcon(Symbol.Cancel);
        cancelButton.IsCompact = false;
        cancelButton.Visibility = Visibility.Collapsed;
        AutomationProperties.SetAutomationId(cancelButton, "toolbar.cancel");
        cancelButton.Click += (_, _) => batchCancellation?.Cancel();
        bar.PrimaryCommands.Add(addImages);
        bar.PrimaryCommands.Add(addFolder);
        bar.PrimaryCommands.Add(clearButton);
        bar.PrimaryCommands.Add(startButton);
        bar.PrimaryCommands.Add(pauseButton);
        bar.PrimaryCommands.Add(cancelButton);
        return bar;
    }

    private static AppBarButton AppBar(string label, Symbol symbol, string automationId, Func<Task> action)
    {
        var button = new AppBarButton { Label = label, Icon = new SymbolIcon(symbol), IsCompact = false };
        AutomationProperties.SetAutomationId(button, automationId);
        button.Click += async (_, _) => await action();
        return button;
    }

    private void BuildCompressionBody()
    {
        if (compressionBody.Children.Count > 0) return;
        compressionBody.AllowDrop = true;
        compressionBody.DragOver += (_, args) => { args.AcceptedOperation = DataPackageOperation.Copy; args.DragUIOverride.Caption = "添加到 Squoosh Pro"; };
        compressionBody.Drop += CompressionDrop;
        compressionBody.Margin = new Thickness(16, 8, 16, 8);
        compressionBody.Children.Add(BuildEmptyWorkspace());
    }

    private FrameworkElement BuildWorkspace()
    {
        var workspace = new Grid();
        workspace.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(290), MinWidth = 230 });
        workspace.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(12) });
        workspace.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star), MinWidth = 420 });

        var queueCard = Card();
        var queue = new Grid { Padding = new Thickness(12) };
        queue.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        queue.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        queue.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        queue.Children.Add(new TextBlock { Text = "图片", FontSize = 20, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 10) });
        searchBox.PlaceholderText = "搜索图片";
        AutomationProperties.SetAutomationId(searchBox, "queue.search");
        AutomationProperties.SetName(searchBox, "搜索图片");
        searchBox.TextChanged += (_, _) => RefreshQueue();
        Grid.SetRow(searchBox, 1);
        queue.Children.Add(searchBox);
        queueList.SelectionChanged += QueueSelectionChanged;
        AutomationProperties.SetAutomationId(queueList, "queue.list");
        Grid.SetRow(queueList, 2);
        queueList.Margin = new Thickness(0, 10, 0, 0);
        queue.Children.Add(queueList);
        queueCard.Child = queue;
        workspace.Children.Add(queueCard);

        detailTabs.TabItems.Add(new TabViewItem { Header = "效果预览", IconSource = new SymbolIconSource { Symbol = Symbol.Preview }, Content = BuildPreviewPane(), IsClosable = false });
        detailTabs.TabItems.Add(new TabViewItem { Header = "压缩设置", IconSource = new SymbolIconSource { Symbol = Symbol.Setting }, Content = BuildSettingsPane(), IsClosable = false });
        detailTabs.IsAddTabButtonVisible = false;
        detailTabs.CanDragTabs = false;
        AutomationProperties.SetAutomationId(detailTabs, "workspace.tabs");
        Grid.SetColumn(detailTabs, 2);
        workspace.Children.Add(detailTabs);
        return workspace;
    }

    private UIElement BuildPreviewPane()
    {
        var card = Card();
        var root = new Grid { Padding = new Thickness(16) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        previewStatus.Text = "选择图片后查看效果";
        previewStatus.FontSize = 16;
        previewStatus.FontWeight = Microsoft.UI.Text.FontWeights.SemiBold;
        AutomationProperties.SetAutomationId(previewStatus, "preview.status");
        root.Children.Add(previewStatus);

        previewCanvas.Background = new SolidColorBrush(Microsoft.UI.Colors.WhiteSmoke);
        previewCanvas.Margin = new Thickness(0, 12, 0, 10);
        originalImage.Stretch = Stretch.Uniform;
        outputImage.Stretch = Stretch.Uniform;
        outputImage.Clip = outputClip;
        previewCanvas.Children.Add(originalImage);
        previewCanvas.Children.Add(outputImage);
        var labels = new Grid { IsHitTestVisible = false, Padding = new Thickness(10) };
        labels.ColumnDefinitions.Add(new ColumnDefinition());
        labels.ColumnDefinitions.Add(new ColumnDefinition());
        labels.Children.Add(Badge("原图", HorizontalAlignment.Left));
        var outputLabel = Badge("输出", HorizontalAlignment.Right);
        Grid.SetColumn(outputLabel, 1);
        labels.Children.Add(outputLabel);
        previewCanvas.Children.Add(labels);
        previewCanvas.SizeChanged += (_, _) => UpdatePreviewClip();
        Grid.SetRow(previewCanvas, 1);
        root.Children.Add(previewCanvas);

        var footer = new Grid();
        footer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        footer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        previewDivider.Minimum = 0;
        previewDivider.Maximum = 100;
        previewDivider.Value = 50;
        previewDivider.Header = "原图 / 输出对比";
        AutomationProperties.SetAutomationId(previewDivider, "preview.divider");
        AutomationProperties.SetName(previewDivider, "原图 / 输出对比");
        previewDivider.ValueChanged += (_, _) => UpdatePreviewClip();
        footer.Children.Add(previewDivider);
        previewMetrics.Text = "预计输出 — · 输出尺寸 —";
        previewMetrics.Margin = new Thickness(0, 6, 0, 0);
        previewMetrics.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray);
        AutomationProperties.SetAutomationId(previewMetrics, "preview.metrics");
        Grid.SetRow(previewMetrics, 1);
        footer.Children.Add(previewMetrics);
        Grid.SetRow(footer, 2);
        root.Children.Add(footer);
        card.Child = root;
        return card;
    }

    private UIElement BuildSettingsPane()
    {
        var panel = new StackPanel { Spacing = 16, Padding = new Thickness(16), MaxWidth = 760, HorizontalAlignment = HorizontalAlignment.Left };
        panel.Children.Add(Heading("压缩设置"));
        presetBox.ItemsSource = AllPresets().Select(value => value.Name).ToList();
        presetBox.SelectedIndex = AllPresets().FindIndex(value => value.Id == selectedPreset.Id);
        presetBox.SelectionChanged += PresetSelectionChanged;
        AutomationProperties.SetAutomationId(presetBox, "settings.purpose");
        panel.Children.Add(SettingRow("用途", presetBox, "选择适合当前图片的压缩方案。"));

        formatBox.ItemsSource = new[] { "自动", "JPEG（JPG）", "PNG", "WebP", "AVIF" };
        formatBox.SelectionChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(formatBox, "settings.format");
        panel.Children.Add(SettingRow("输出格式", formatBox));

        strategyBox.ItemsSource = new[] { "指定质量", "每张不超过指定大小" };
        strategyBox.SelectionChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(strategyBox, "settings.strategy");
        panel.Children.Add(SettingRow("压缩方式", strategyBox));

        var qualityPanel = new Grid();
        qualityPanel.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        qualityPanel.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(52) });
        qualitySlider.Minimum = 0;
        qualitySlider.Maximum = 100;
        qualitySlider.StepFrequency = 1;
        qualitySlider.ValueChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(qualitySlider, "settings.quality");
        qualityPanel.Children.Add(qualitySlider);
        qualityValue.HorizontalAlignment = HorizontalAlignment.Right;
        qualityValue.VerticalAlignment = VerticalAlignment.Center;
        Grid.SetColumn(qualityValue, 1);
        qualityPanel.Children.Add(qualityValue);
        panel.Children.Add(SettingRow("质量", qualityPanel, "数值越高通常越清晰，文件也越大。"));

        targetSize.Minimum = 1;
        targetSize.Maximum = 1_000_000;
        targetSize.SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline;
        targetSize.ValueChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(targetSize, "settings.targetSizeKB");
        panel.Children.Add(SettingRow("每张不超过", targetSize, "单位为 KB，1 KB 按 1000 字节计算。"));

        resizeBox.ItemsSource = new[] { "保持原尺寸", "最长边", "固定宽度", "固定高度", "适合指定范围", "自动选择宽度" };
        resizeBox.SelectionChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(resizeBox, "settings.resizeMode");
        panel.Children.Add(SettingRow("图片尺寸", resizeBox));

        widthBox.Minimum = 1;
        widthBox.Maximum = 100_000;
        widthBox.ValueChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(widthBox, "settings.width");
        panel.Children.Add(SettingRow("宽度 / 最长边", widthBox, "“适合指定范围”会完整保留图片，不会裁切。"));
        heightBox.Minimum = 1;
        heightBox.Maximum = 100_000;
        heightBox.ValueChanged += SettingsChanged;
        AutomationProperties.SetAutomationId(heightBox, "settings.height");
        panel.Children.Add(SettingRow("高度", heightBox));
        noUpscale.Content = "小图片保持原尺寸";
        noUpscale.Checked += SettingsChanged;
        noUpscale.Unchecked += SettingsChanged;
        AutomationProperties.SetAutomationId(noUpscale, "settings.noUpscale");
        panel.Children.Add(SettingRow("放大规则", noUpscale, "开启后，尺寸已经较小的图片不会被放大。"));

        var outputPanel = new StackPanel { Spacing = 6 };
        outputLocation.TextWrapping = TextWrapping.Wrap;
        outputLocation.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray);
        outputPanel.Children.Add(outputLocation);
        var chooseOutput = new Button { Content = "选择位置…" };
        AutomationProperties.SetAutomationId(chooseOutput, "settings.outputDirectory");
        chooseOutput.Click += async (_, _) => await ChooseOutputAsync();
        outputPanel.Children.Add(chooseOutput);
        panel.Children.Add(SettingRow("输出位置", outputPanel));

        var advanced = new Expander { Header = "高级设置（始终生效）", IsExpanded = false };
        AutomationProperties.SetAutomationId(advanced, "settings.advanced");
        var advancedPanel = new StackPanel { Spacing = 12, Padding = new Thickness(0, 10, 0, 4) };
        advancedPanel.Children.Add(new TextBlock { Text = "展开或收起只改变显示，已设置选项始终应用。", TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) });
        metadataBox.ItemsSource = new[] { "删除隐私信息", "删除所有信息", "保留常用信息", "保留全部信息" };
        metadataBox.SelectionChanged += SettingsChanged;
        advancedPanel.Children.Add(SettingRow("元数据", metadataBox));
        advancedPanel.Children.Add(new TextBlock { Text = "透明区域：JPEG 自动填充为白色", TextWrapping = TextWrapping.Wrap });
        progressive.Content = "渐进式显示";
        progressive.Checked += ProgressiveChanged;
        progressive.Unchecked += ProgressiveChanged;
        AutomationProperties.SetAutomationId(progressive, "settings.progressive");
        advancedPanel.Children.Add(ExplainedOption(progressive, "settings.progressive.help", "网页加载时先显示整张粗略图片，再逐渐变清晰。主流浏览器均支持。"));
        optimizeCoding.Content = "优化文件大小";
        optimizeCoding.Checked += SettingsChanged;
        optimizeCoding.Unchecked += SettingsChanged;
        AutomationProperties.SetAutomationId(optimizeCoding, "settings.optimizeCoding");
        advancedPanel.Children.Add(ExplainedOption(optimizeCoding, "settings.optimizeCoding.help", "优化图片内部编码，通常能在相同质量下减小文件，压缩时间可能稍长。"));
        baseline.Content = "标准兼容模式";
        baseline.Checked += BaselineChanged;
        baseline.Unchecked += BaselineChanged;
        AutomationProperties.SetAutomationId(baseline, "settings.baseline");
        advancedPanel.Children.Add(ExplainedOption(baseline, "settings.baseline.help", "输出 Baseline JPEG，适合非常老旧的软件。现代浏览器通常不需要。"));
        advanced.Content = advancedPanel;
        panel.Children.Add(advanced);

        var savePreset = new Button { Content = "保存为预设", HorizontalAlignment = HorizontalAlignment.Stretch };
        AutomationProperties.SetAutomationId(savePreset, "settings.savePreset");
        savePreset.Click += async (_, _) => await SavePresetAsync();
        panel.Children.Add(savePreset);
        SyncControlsFromPreset();
        return new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }

    private static UIElement ExplainedOption(CheckBox option, string automationId, string explanation)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.Children.Add(option);
        var info = new Button
        {
            Content = "说明",
            Padding = new Thickness(8, 3, 8, 3),
            Flyout = new Flyout
            {
                Content = new TextBlock
                {
                    Text = explanation,
                    MaxWidth = 320,
                    TextWrapping = TextWrapping.Wrap
                }
            }
        };
        AutomationProperties.SetAutomationId(info, automationId);
        AutomationProperties.SetName(info, $"{option.Content}说明");
        ToolTipService.SetToolTip(info, explanation);
        Grid.SetColumn(info, 1);
        grid.Children.Add(info);
        return grid;
    }

    private static Border Card() => new()
    {
        Background = new SolidColorBrush(Microsoft.UI.Colors.Transparent),
        BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.LightGray),
        BorderThickness = new Thickness(1),
        CornerRadius = new CornerRadius(12)
    };

    private static TextBlock Heading(string text) => new() { Text = text, FontSize = 24, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold };

    private static Border Badge(string text, HorizontalAlignment alignment) => new()
    {
        HorizontalAlignment = alignment,
        VerticalAlignment = VerticalAlignment.Top,
        Background = new SolidColorBrush(ColorHelper.FromArgb(210, 32, 32, 32)),
        CornerRadius = new CornerRadius(10),
        Padding = new Thickness(9, 4, 9, 4),
        Child = new TextBlock { Text = text, Foreground = new SolidColorBrush(Microsoft.UI.Colors.White), FontSize = 12 }
    };

    private static UIElement SettingRow(string title, UIElement control, string? description = null)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(170) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var label = new TextBlock { Text = title, FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 7, 12, 0), TextWrapping = TextWrapping.Wrap };
        grid.Children.Add(label);
        var stack = new StackPanel { Spacing = 5 };
        stack.Children.Add(control);
        if (!string.IsNullOrWhiteSpace(description)) stack.Children.Add(new TextBlock { Text = description, FontSize = 13, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray), TextWrapping = TextWrapping.Wrap });
        Grid.SetColumn(stack, 1);
        grid.Children.Add(stack);
        return grid;
    }

    private FrameworkElement BuildBatchSummary()
    {
        var border = new Border { BorderThickness = new Thickness(0, 1, 0, 0), BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.LightGray), Padding = new Thickness(16, 9, 16, 9) };
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var left = new StackPanel { Spacing = 5 };
        batchStatus.Text = "添加图片后即可开始";
        AutomationProperties.SetAutomationId(batchStatus, "batch.status");
        left.Children.Add(batchStatus);
        batchProgress.Minimum = 0;
        batchProgress.Maximum = 1;
        batchProgress.Visibility = Visibility.Collapsed;
        AutomationProperties.SetAutomationId(batchProgress, "batch.progress");
        left.Children.Add(batchProgress);
        grid.Children.Add(left);
        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        retryButton.Content = "重试失败项";
        retryButton.Visibility = Visibility.Collapsed;
        retryButton.Click += async (_, _) => { foreach (var item in items.Where(value => value.State == FileState.failed)) { item.State = FileState.queued; item.ErrorMessage = null; } await StartBatchAsync(); };
        openOutputButton.Content = "打开输出目录";
        openOutputButton.Visibility = Visibility.Collapsed;
        openOutputButton.Click += (_, _) => OpenOutputDirectory();
        actions.Children.Add(retryButton);
        actions.Children.Add(openOutputButton);
        Grid.SetColumn(actions, 1);
        grid.Children.Add(actions);
        border.Child = grid;
        return border;
    }

    private void RefreshCompressionBody()
    {
        if (compressionBody.Children.Count == 0) return;
        compressionBody.Children.Clear();
        compressionBody.Children.Add(items.Count == 0 ? BuildEmptyWorkspace() : workspaceView ??= BuildWorkspace());
        startButton.IsEnabled = items.Count > 0 && !isRunning;
        clearButton.IsEnabled = items.Count > 0 && !isRunning;
    }

    private UIElement BuildEmptyWorkspace()
    {
        var outer = new Grid { MaxWidth = 980, HorizontalAlignment = HorizontalAlignment.Stretch, VerticalAlignment = VerticalAlignment.Center };
        var card = Card();
        card.Padding = new Thickness(32);
        var stack = new StackPanel { Spacing = 20 };
        stack.Children.Add(new TextBlock { Text = "Squoosh Pro", FontSize = 38, FontWeight = Microsoft.UI.Text.FontWeights.Bold });
        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        var chooseImages = new Button { Content = "选择图片", Padding = new Thickness(18, 10, 18, 10) };
        chooseImages.Click += async (_, _) => await ChooseImagesAsync();
        AutomationProperties.SetAutomationId(chooseImages, "empty.chooseImages");
        var chooseFolder = new Button { Content = "选择文件夹", Padding = new Thickness(18, 10, 18, 10) };
        chooseFolder.Click += async (_, _) => await ChooseFolderAsync();
        AutomationProperties.SetAutomationId(chooseFolder, "empty.chooseFolder");
        actions.Children.Add(chooseImages);
        actions.Children.Add(chooseFolder);
        stack.Children.Add(actions);
        stack.Children.Add(new TextBlock { Text = "选择压缩方案", FontSize = 20, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        var panel = new Grid { ColumnSpacing = 10, RowSpacing = 10 };
        panel.ColumnDefinitions.Add(new ColumnDefinition());
        panel.ColumnDefinitions.Add(new ColumnDefinition());
        panel.RowDefinitions.Add(new RowDefinition());
        panel.RowDefinitions.Add(new RowDefinition());
        var featured = new[] { Presets.Smart, Presets.WebsiteJpeg, Presets.WebJpeg150Kb, Presets.LosslessPng };
        for (var index = 0; index < featured.Length; index++)
        {
            var preset = featured[index];
            var button = new Button { Width = 260, Height = 82, Margin = new Thickness(0, 0, 10, 10), HorizontalContentAlignment = HorizontalAlignment.Left };
            var copy = new StackPanel { Spacing = 4 };
            copy.Children.Add(new TextBlock { Text = preset.Name, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
            copy.Children.Add(new TextBlock { Text = PresetDescription(preset), FontSize = 12, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray), TextWrapping = TextWrapping.Wrap });
            button.Content = copy;
            AutomationProperties.SetAutomationId(button, $"empty.preset.{preset.Id}");
            button.Click += (_, _) => { selectedPreset = preset.DeepClone(); SyncControlsFromPreset(); batchStatus.Text = $"已选择“{preset.Name}”，请添加图片"; };
            Grid.SetColumn(button, index % 2);
            Grid.SetRow(button, index / 2);
            panel.Children.Add(button);
        }
        stack.Children.Add(panel);
        card.Child = stack;
        outer.Children.Add(card);
        return outer;
    }

    private static string PresetDescription(CompressionPreset preset) => preset.Id switch
    {
        "system.smart" => "自动选择合适的格式和质量",
        "system.website-jpeg" => "兼容常用浏览器和设备",
        "system.web-jpeg-150kb" => "每张不超过 150 KB",
        "system.lossless-png" => "保留清晰度和透明区域",
        _ => preset.Notes ?? "使用保存的压缩设置"
    };

    private async void CompressionDrop(object sender, DragEventArgs args)
    {
        if (!args.DataView.Contains(StandardDataFormats.StorageItems)) return;
        var storageItems = await args.DataView.GetStorageItemsAsync();
        var paths = new List<string>();
        foreach (var item in storageItems)
        {
            if (item is StorageFile file) paths.Add(file.Path);
            if (item is StorageFolder folder) paths.AddRange(EnumerateFolder(folder.Path));
        }
        await AddPathsAsync(paths);
    }

    private async Task ChooseImagesAsync()
    {
        var picker = new FileOpenPicker { ViewMode = PickerViewMode.Thumbnail, SuggestedStartLocation = PickerLocationId.PicturesLibrary };
        foreach (var extension in SupportedExtensions.Where(value => value != ".ppm")) picker.FileTypeFilter.Add(extension);
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var files = await picker.PickMultipleFilesAsync();
        await AddPathsAsync(files.Select(file => file.Path));
    }

    private async Task ChooseFolderAsync()
    {
        var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.PicturesLibrary };
        picker.FileTypeFilter.Add("*");
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var folder = await picker.PickSingleFolderAsync();
        if (folder is not null) await AddPathsAsync(EnumerateFolder(folder.Path));
    }

    private IEnumerable<string> EnumerateFolder(string folder)
    {
        var option = preferences.RecursiveFolders ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
        try { return Directory.EnumerateFiles(folder, "*", option).Where(IsSupported).ToList(); }
        catch (Exception error) { batchStatus.Text = $"无法读取文件夹：{error.Message}"; return []; }
    }

    private async Task AddPathsAsync(IEnumerable<string> paths)
    {
        var existing = items.Select(value => value.Path).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var path in paths.Where(File.Exists).Where(IsSupported))
        {
            var full = Path.GetFullPath(path);
            if (!existing.Add(full)) continue;
            var item = new WorkspaceItem(full);
            items.Add(item);
            _ = LoadThumbnailAsync(item);
        }
        if (items.Count > 0 && selectedItem is null) selectedItem = items[0];
        RefreshCompressionBody();
        RefreshQueue();
        if (selectedItem is not null) await SelectItemAsync(selectedItem);
        batchStatus.Text = $"已添加 {items.Count} 张图片，选择方案后点击“开始压缩”";
    }

    private static bool IsSupported(string path) => SupportedExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);

    private async Task LoadThumbnailAsync(WorkspaceItem item)
    {
        try
        {
            var bytes = await engine.CreateDisplayPngAsync(item.Path, 160);
            item.Thumbnail = await BitmapFromBytesAsync(bytes);
            RefreshQueueRow(item);
        }
        catch { }
    }

    private void RefreshQueue()
    {
        if (queueList is null) return;
        refreshingQueue = true;
        var query = searchBox.Text?.Trim() ?? "";
        queueList.Items.Clear();
        foreach (var item in items.Where(value => string.IsNullOrEmpty(query) || value.FileName.Contains(query, StringComparison.CurrentCultureIgnoreCase)))
        {
            var row = new QueueRow(item);
            queueList.Items.Add(row);
            if (selectedItem == item) queueList.SelectedItem = row;
        }
        refreshingQueue = false;
    }

    private void RefreshQueueRow(WorkspaceItem item)
    {
        foreach (var row in queueList.Items.OfType<QueueRow>().Where(value => value.Item == item)) row.Refresh();
    }

    private async void QueueSelectionChanged(object sender, SelectionChangedEventArgs args)
    {
        if (refreshingQueue) return;
        if (queueList.SelectedItem is not QueueRow row) return;
        selectedItem = row.Item;
        detailTabs.SelectedIndex = 0;
        await SelectItemAsync(row.Item);
    }

    private async Task SelectItemAsync(WorkspaceItem item)
    {
        previewCancellation?.Cancel();
        previewCancellation = new CancellationTokenSource();
        var token = previewCancellation.Token;
        previewStatus.Text = "正在加载预览";
        try
        {
            var original = await engine.CreateDisplayPngAsync(item.Path, preferences.HardwarePreview ? 2400 : 1400, token);
            originalImage.Source = await BitmapFromBytesAsync(original);
            await Task.Delay(120, token);
            var preset = ReadPresetFromControls();
            var key = PreviewKey(item, preset);
            var result = previewCache.Get(key) ?? await engine.EncodeAsync(item.Path, preset, token);
            token.ThrowIfCancellationRequested();
            previewCache.Put(key, result);
            selectedPreview = result;
            selectedPreviewKey = key;
            item.IsCached = true;
            outputImage.Source = await BitmapFromBytesAsync(result.PreviewPng);
            previewStatus.Text = item.FileName;
            previewMetrics.Text = $"预计输出 {FormatBytes(result.Data.Length)} · 输出尺寸 {result.Width}×{result.Height} · 质量 {result.Quality}";
            RefreshQueueRow(item);
            UpdatePreviewClip();
        }
        catch (OperationCanceledException) { }
        catch (Exception error)
        {
            previewStatus.Text = "预览加载失败";
            previewMetrics.Text = FriendlyError(error);
        }
    }

    private void UpdatePreviewClip()
    {
        outputClip.Rect = new global::Windows.Foundation.Rect(0, 0, Math.Max(0, previewCanvas.ActualWidth * previewDivider.Value / 100d), Math.Max(0, previewCanvas.ActualHeight));
    }

    private static async Task<BitmapImage> BitmapFromBytesAsync(byte[] data)
    {
        using var stream = new InMemoryRandomAccessStream();
        using (var writer = new DataWriter(stream))
        {
            writer.WriteBytes(data);
            await writer.StoreAsync();
            await writer.FlushAsync();
            writer.DetachStream();
        }
        stream.Seek(0);
        var bitmap = new BitmapImage();
        await bitmap.SetSourceAsync(stream);
        return bitmap;
    }

    private string PreviewKey(WorkspaceItem item, CompressionPreset preset)
    {
        var info = new FileInfo(item.Path);
        var text = $"{item.Path}|{info.Length}|{info.LastWriteTimeUtc.Ticks}|{JsonSerializer.Serialize(preset, JsonOptions.Default)}";
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)));
    }

    private void PresetSelectionChanged(object sender, SelectionChangedEventArgs args)
    {
        if (syncingSettings || presetBox.SelectedIndex < 0) return;
        var all = AllPresets();
        if (presetBox.SelectedIndex >= all.Count) return;
        selectedPreset = all[presetBox.SelectedIndex].DeepClone();
        SyncControlsFromPreset();
        InvalidatePreview();
    }

    private List<CompressionPreset> AllPresets() => Presets.BuiltIns.Concat(userPresets).ToList();

    private void SyncControlsFromPreset()
    {
        if (formatBox is null || formatBox.Items.Count == 0) return;
        syncingSettings = true;
        presetBox.ItemsSource = AllPresets().Select(value => value.Name).ToList();
        presetBox.SelectedIndex = Math.Max(0, AllPresets().FindIndex(value => value.Id == selectedPreset.Id));
        formatBox.SelectedIndex = selectedPreset.Output.Format switch { CodecFormat.automatic => 0, CodecFormat.mozjpeg => 1, CodecFormat.oxipng => 2, CodecFormat.webp => 3, CodecFormat.avif => 4, _ => 1 };
        strategyBox.SelectedIndex = selectedPreset.Output.Strategy == CompressionStrategy.targetBytes ? 1 : 0;
        qualitySlider.Value = selectedPreset.Output.Quality;
        qualityValue.Text = selectedPreset.Output.Quality.ToString();
        targetSize.Value = (selectedPreset.Output.TargetBytes ?? 150_000) / 1000d;
        resizeBox.SelectedIndex = selectedPreset.Resize.Mode switch { ResizeMode.original => 0, ResizeMode.longestEdge => 1, ResizeMode.fixedWidth => 2, ResizeMode.fixedHeight => 3, ResizeMode.fitBox => 4, ResizeMode.adaptiveWidth => 5, _ => 0 };
        widthBox.Value = selectedPreset.Resize.Width ?? selectedPreset.Resize.LongestEdge ?? selectedPreset.Resize.CandidateWidths.FirstOrDefault(1000);
        heightBox.Value = selectedPreset.Resize.Height ?? 1080;
        noUpscale.IsChecked = !selectedPreset.Resize.AllowUpscale;
        metadataBox.SelectedIndex = selectedPreset.Metadata.Policy switch { MetadataPolicy.stripPrivate => 0, MetadataPolicy.stripAll => 1, MetadataPolicy.preserveSafe => 2, MetadataPolicy.preserveAll => 3, _ => 0 };
        progressive.IsChecked = selectedPreset.FormatOptions.GetValueOrDefault("progressive", 1) != 0;
        optimizeCoding.IsChecked = selectedPreset.FormatOptions.GetValueOrDefault("optimizeCoding", 1) != 0;
        baseline.IsChecked = selectedPreset.FormatOptions.GetValueOrDefault("baseline", 0) != 0;
        outputLocation.Text = preferences.OutputParent ?? "默认：在第一张原图旁创建带时间的文件夹";
        syncingSettings = false;
    }

    private CompressionPreset ReadPresetFromControls()
    {
        if (formatBox.Items.Count == 0) return selectedPreset.DeepClone();
        var preset = selectedPreset.DeepClone();
        preset.Output.Format = formatBox.SelectedIndex switch { 0 => CodecFormat.automatic, 1 => CodecFormat.mozjpeg, 2 => CodecFormat.oxipng, 3 => CodecFormat.webp, 4 => CodecFormat.avif, _ => preset.Output.Format };
        preset.Output.Strategy = strategyBox.SelectedIndex == 1 ? CompressionStrategy.targetBytes : CompressionStrategy.fixedQuality;
        preset.Output.Quality = Math.Clamp((int)Math.Round(qualitySlider.Value), 0, 100);
        var kb = double.IsNaN(targetSize.Value) ? 150 : Math.Clamp((int)Math.Round(targetSize.Value), 1, 1_000_000);
        preset.Output.TargetBytes = kb * 1000;
        preset.Output.SafetyTargetBytes = Math.Max(1, preset.Output.TargetBytes.Value - Math.Min(5000, preset.Output.TargetBytes.Value / 20));
        preset.Resize.Mode = resizeBox.SelectedIndex switch { 0 => ResizeMode.original, 1 => ResizeMode.longestEdge, 2 => ResizeMode.fixedWidth, 3 => ResizeMode.fixedHeight, 4 => ResizeMode.fitBox, 5 => ResizeMode.adaptiveWidth, _ => ResizeMode.original };
        var width = double.IsNaN(widthBox.Value) ? 1000 : Math.Max(1, (int)Math.Round(widthBox.Value));
        var height = double.IsNaN(heightBox.Value) ? 1080 : Math.Max(1, (int)Math.Round(heightBox.Value));
        preset.Resize.Width = width;
        preset.Resize.LongestEdge = width;
        preset.Resize.Height = height;
        if (preset.Resize.Mode == ResizeMode.adaptiveWidth && preset.Resize.CandidateWidths.Count == 0) preset.Resize.CandidateWidths = [1000, 960, 920];
        preset.Resize.AllowUpscale = noUpscale.IsChecked != true;
        preset.Metadata.Policy = metadataBox.SelectedIndex switch { 1 => MetadataPolicy.stripAll, 2 => MetadataPolicy.preserveSafe, 3 => MetadataPolicy.preserveAll, _ => MetadataPolicy.stripPrivate };
        preset.FormatOptions["progressive"] = progressive.IsChecked == true ? 1 : 0;
        preset.FormatOptions["optimizeCoding"] = optimizeCoding.IsChecked == true ? 1 : 0;
        preset.FormatOptions["baseline"] = baseline.IsChecked == true ? 1 : 0;
        Presets.Validate(preset);
        return preset;
    }

    private void SettingsChanged(object sender, object args)
    {
        if (syncingSettings) return;
        qualityValue.Text = Math.Clamp((int)Math.Round(qualitySlider.Value), 0, 100).ToString();
        InvalidatePreview();
    }

    private void ProgressiveChanged(object sender, RoutedEventArgs args)
    {
        if (syncingSettings) return;
        if (progressive.IsChecked == true) { syncingSettings = true; baseline.IsChecked = false; syncingSettings = false; }
        InvalidatePreview();
    }

    private void BaselineChanged(object sender, RoutedEventArgs args)
    {
        if (syncingSettings) return;
        if (baseline.IsChecked == true) { syncingSettings = true; progressive.IsChecked = false; syncingSettings = false; }
        InvalidatePreview();
    }

    private void InvalidatePreview()
    {
        selectedPreview = null;
        selectedPreviewKey = null;
        foreach (var item in items) item.IsCached = false;
        RefreshQueue();
        if (selectedItem is not null) _ = SelectItemAsync(selectedItem);
    }

    private async Task ChooseOutputAsync()
    {
        var picker = new FolderPicker();
        picker.FileTypeFilter.Add("*");
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var folder = await picker.PickSingleFolderAsync();
        if (folder is null) return;
        preferences.OutputParent = folder.Path;
        UserStorage.SavePreferences(preferences);
        outputLocation.Text = folder.Path;
    }

    private async Task SavePresetAsync()
    {
        var name = new TextBox { Header = "预设名称", PlaceholderText = "例如：商品图 150 KB", Text = $"{selectedPreset.Name} 副本" };
        var notes = new TextBox { Header = "备注（可选）", PlaceholderText = "说明这个预设适合什么图片" };
        var panel = new StackPanel { Spacing = 12 };
        panel.Children.Add(name);
        panel.Children.Add(notes);
        var dialog = new ContentDialog { Title = "保存预设", Content = panel, PrimaryButtonText = "保存预设", CloseButtonText = "取消", XamlRoot = pageHost.XamlRoot };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary || string.IsNullOrWhiteSpace(name.Text)) return;
        var preset = ReadPresetFromControls();
        preset.Id = $"user.{Guid.NewGuid():D}";
        preset.Name = name.Text.Trim();
        preset.Notes = string.IsNullOrWhiteSpace(notes.Text) ? null : notes.Text.Trim();
        preset.Kind = "user";
        userPresets.Add(preset);
        UserStorage.SavePresets(userPresets);
        selectedPreset = preset.DeepClone();
        SyncControlsFromPreset();
        batchStatus.Text = $"已保存预设“{preset.Name}”";
    }

    private async Task StartBatchAsync()
    {
        if (isRunning || items.Count == 0) return;
        CompressionPreset preset;
        try { preset = ReadPresetFromControls(); }
        catch (Exception error) { batchStatus.Text = FriendlyError(error); return; }
        isRunning = true;
        isPaused = false;
        batchCancellation = new CancellationTokenSource();
        var token = batchCancellation.Token;
        SetRunningUi(true);
        var parent = preferences.OutputParent ?? Path.GetDirectoryName(items[0].Path)!;
        currentOutputDirectory = CompressionEngine.CreateTimestampedDirectory(parent);
        var report = new JobReport
        {
            PresetID = preset.Id,
            OutputDirectoryName = Path.GetFileName(currentOutputDirectory),
            State = JobState.running,
            Items = items.Select(item => new JobItemRecord { ItemID = item.Id, SourceFileName = item.FileName, InputBytes = item.InputBytes }).ToList()
        };
        PersistReport(report);
        var completed = 0;
        try
        {
            foreach (var item in items.Where(value => value.State is FileState.queued or FileState.failed or FileState.cancelled))
            {
                token.ThrowIfCancellationRequested();
                while (isPaused) await Task.Delay(100, token);
                var record = report.Items.First(value => value.ItemID == item.Id);
                try
                {
                    UpdateItem(item, record, FileState.reading);
                    var key = PreviewKey(item, preset);
                    var cached = previewCache.Get(key);
                    UpdateItem(item, record, FileState.encoding);
                    if (cached is null) cached = await engine.EncodeAsync(item.Path, preset, token);
                    UpdateItem(item, record, FileState.verifying);
                    UpdateItem(item, record, FileState.committing);
                    var output = await engine.EncodeAndCommitAsync(item.Path, currentOutputDirectory, preset, cached, token);
                    item.OutputPath = output;
                    item.OutputBytes = new FileInfo(output).Length;
                    record.OutputFileName = Path.GetFileName(output);
                    record.OutputBytes = item.OutputBytes;
                    UpdateItem(item, record, FileState.completed);
                }
                catch (OperationCanceledException) { throw; }
                catch (Exception error)
                {
                    item.ErrorMessage = FriendlyError(error);
                    record.ErrorCode = error is SquooshException typed ? typed.Code : "unknown";
                    record.ErrorMessage = item.ErrorMessage;
                    UpdateItem(item, record, FileState.failed);
                }
                completed++;
                batchProgress.Value = completed / (double)items.Count;
                batchStatus.Text = $"已完成 {completed}/{items.Count}";
                PersistReport(report);
            }
            report.State = items.Any(value => value.State == FileState.failed) ? JobState.completedWithErrors : JobState.completed;
        }
        catch (OperationCanceledException)
        {
            report.State = JobState.cancelled;
            foreach (var item in items.Where(value => value.State is not FileState.completed and not FileState.failed)) item.State = FileState.cancelled;
            batchStatus.Text = "已取消，已完成的文件仍保留";
        }
        finally
        {
            PersistReport(report);
            isRunning = false;
            isPaused = false;
            SetRunningUi(false);
            previewCache.Clear();
            foreach (var item in items) item.IsCached = false;
            RefreshQueue();
            var failed = items.Count(value => value.State == FileState.failed);
            if (report.State == JobState.completed) batchStatus.Text = $"压缩完成：{items.Count} 张图片";
            if (report.State == JobState.completedWithErrors) batchStatus.Text = $"完成 {items.Count - failed} 张，失败 {failed} 张";
            retryButton.Visibility = failed > 0 ? Visibility.Visible : Visibility.Collapsed;
            openOutputButton.Visibility = Directory.Exists(currentOutputDirectory) ? Visibility.Visible : Visibility.Collapsed;
        }
    }

    private void PersistReport(JobReport report)
    {
        UserStorage.SaveJob(report);
        if (currentOutputDirectory is not null) UserStorage.AtomicWrite(Path.Combine(currentOutputDirectory, "manifest.json"), report);
    }

    private void UpdateItem(WorkspaceItem item, JobItemRecord record, FileState state)
    {
        item.State = state;
        record.State = state;
        RefreshQueueRow(item);
    }

    private void SetRunningUi(bool running)
    {
        startButton.Visibility = running ? Visibility.Collapsed : Visibility.Visible;
        pauseButton.Visibility = running ? Visibility.Visible : Visibility.Collapsed;
        cancelButton.Visibility = running ? Visibility.Visible : Visibility.Collapsed;
        clearButton.IsEnabled = !running;
        batchProgress.Visibility = running ? Visibility.Visible : Visibility.Collapsed;
        if (running) { batchProgress.Value = 0; retryButton.Visibility = Visibility.Collapsed; openOutputButton.Visibility = Visibility.Collapsed; }
    }

    private void TogglePause()
    {
        if (!isRunning) return;
        isPaused = !isPaused;
        pauseButton.Label = isPaused ? "继续" : "暂停";
        pauseButton.Icon = new SymbolIcon(isPaused ? Symbol.Play : Symbol.Pause);
        batchStatus.Text = isPaused ? "将在当前图片完成后暂停" : "正在继续压缩";
    }

    private void ClearItems()
    {
        if (isRunning) return;
        previewCancellation?.Cancel();
        items.Clear();
        selectedItem = null;
        selectedPreview = null;
        selectedPreviewKey = null;
        originalImage.Source = null;
        outputImage.Source = null;
        previewCache.Clear();
        batchStatus.Text = "添加图片后即可开始";
        currentOutputDirectory = null;
        RefreshCompressionBody();
    }

    private void OpenOutputDirectory()
    {
        if (Directory.Exists(currentOutputDirectory)) Process.Start(new ProcessStartInfo("explorer.exe", currentOutputDirectory!) { UseShellExecute = true });
    }

    private void ShowPresetsPage()
    {
        pageHost.Children.Clear();
        var panel = new StackPanel { Spacing = 16, Padding = new Thickness(24), MaxWidth = 900, HorizontalAlignment = HorizontalAlignment.Left };
        panel.Children.Add(new TextBlock { Text = "选择后会返回压缩页面。导出只包含你保存的预设，不包含系统预设。", TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) });
        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var import = new Button { Content = "导入预设…" };
        import.Click += async (_, _) => await ImportPresetsAsync();
        var export = new Button { Content = "导出我的预设…" };
        export.Click += async (_, _) => await ExportPresetsAsync();
        actions.Children.Add(import);
        actions.Children.Add(export);
        panel.Children.Add(actions);
        foreach (var preset in AllPresets())
        {
            var card = Card();
            card.Padding = new Thickness(14);
            var row = new Grid();
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var copy = new StackPanel { Spacing = 4 };
            copy.Children.Add(new TextBlock { Text = preset.Name, FontSize = 17, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
            copy.Children.Add(new TextBlock { Text = preset.Notes ?? PresetDescription(preset), TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) });
            row.Children.Add(copy);
            var select = new Button { Content = "选择" };
            select.Click += (_, _) => { selectedPreset = preset.DeepClone(); navigation.SelectedItem = navigation.MenuItems[0]; SyncControlsFromPreset(); };
            Grid.SetColumn(select, 1);
            row.Children.Add(select);
            card.Child = row;
            panel.Children.Add(card);
        }
        pageHost.Children.Add(new ScrollViewer { Content = panel });
    }

    private async Task ImportPresetsAsync()
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(".json");
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var file = await picker.PickSingleFileAsync();
        if (file is null) return;
        try
        {
            var text = await File.ReadAllTextAsync(file.Path);
            var imported = JsonSerializer.Deserialize<List<CompressionPreset>>(text, JsonOptions.Default)
                ?? [JsonSerializer.Deserialize<CompressionPreset>(text, JsonOptions.Default)!];
            foreach (var preset in imported.Where(value => value is not null))
            {
                Presets.Validate(preset);
                preset.Id = $"user.{Guid.NewGuid():D}";
                preset.Kind = "user";
                userPresets.Add(preset);
            }
            UserStorage.SavePresets(userPresets);
            ShowPresetsPage();
        }
        catch (Exception error) { await ShowMessageAsync("无法导入预设", FriendlyError(error)); }
    }

    private async Task ExportPresetsAsync()
    {
        if (userPresets.Count == 0) { await ShowMessageAsync("没有可导出的预设", "请先在压缩设置中保存自己的预设。"); return; }
        var picker = new FileSavePicker { SuggestedFileName = "Squoosh-Pro-我的预设" };
        picker.FileTypeChoices.Add("JSON", [".json"]);
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));
        var file = await picker.PickSaveFileAsync();
        if (file is not null) await File.WriteAllTextAsync(file.Path, JsonSerializer.Serialize(userPresets, JsonOptions.Default));
    }

    private void ShowHistoryPage()
    {
        pageHost.Children.Clear();
        var panel = new StackPanel { Spacing = 12, Padding = new Thickness(24), MaxWidth = 900, HorizontalAlignment = HorizontalAlignment.Left };
        var jobs = UserStorage.LoadJobs();
        if (jobs.Count == 0) panel.Children.Add(new TextBlock { Text = "还没有压缩记录。", Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) });
        foreach (var job in jobs)
        {
            var card = Card();
            card.Padding = new Thickness(14);
            var success = job.Items.Count(value => value.State == FileState.completed);
            var failed = job.Items.Count(value => value.State == FileState.failed);
            var stack = new StackPanel { Spacing = 4 };
            stack.Children.Add(new TextBlock { Text = job.CreatedAt.LocalDateTime.ToString("yyyy-MM-dd HH:mm"), FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
            stack.Children.Add(new TextBlock { Text = $"{job.OutputDirectoryName} · 成功 {success} · 失败 {failed} · {job.State}", TextWrapping = TextWrapping.Wrap });
            card.Child = stack;
            panel.Children.Add(card);
        }
        pageHost.Children.Add(new ScrollViewer { Content = panel });
    }

    private void ShowApplicationSettingsPage()
    {
        pageHost.Children.Clear();
        var panel = new StackPanel { Spacing = 18, Padding = new Thickness(24), MaxWidth = 760, HorizontalAlignment = HorizontalAlignment.Left };
        var recursive = new ToggleSwitch { Header = "读取子文件夹", IsOn = preferences.RecursiveFolders, OnContent = "开启", OffContent = "关闭" };
        recursive.Toggled += (_, _) => { preferences.RecursiveFolders = recursive.IsOn; UserStorage.SavePreferences(preferences); };
        panel.Children.Add(recursive);
        var hardware = new ToggleSwitch { Header = "硬件加速预览", IsOn = preferences.HardwarePreview, OnContent = "开启", OffContent = "关闭" };
        AutomationProperties.SetAutomationId(hardware, "settings.hardwareAcceleration");
        hardware.Toggled += (_, _) => { preferences.HardwarePreview = hardware.IsOn; UserStorage.SavePreferences(preferences); if (selectedItem is not null) _ = SelectItemAsync(selectedItem); };
        panel.Children.Add(hardware);
        panel.Children.Add(new TextBlock { Text = "开启时由 WinUI 使用系统图形管线缩放预览；如果上次启动在预览初始化前异常结束，应用会自动关闭此选项。该设置不改变输出图片。", TextWrapping = TextWrapping.Wrap, Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) });
        panel.Children.Add(new TextBlock { Text = "预览缓存最多保留 24 项或 128 MB，完成任务、清空或退出时会清理。", TextWrapping = TextWrapping.Wrap });
        panel.Children.Add(new TextBlock { Text = "Squoosh Pro 0.2.0 · Windows 10/11 x64", Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) });
        pageHost.Children.Add(new ScrollViewer { Content = panel });
    }

    private async Task ShowMessageAsync(string title, string message)
    {
        var dialog = new ContentDialog { Title = title, Content = new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap }, CloseButtonText = "关闭", XamlRoot = pageHost.XamlRoot };
        await dialog.ShowAsync();
    }

    private async void OnFirstActivated(object sender, WindowActivatedEventArgs args)
    {
        Activated -= OnFirstActivated;
        await Task.Delay(700);
        TryDeleteStartupMarker();
        string? input = null;
        string? output = null;
        string? renderDirectory = null;
        for (var index = 0; index < startupArguments.Length; index++)
        {
            if (startupArguments[index] == "--test-input" && index + 1 < startupArguments.Length) input = startupArguments[++index];
            if (startupArguments[index] == "--test-output" && index + 1 < startupArguments.Length) output = startupArguments[++index];
            if (startupArguments[index] == "--test-render-directory" && index + 1 < startupArguments.Length) renderDirectory = startupArguments[++index];
        }
        if (!string.IsNullOrWhiteSpace(renderDirectory)) StartTestRenderChannel(renderDirectory);
        if (!string.IsNullOrWhiteSpace(output)) { preferences.OutputParent = output; outputLocation.Text = output; }
        if (!string.IsNullOrWhiteSpace(input)) await AddPathsAsync([input]);
    }

    private void StartTestRenderChannel(string directory)
    {
        testRenderDirectory = Path.GetFullPath(directory);
        Directory.CreateDirectory(testRenderDirectory);
        testRenderTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(150) };
        testRenderTimer.Tick += TestRenderTimerTick;
        testRenderTimer.Start();
    }

    private async void TestRenderTimerTick(object? sender, object args)
    {
        if (testRenderCaptureRunning || testRenderDirectory is null) return;
        var request = Directory.EnumerateFiles(testRenderDirectory, "*.request").OrderBy(value => value).FirstOrDefault();
        if (request is null) return;
        testRenderCaptureRunning = true;
        var name = Path.GetFileNameWithoutExtension(request);
        var output = Path.Combine(testRenderDirectory, name + ".png");
        var errorOutput = Path.Combine(testRenderDirectory, name + ".error.txt");
        try
        {
            await CaptureVisualTreeAsync(output);
        }
        catch (Exception error)
        {
            await File.WriteAllTextAsync(errorOutput, error.ToString());
        }
        finally
        {
            try { File.Delete(request); } catch { }
            testRenderCaptureRunning = false;
        }
    }

    private async Task CaptureVisualTreeAsync(string path)
    {
        if (Content is not UIElement root) throw new InvalidOperationException("The window does not have a renderable root element.");
        var bitmap = new RenderTargetBitmap();
        await bitmap.RenderAsync(root);
        if (bitmap.PixelWidth < 1 || bitmap.PixelHeight < 1) throw new InvalidOperationException("WinUI returned an empty render target.");
        var pixels = await bitmap.GetPixelsAsync();
        using var pixelReader = DataReader.FromBuffer(pixels);
        var pixelData = new byte[pixels.Length];
        pixelReader.ReadBytes(pixelData);
        using var stream = new InMemoryRandomAccessStream();
        var encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, stream);
        encoder.SetPixelData(
            BitmapPixelFormat.Bgra8,
            BitmapAlphaMode.Premultiplied,
            (uint)bitmap.PixelWidth,
            (uint)bitmap.PixelHeight,
            96,
            96,
            pixelData);
        await encoder.FlushAsync();
        stream.Seek(0);
        using var reader = new DataReader(stream.GetInputStreamAt(0));
        await reader.LoadAsync((uint)stream.Size);
        var data = new byte[(int)stream.Size];
        reader.ReadBytes(data);
        await File.WriteAllBytesAsync(path, data);
    }

    private void MarkPreviewStartup()
    {
        try
        {
            Directory.CreateDirectory(UserStorage.Root);
            if (File.Exists(UserStorage.StartupMarkerPath))
            {
                preferences.HardwarePreview = false;
                UserStorage.SavePreferences(preferences);
            }
            File.WriteAllText(UserStorage.StartupMarkerPath, DateTimeOffset.Now.ToString("O"));
        }
        catch { }
    }

    private static void TryDeleteStartupMarker()
    {
        try { if (File.Exists(UserStorage.StartupMarkerPath)) File.Delete(UserStorage.StartupMarkerPath); } catch { }
    }

    private static string FriendlyError(Exception error) => error switch
    {
        SquooshException typed => typed.Message,
        UnauthorizedAccessException => "没有读取或写入权限",
        IOException => "文件正在使用或磁盘空间不足",
        _ => $"操作失败：{error.Message}"
    };

    private static string FormatBytes(long bytes) => bytes >= 1_000_000 ? $"{bytes / 1_000_000d:0.0} MB" : $"{bytes / 1000d:0.#} KB";
}
