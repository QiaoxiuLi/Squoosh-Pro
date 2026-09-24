using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Automation;
using SquooshPro.Core;

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: SquooshPro.WindowsUiTests <SquooshPro.exe> <artifact-directory>");
    return 2;
}

var executable = Path.GetFullPath(args[0]);
var artifactBase = Path.GetFullPath(args[1]);
Directory.CreateDirectory(artifactBase);
var artifactRoot = Path.Combine(artifactBase, $"run-{DateTimeOffset.Now:yyyyMMdd-HHmmss}");
Directory.CreateDirectory(artifactRoot);
var input = Path.Combine(artifactRoot, "ui-test-input.png");
var outputParent = Path.Combine(artifactRoot, "output");
var renderDirectory = Path.Combine(artifactRoot, "rendered-ui");
Directory.CreateDirectory(outputParent);
Directory.CreateDirectory(renderDirectory);
var results = new List<UiCheck>();
Process? app = null;

void Record(string name, bool passed, string? detail = null)
{
    results.Add(new UiCheck(name, passed, detail));
    Console.WriteLine($"{(passed ? "PASS" : "FAIL")} {name}{(detail is null ? "" : $": {detail}")}");
}

async Task CaptureRenderedState(string name)
{
    var request = Path.Combine(renderDirectory, name + ".request");
    var imagePath = Path.Combine(renderDirectory, name + ".png");
    var errorPath = Path.Combine(renderDirectory, name + ".error.txt");
    await File.WriteAllTextAsync(request, DateTimeOffset.Now.ToString("O"));
    var completed = WaitUntil(() => File.Exists(imagePath) || File.Exists(errorPath), TimeSpan.FromSeconds(20));
    if (!completed)
    {
        Record(name + " visual render", false, "The application did not answer the render request");
        return;
    }
    if (File.Exists(errorPath))
    {
        Record(name + " visual render", false, await File.ReadAllTextAsync(errorPath));
        return;
    }
    var analysis = AnalyzeRenderedImage(imagePath);
    Record(name + " visual render", analysis.Passed, analysis.Detail);
}

try
{
    foreach (var process in Process.GetProcessesByName("SquooshPro"))
    {
        try { process.Kill(true); process.WaitForExit(5000); } catch { }
    }

    await CreateInputPng(input);
    var sourceHash = await Hash(input);
    app = Process.Start(new ProcessStartInfo(executable)
    {
        UseShellExecute = true,
        Arguments = $"--test-input \"{input}\" --test-output \"{outputParent}\" --test-data-root \"{Path.Combine(artifactRoot, "app-data")}\" --test-render-directory \"{renderDirectory}\""
    }) ?? throw new InvalidOperationException("Application process did not start");

    var window = WaitForWindow(app.Id, TimeSpan.FromSeconds(25));
    Record("main window created", window is not null, window?.Current.Name);
    if (window is null) throw new InvalidOperationException("Main window was not available to UI Automation");
    var hwnd = new IntPtr(window.Current.NativeWindowHandle);
    WaitUntil(() => GetWindowRect(hwnd, out var bounds) && bounds.Right - bounds.Left > 500 && bounds.Bottom - bounds.Top > 400, TimeSpan.FromSeconds(10));

    AutomationElement? search = null;
    WaitUntil(() => (search = Find(window, "queue.search") ?? FindByName(window, "搜索图片")) is not null, TimeSpan.FromSeconds(20));
    Record("image search control", search is not null);
    if (search?.TryGetCurrentPattern(ValuePattern.Pattern, out var searchPattern) == true && searchPattern is ValuePattern searchValue) searchValue.SetValue("ui-test");

    AutomationElement? divider = null;
    WaitUntil(() => (divider = Find(window, "preview.divider") ?? FindByName(window, "原图 / 输出对比")) is not null, TimeSpan.FromSeconds(20));
    Record("preview comparison slider", divider is not null);
    if (divider?.TryGetCurrentPattern(RangeValuePattern.Pattern, out var rangePattern) == true && rangePattern is RangeValuePattern range) range.SetValue(65);

    var previewStatus = Find(window, "preview.status");
    var previewReady = WaitUntil(() =>
    {
        previewStatus = Find(window, "preview.status");
        return previewStatus is not null && !previewStatus.Current.Name.Contains("正在加载");
    }, TimeSpan.FromSeconds(35));
    Record("preview rendered", previewReady, previewStatus?.Current.Name);
    Capture(hwnd, Path.Combine(artifactRoot, "01-workspace-desktop.png"));
    await CaptureRenderedState("01-workspace");

    Invoke(FindByName(window, "压缩设置"));
    AutomationElement? targetSize = null;
    AutomationElement? quality = null;
    AutomationElement? savePreset = null;
    WaitUntil(() =>
    {
        targetSize = Find(window, "settings.targetSizeKB");
        quality = Find(window, "settings.quality");
        savePreset = Find(window, "settings.savePreset");
        return targetSize is not null && quality is not null && savePreset is not null;
    }, TimeSpan.FromSeconds(8));
    Record("target size setting", targetSize is not null);
    Record("quality slider setting", quality is not null);
    Record("save preset command", savePreset is not null);
    var advanced = Find(window, "settings.advanced");
    if (advanced?.TryGetCurrentPattern(ExpandCollapsePattern.Pattern, out var expandObject) == true && expandObject is ExpandCollapsePattern expand)
        expand.Expand();
    AutomationElement? progressiveHelp = null;
    WaitUntil(() => (progressiveHelp = Find(window, "settings.progressive.help")) is not null, TimeSpan.FromSeconds(5));
    Record("advanced option explanation command", progressiveHelp is not null);
    Invoke(progressiveHelp);
    var explanation = "网页加载时先显示整张粗略图片，再逐渐变清晰。主流浏览器均支持。";
    var explanationVisible = WaitUntil(() => FindByName(AutomationElement.RootElement, explanation) is not null, TimeSpan.FromSeconds(5));
    Record("advanced option explanation opens", explanationVisible);
    Capture(hwnd, Path.Combine(artifactRoot, "02-compression-settings-desktop.png"));
    await CaptureRenderedState("02-compression-settings");
    Invoke(FindByName(window, "效果预览"));
    Thread.Sleep(300);

    SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 920, 680, 0x0004 | 0x0010);
    Thread.Sleep(800);
    Capture(hwnd, Path.Combine(artifactRoot, "03-compact-desktop.png"));
    Record("compact window keeps start command", Find(window, "toolbar.start") is not null);
    var compactOutputLabel = FindByName(window, "输出");
    GetWindowRect(hwnd, out var compactBounds);
    var compactLabelBounds = compactOutputLabel?.Current.BoundingRectangle;
    var compactLabelVisible = compactLabelBounds is { Width: > 0, Height: > 0 }
        && compactLabelBounds.Value.Left >= compactBounds.Left
        && compactLabelBounds.Value.Right <= compactBounds.Right;
    Record("compact preview labels remain visible", compactLabelVisible, compactLabelBounds?.ToString());
    await CaptureRenderedState("03-compact");

    var settingsNav = Find(window, "nav.settings");
    Invoke(settingsNav);
    Thread.Sleep(700);
    var hardware = Find(window, "settings.hardwareAcceleration");
    Record("hardware acceleration setting", hardware is not null);
    if (hardware?.TryGetCurrentPattern(TogglePattern.Pattern, out var toggleObject) == true && toggleObject is TogglePattern toggle)
        Record("hardware acceleration defaults on", toggle.Current.ToggleState == ToggleState.On, toggle.Current.ToggleState.ToString());
    Capture(hwnd, Path.Combine(artifactRoot, "04-settings-desktop.png"));
    await CaptureRenderedState("04-settings");

    Invoke(Find(window, "nav.compress"));
    Thread.Sleep(500);
    var start = Find(window, "toolbar.start");
    Record("start compression command", start is not null);
    Invoke(start);

    var finished = WaitUntil(() => Directory.Exists(outputParent) && Directory.EnumerateFiles(outputParent, "*.jpg", SearchOption.AllDirectories).Any(), TimeSpan.FromSeconds(60));
    var output = finished ? Directory.EnumerateFiles(outputParent, "*.jpg", SearchOption.AllDirectories).First() : null;
    Record("UI batch produced JPEG", output is not null, output);
    if (output is not null)
    {
        var info = new FileInfo(output);
        Record("UI output is at most 150000 bytes", info.Length <= 150_000, info.Length.ToString());
        CompressionEngine.VerifyEncodedFile(output, CodecFormat.mozjpeg, ReadDimensions(output).Width, ReadDimensions(output).Height, 150_000);
        Record("UI output decodes and verifies", true, $"{ReadDimensions(output).Width}x{ReadDimensions(output).Height}");
    }
    Record("UI flow preserved source", sourceHash == await Hash(input));
    var batchState = Find(window, "batch.status");
    var batchFinished = WaitUntil(() =>
    {
        batchState = Find(window, "batch.status");
        return batchState is not null && (batchState.Current.Name.Contains("压缩完成") || batchState.Current.Name.StartsWith("完成"));
    }, TimeSpan.FromSeconds(20));
    Record("batch completion state", batchFinished, batchState?.Current.Name);
    Capture(hwnd, Path.Combine(artifactRoot, "05-completed-desktop.png"));
    await CaptureRenderedState("05-completed");
}
catch (Exception error)
{
    Record("UI test execution", false, error.ToString());
}
finally
{
    try { if (app is { HasExited: false }) { app.CloseMainWindow(); if (!app.WaitForExit(5000)) app.Kill(true); } } catch { }
    await File.WriteAllTextAsync(Path.Combine(artifactRoot, "ui-test-result.json"), JsonSerializer.Serialize(new UiTestResult(Environment.OSVersion.VersionString, DateTimeOffset.Now, results), JsonOptions.Default));
}

return results.All(value => value.Passed) ? 0 : 1;

static AutomationElement? WaitForWindow(int processId, TimeSpan timeout)
{
    AutomationElement? result = null;
    WaitUntil(() =>
    {
        result = AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, processId));
        result ??= AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.NameProperty, "Squoosh Pro"));
        return result is not null;
    }, timeout);
    return result;
}

static AutomationElement? Find(AutomationElement root, string automationId) =>
    root.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.AutomationIdProperty, automationId));

static AutomationElement? FindByName(AutomationElement root, string name) =>
    root.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, name));

static void Invoke(AutomationElement? element)
{
    if (element is null) return;
    if (element.TryGetCurrentPattern(InvokePattern.Pattern, out var invoke) && invoke is InvokePattern invokePattern) invokePattern.Invoke();
    else if (element.TryGetCurrentPattern(SelectionItemPattern.Pattern, out var selection) && selection is SelectionItemPattern selectionPattern) selectionPattern.Select();
}

static bool WaitUntil(Func<bool> condition, TimeSpan timeout)
{
    var watch = Stopwatch.StartNew();
    while (watch.Elapsed < timeout)
    {
        try { if (condition()) return true; } catch { }
        Thread.Sleep(200);
    }
    return false;
}

static void Capture(IntPtr hwnd, string path)
{
    if (!GetWindowRect(hwnd, out var rect)) throw new InvalidOperationException("Cannot read window bounds");
    var width = Math.Max(1, rect.Right - rect.Left);
    var height = Math.Max(1, rect.Bottom - rect.Top);
    using var bitmap = new Bitmap(width, height);
    using var graphics = Graphics.FromImage(bitmap);
    var deviceContext = graphics.GetHdc();
    var captured = false;
    try { captured = PrintWindow(hwnd, deviceContext, 2); }
    finally { graphics.ReleaseHdc(deviceContext); }
    if (!captured) graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, new Size(width, height));
    bitmap.Save(path, ImageFormat.Png);
}

static (bool Passed, string Detail) AnalyzeRenderedImage(string path)
{
    using var bitmap = new Bitmap(path);
    var sampleStep = Math.Max(1, Math.Min(bitmap.Width, bitmap.Height) / 180);
    var sampled = 0;
    var nonWhite = 0;
    var colors = new HashSet<int>();
    for (var y = 0; y < bitmap.Height; y += sampleStep)
    {
        for (var x = 0; x < bitmap.Width; x += sampleStep)
        {
            var color = bitmap.GetPixel(x, y);
            sampled++;
            if (color.A > 16 && (color.R < 245 || color.G < 245 || color.B < 245)) nonWhite++;
            colors.Add((color.R / 16 << 8) | (color.G / 16 << 4) | color.B / 16);
        }
    }
    var ratio = sampled == 0 ? 0 : nonWhite / (double)sampled;
    var passed = bitmap.Width >= 500 && bitmap.Height >= 400 && ratio >= 0.01 && colors.Count >= 8;
    return (passed, string.Format(
        System.Globalization.CultureInfo.InvariantCulture,
        "{0}x{1}, non-white {2:P1}, color groups {3}",
        bitmap.Width,
        bitmap.Height,
        ratio,
        colors.Count));
}

static async Task CreateInputPng(string path)
{
    var ppm = Path.ChangeExtension(path, ".ppm");
    await using (var stream = new FileStream(ppm, FileMode.Create, FileAccess.Write, FileShare.None, 1024 * 1024, true))
    {
        var width = 2200;
        var height = 1400;
        await stream.WriteAsync(Encoding.ASCII.GetBytes($"P6\n{width} {height}\n255\n"));
        var row = new byte[width * 3];
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var block = ((x / 40) + (y / 40)) % 2 == 0 ? 36 : 0;
                row[x * 3] = (byte)((x * 255 / width + block) % 256);
                row[x * 3 + 1] = (byte)((y * 255 / height + block * 2) % 256);
                row[x * 3 + 2] = (byte)(((x + y) * 120 / (width + height) + block * 3) % 256);
            }
            await stream.WriteAsync(row);
        }
    }
    var encoded = await new CompressionEngine().EncodeAsync(ppm, Presets.LosslessPng);
    await File.WriteAllBytesAsync(path, encoded.Data);
    File.Delete(ppm);
}

static async Task<string> Hash(string path)
{
    await using var stream = File.OpenRead(path);
    return Convert.ToHexString(await SHA256.HashDataAsync(stream));
}

static (int Width, int Height) ReadDimensions(string path)
{
    using var stream = File.OpenRead(path);
    Span<byte> bytes = stackalloc byte[24];
    stream.ReadExactly(bytes);
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return ((int)System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(bytes[16..20]), (int)System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(bytes[20..24]));
    stream.Position = 0;
    using var image = System.Drawing.Image.FromStream(stream);
    return (image.Width, image.Height);
}

[DllImport("user32.dll")]
static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);

[DllImport("user32.dll")]
static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

[DllImport("user32.dll")]
static extern bool PrintWindow(IntPtr hwnd, IntPtr deviceContext, uint flags);

record struct RECT(int Left, int Top, int Right, int Bottom);
sealed record UiCheck(string Name, bool Passed, string? Detail);
sealed record UiTestResult(string OperatingSystem, DateTimeOffset CompletedAt, IReadOnlyList<UiCheck> Checks);
