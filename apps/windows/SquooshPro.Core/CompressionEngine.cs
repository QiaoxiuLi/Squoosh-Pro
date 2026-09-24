using ImageMagick;

namespace SquooshPro.Core;

public sealed class CompressionEngine
{
    public Task<byte[]> CreateDisplayPngAsync(string sourcePath, int maximumEdge = 1800, CancellationToken cancellationToken = default) =>
        Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            using var image = new MagickImage(sourcePath);
            image.AutoOrient();
            if (Math.Max(image.Width, image.Height) > maximumEdge)
                image.Resize(new MagickGeometry((uint)maximumEdge, (uint)maximumEdge) { IgnoreAspectRatio = false });
            image.ColorSpace = ColorSpace.sRGB;
            image.Format = MagickFormat.Png;
            using var stream = new MemoryStream();
            image.Write(stream, MagickFormat.Png);
            return stream.ToArray();
        }, cancellationToken);

    public Task<EncodedImageResult> EncodeAsync(string sourcePath, CompressionPreset preset, CancellationToken cancellationToken = default) =>
        Task.Run(() => Encode(sourcePath, preset.DeepClone(), cancellationToken), cancellationToken);

    public async Task<string> EncodeAndCommitAsync(
        string sourcePath,
        string outputDirectory,
        CompressionPreset preset,
        EncodedImageResult? cachedResult = null,
        CancellationToken cancellationToken = default)
    {
        Presets.Validate(preset);
        var before = await SourceFingerprint.CaptureAsync(sourcePath, cancellationToken);
        var result = cachedResult ?? await EncodeAsync(sourcePath, preset, cancellationToken);
        cancellationToken.ThrowIfCancellationRequested();
        var after = await SourceFingerprint.CaptureAsync(sourcePath, cancellationToken);
        if (before != after) throw new SquooshException("sourceChanged", "原图在处理过程中发生了变化");

        Directory.CreateDirectory(outputDirectory);
        var extension = ExtensionFor(result.Format);
        var destination = SafePaths.UniqueOutputPath(outputDirectory, sourcePath, preset.Naming.Suffix, extension);
        var temporary = Path.Combine(outputDirectory, $".{Path.GetFileName(destination)}.sqbtmp-{Guid.NewGuid():N}");
        try
        {
            await File.WriteAllBytesAsync(temporary, result.Data, cancellationToken);
            VerifyEncodedFile(temporary, result.Format, result.Width, result.Height, preset.Output.Strategy == CompressionStrategy.targetBytes ? preset.Output.TargetBytes : null);
            if (Path.GetFullPath(destination).Equals(Path.GetFullPath(sourcePath), StringComparison.OrdinalIgnoreCase))
                throw new SquooshException("unsafePath", "输出路径不能与原图相同");
            File.Move(temporary, destination, false);
            return destination;
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    public static string CreateTimestampedDirectory(string parent, DateTimeOffset? now = null)
    {
        Directory.CreateDirectory(parent);
        var stamp = (now ?? DateTimeOffset.Now).ToString("yyyyMMdd_HHmmss");
        var basePath = Path.Combine(parent, $"result_{stamp}");
        for (var index = 0; index < 10_000; index++)
        {
            var candidate = index == 0 ? basePath : $"{basePath}_{index}";
            if (Directory.Exists(candidate)) continue;
            Directory.CreateDirectory(candidate);
            return candidate;
        }
        throw new IOException("无法创建新的结果文件夹");
    }

    public static void VerifyEncodedFile(string path, CodecFormat format, int expectedWidth, int expectedHeight, int? targetBytes)
    {
        var info = new FileInfo(path);
        if (!info.Exists || info.Length == 0) throw new SquooshException("verifyFailed", "输出文件为空");
        if (targetBytes is > 0 && info.Length > targetBytes) throw new SquooshException("targetNotMet", "输出文件超过目标大小");
        using var decoded = new MagickImage(path);
        if (decoded.Width != expectedWidth || decoded.Height != expectedHeight) throw new SquooshException("verifyFailed", "输出尺寸验证失败");
        var actual = FromMagickFormat(decoded.Format);
        if (actual != format) throw new SquooshException("verifyFailed", "输出格式验证失败");
    }

    private static EncodedImageResult Encode(string sourcePath, CompressionPreset preset, CancellationToken cancellationToken)
    {
        Presets.Validate(preset);
        if (!File.Exists(sourcePath)) throw new FileNotFoundException("找不到图片", sourcePath);
        cancellationToken.ThrowIfCancellationRequested();

        try
        {
            using var source = new MagickImage(sourcePath);
            if (source.Width == 0 || source.Height == 0) throw new SquooshException("decodeFailed", "无法读取图片尺寸");
            if (preset.Metadata.ApplyOrientationToPixels) source.AutoOrient();

            var format = preset.Output.Format == CodecFormat.automatic
                ? (source.HasAlpha && !source.IsOpaque ? CodecFormat.oxipng : CodecFormat.mozjpeg)
                : preset.Output.Format;

            if (format == CodecFormat.mozjpeg && preset.Output.Strategy == CompressionStrategy.targetBytes)
                return EncodeTargetJpeg(source, preset, cancellationToken);

            using var transformed = Transform(source, preset.Resize, null, format, preset, cancellationToken);
            var data = Write(transformed, format, preset.Output.Quality, preset, cancellationToken);
            var preview = BuildPreview(data, cancellationToken);
            return new EncodedImageResult(data, preview, format, (int)transformed.Width, (int)transformed.Height, preset.Output.Quality);
        }
        catch (OperationCanceledException) { throw; }
        catch (SquooshException) { throw; }
        catch (MagickException error) { throw new SquooshException("encodeFailed", $"无法处理这张图片：{error.Message}"); }
    }

    private static EncodedImageResult EncodeTargetJpeg(MagickImage source, CompressionPreset preset, CancellationToken cancellationToken)
    {
        var widths = preset.Resize.CandidateWidths.Count > 0
            ? preset.Resize.CandidateWidths.Distinct().OrderDescending().Select<int, int?>(value => value).ToList()
            : new List<int?> { preset.Resize.Width };
        if (widths.Count == 0 || widths.All(value => value is null)) widths = [null];
        var target = preset.Output.TargetBytes ?? throw new SquooshException("invalidPreset", "缺少目标大小");
        var safety = Math.Min(preset.Output.SafetyTargetBytes ?? target, target);

        foreach (var width in widths)
        {
            cancellationToken.ThrowIfCancellationRequested();
            using var transformed = Transform(source, preset.Resize, width, CodecFormat.mozjpeg, preset, cancellationToken);
            var measured = new Dictionary<int, byte[]>();
            (byte[] Data, int Quality)? best = null;
            var attempts = 0;

            byte[] Measure(int quality)
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (measured.TryGetValue(quality, out var existing)) return existing;
                if (attempts >= preset.Output.MaximumSearchAttempts) throw new SquooshException("targetNotMet", "已达到质量搜索次数");
                attempts++;
                var bytes = Write(transformed, CodecFormat.mozjpeg, quality, preset, cancellationToken);
                measured[quality] = bytes;
                if (bytes.Length <= safety && (best is null || quality > best.Value.Quality)) best = (bytes, quality);
                return bytes;
            }

            var initial = Measure(preset.Output.Quality);
            var low = preset.Output.MinimumQuality;
            var high = initial.Length > safety ? preset.Output.Quality - 1 : 100;
            while (low <= high && attempts < preset.Output.MaximumSearchAttempts)
            {
                var quality = (low + high) / 2;
                var bytes = Measure(quality);
                if (bytes.Length <= safety) low = quality + 1; else high = quality - 1;
            }
            if (best is null && attempts < preset.Output.MaximumSearchAttempts) _ = Measure(preset.Output.MinimumQuality);
            if (best is not null && best.Value.Data.Length <= target)
            {
                var preview = BuildPreview(best.Value.Data, cancellationToken);
                return new EncodedImageResult(best.Value.Data, preview, CodecFormat.mozjpeg, (int)transformed.Width, (int)transformed.Height, best.Value.Quality);
            }
        }
        throw new SquooshException("targetNotMet", "在当前最低质量和尺寸下无法达到目标大小");
    }

    private static MagickImage Transform(MagickImage source, ResizeOptions options, int? overrideWidth, CodecFormat format, CompressionPreset preset, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var image = (MagickImage)source.Clone();
        var (width, height) = CalculateSize((int)image.Width, (int)image.Height, options, overrideWidth);
        if (width != image.Width || height != image.Height)
        {
            image.FilterType = FilterType.Lanczos;
            image.Resize((uint)width, (uint)height);
        }
        image.ColorSpace = ColorSpace.sRGB;
        ApplyMetadataPolicy(image, preset.Metadata.Policy);
        if (format == CodecFormat.mozjpeg)
        {
            image.BackgroundColor = new MagickColor(preset.Alpha.JpegBackground);
            image.Alpha(AlphaOption.Remove);
        }
        return image;
    }

    public static (int Width, int Height) CalculateSize(int sourceWidth, int sourceHeight, ResizeOptions options, int? overrideWidth = null)
    {
        var targetWidth = sourceWidth;
        var targetHeight = sourceHeight;
        var ratio = sourceWidth / (double)sourceHeight;
        if (overrideWidth is > 0)
        {
            targetWidth = overrideWidth.Value;
            targetHeight = Math.Max(1, (int)Math.Round(targetWidth / ratio));
        }
        else switch (options.Mode)
        {
            case ResizeMode.fixedWidth when options.Width is > 0:
                targetWidth = options.Width.Value;
                targetHeight = Math.Max(1, (int)Math.Round(targetWidth / ratio));
                break;
            case ResizeMode.fixedHeight when options.Height is > 0:
                targetHeight = options.Height.Value;
                targetWidth = Math.Max(1, (int)Math.Round(targetHeight * ratio));
                break;
            case ResizeMode.longestEdge when options.LongestEdge is > 0:
                var edgeScale = options.LongestEdge.Value / (double)Math.Max(sourceWidth, sourceHeight);
                targetWidth = Math.Max(1, (int)Math.Round(sourceWidth * edgeScale));
                targetHeight = Math.Max(1, (int)Math.Round(sourceHeight * edgeScale));
                break;
            case ResizeMode.fitBox when options.Width is > 0 && options.Height is > 0:
                var boxScale = Math.Min(options.Width.Value / (double)sourceWidth, options.Height.Value / (double)sourceHeight);
                targetWidth = Math.Max(1, (int)Math.Round(sourceWidth * boxScale));
                targetHeight = Math.Max(1, (int)Math.Round(sourceHeight * boxScale));
                break;
        }
        if (!options.AllowUpscale && (targetWidth > sourceWidth || targetHeight > sourceHeight)) return (sourceWidth, sourceHeight);
        return (Math.Max(1, targetWidth), Math.Max(1, targetHeight));
    }

    private static byte[] Write(MagickImage image, CodecFormat format, int quality, CompressionPreset preset, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        using var output = new MemoryStream();
        image.Quality = (uint)Math.Clamp(quality, 0, 100);
        var magickFormat = ToMagickFormat(format);
        image.Format = magickFormat;
        switch (format)
        {
            case CodecFormat.mozjpeg:
                var progressive = preset.FormatOptions.GetValueOrDefault("progressive", 1) != 0;
                var baseline = preset.FormatOptions.GetValueOrDefault("baseline", 0) != 0;
                image.Settings.Interlace = progressive && !baseline ? Interlace.Jpeg : Interlace.NoInterlace;
                image.Settings.SetDefine(MagickFormat.Jpeg, "optimize-coding", preset.FormatOptions.GetValueOrDefault("optimizeCoding", 1) != 0);
                break;
            case CodecFormat.oxipng:
                image.Settings.SetDefine(MagickFormat.Png, "compression-level", Math.Clamp((int)preset.FormatOptions.GetValueOrDefault("level", 2), 0, 9));
                break;
            case CodecFormat.webp:
                image.Settings.SetDefine(MagickFormat.WebP, "method", Math.Clamp((int)preset.FormatOptions.GetValueOrDefault("method", 4), 0, 6));
                image.Settings.SetDefine(MagickFormat.WebP, "lossless", preset.FormatOptions.GetValueOrDefault("lossless", 0) != 0);
                image.Settings.SetDefine(MagickFormat.WebP, "use-sharp-yuv", preset.FormatOptions.GetValueOrDefault("sharpYUV", 0) != 0);
                break;
            case CodecFormat.avif:
                image.Settings.SetDefine(MagickFormat.Avif, "speed", Math.Clamp((int)preset.FormatOptions.GetValueOrDefault("speed", 6), 0, 10));
                break;
        }
        image.Write(output, magickFormat);
        return output.ToArray();
    }

    private static byte[] BuildPreview(byte[] encoded, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        using var image = new MagickImage(encoded);
        if (Math.Max(image.Width, image.Height) > 1800) image.Resize(new MagickGeometry(1800, 1800) { IgnoreAspectRatio = false });
        image.Format = MagickFormat.Png;
        using var stream = new MemoryStream();
        image.Write(stream, MagickFormat.Png);
        return stream.ToArray();
    }

    private static void ApplyMetadataPolicy(MagickImage image, MetadataPolicy policy)
    {
        if (policy is MetadataPolicy.stripAll or MetadataPolicy.stripPrivate)
        {
            image.Strip();
            return;
        }
        if (policy == MetadataPolicy.preserveSafe)
        {
            image.RemoveProfile("exif");
            image.RemoveProfile("xmp");
            image.RemoveProfile("iptc");
        }
    }

    private static MagickFormat ToMagickFormat(CodecFormat format) => format switch
    {
        CodecFormat.mozjpeg => MagickFormat.Jpeg,
        CodecFormat.oxipng => MagickFormat.Png,
        CodecFormat.webp => MagickFormat.WebP,
        CodecFormat.avif => MagickFormat.Avif,
        _ => MagickFormat.Jpeg
    };

    private static CodecFormat FromMagickFormat(MagickFormat format) => format switch
    {
        MagickFormat.Jpeg or MagickFormat.Jpg => CodecFormat.mozjpeg,
        MagickFormat.Png => CodecFormat.oxipng,
        MagickFormat.WebP => CodecFormat.webp,
        MagickFormat.Avif or MagickFormat.Heic => CodecFormat.avif,
        _ => throw new SquooshException("verifyFailed", $"无法识别输出格式：{format}")
    };

    public static string ExtensionFor(CodecFormat format) => format switch
    {
        CodecFormat.oxipng => "png",
        CodecFormat.webp => "webp",
        CodecFormat.avif => "avif",
        _ => "jpg"
    };
}

public static class SafePaths
{
    public static string UniqueOutputPath(string directory, string sourcePath, string suffix, string extension)
    {
        var stem = Sanitize(Path.GetFileNameWithoutExtension(sourcePath));
        var safeSuffix = string.IsNullOrWhiteSpace(suffix) ? "" : Sanitize(suffix);
        var baseName = string.IsNullOrWhiteSpace(safeSuffix) ? stem : $"{stem}{safeSuffix}";
        for (var index = 0; index < 10_000; index++)
        {
            var name = index == 0 ? $"{baseName}.{extension}" : $"{baseName}_{index}.{extension}";
            var candidate = Path.Combine(directory, name);
            if (!File.Exists(candidate) && !Directory.Exists(candidate)) return candidate;
        }
        throw new IOException("无法生成不重复的输出文件名");
    }

    private static string Sanitize(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var result = new string(value.Where(ch => !invalid.Contains(ch) && !char.IsControl(ch)).ToArray()).Trim().TrimEnd('.');
        return string.IsNullOrWhiteSpace(result) ? "image" : result[..Math.Min(result.Length, 100)];
    }
}
