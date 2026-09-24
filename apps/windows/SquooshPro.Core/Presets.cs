using System.Text.RegularExpressions;

namespace SquooshPro.Core;

public static partial class Presets
{
    public static CompressionPreset Smart => new()
    {
        Id = "system.smart", Name = "智能推荐", Kind = "system",
        Output = new() { Format = CodecFormat.automatic, Strategy = CompressionStrategy.fixedQuality, Quality = 78 },
        Resize = new() { Mode = ResizeMode.longestEdge, LongestEdge = 1920 }
    };

    public static CompressionPreset WebsiteJpeg => new()
    {
        Id = "system.website-jpeg", Name = "JPEG（JPG）", Kind = "system",
        Output = new() { Format = CodecFormat.mozjpeg, Strategy = CompressionStrategy.fixedQuality, Quality = 75 },
        Resize = new() { Mode = ResizeMode.longestEdge, LongestEdge = 1920 },
        FormatOptions = new() { ["progressive"] = 1, ["optimizeCoding"] = 1, ["baseline"] = 0 }
    };

    public static CompressionPreset WebJpeg150Kb => new()
    {
        Id = "system.web-jpeg-150kb", Name = "网页 JPEG ≤150KB", Kind = "system",
        Output = new()
        {
            Format = CodecFormat.mozjpeg, Strategy = CompressionStrategy.targetBytes, Quality = 75,
            TargetBytes = 150_000, SafetyTargetBytes = 145_000, MinimumQuality = 35, MaximumSearchAttempts = 8
        },
        Resize = new() { Mode = ResizeMode.adaptiveWidth, CandidateWidths = [1000, 960, 920], AllowUpscale = false },
        FormatOptions = new() { ["progressive"] = 1, ["optimizeCoding"] = 1, ["baseline"] = 0 }
    };

    public static CompressionPreset LosslessPng => new()
    {
        Id = "system.lossless-png", Name = "无损 PNG", Kind = "system",
        Output = new() { Format = CodecFormat.oxipng, Strategy = CompressionStrategy.fixedQuality, Quality = 100 },
        Resize = new() { Mode = ResizeMode.original },
        FormatOptions = new() { ["level"] = 2, ["interlace"] = 0 }
    };

    public static CompressionPreset ModernWebP => new()
    {
        Id = "system.modern-webp", Name = "现代网站 WebP", Kind = "system",
        Output = new() { Format = CodecFormat.webp, Strategy = CompressionStrategy.fixedQuality, Quality = 78 },
        Resize = new() { Mode = ResizeMode.original },
        FormatOptions = new() { ["method"] = 4, ["alphaQuality"] = 100 }
    };

    public static CompressionPreset CompactAvif => new()
    {
        Id = "system.compact-avif", Name = "极致压缩 AVIF", Kind = "system",
        Output = new() { Format = CodecFormat.avif, Strategy = CompressionStrategy.fixedQuality, Quality = 50 },
        Resize = new() { Mode = ResizeMode.original },
        FormatOptions = new() { ["speed"] = 6, ["alphaQuality"] = 50 }
    };

    public static IReadOnlyList<CompressionPreset> BuiltIns => [Smart, WebsiteJpeg, WebJpeg150Kb, LosslessPng, ModernWebP, CompactAvif];

    public static void Validate(CompressionPreset preset)
    {
        if (preset.SchemaVersion != 1) throw new SquooshException("invalidPreset", "不支持的预设版本");
        if (string.IsNullOrWhiteSpace(preset.Id) || string.IsNullOrWhiteSpace(preset.Name)) throw new SquooshException("invalidPreset", "预设名称不能为空");
        if (preset.Output.Quality is < 0 or > 100) throw new SquooshException("invalidPreset", "质量必须在 0 到 100 之间");
        if (preset.Output.MaximumSearchAttempts is < 1 or > 16) throw new SquooshException("invalidPreset", "质量搜索次数必须在 1 到 16 之间");
        if (preset.Output.Strategy == CompressionStrategy.targetBytes)
        {
            if (preset.Output.MinimumQuality is < 0 or > 100 || preset.Output.MinimumQuality > preset.Output.Quality)
                throw new SquooshException("invalidPreset", "最低质量不能高于初始质量");
            if (preset.Output.TargetBytes is null or <= 0) throw new SquooshException("invalidPreset", "请输入有效的目标大小");
            var safety = preset.Output.SafetyTargetBytes ?? preset.Output.TargetBytes;
            if (safety is null or <= 0 || safety > preset.Output.TargetBytes) throw new SquooshException("invalidPreset", "安全目标不能超过目标大小");
        }
        if (preset.Resize.CandidateWidths.Any(value => value is <= 0 or > 100_000)) throw new SquooshException("invalidPreset", "候选宽度超出安全范围");
        if (!HexColor().IsMatch(preset.Alpha.JpegBackground)) throw new SquooshException("invalidPreset", "JPEG 背景颜色格式无效");
    }

    [GeneratedRegex("^#[0-9A-Fa-f]{6}$")]
    private static partial Regex HexColor();
}
