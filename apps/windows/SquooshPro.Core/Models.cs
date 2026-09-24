using System.Text.Json;
using System.Text.Json.Serialization;

namespace SquooshPro.Core;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CodecFormat { automatic, mozjpeg, oxipng, webp, avif }

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CompressionStrategy { fixedQuality, targetBytes }

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum ResizeMode { original, longestEdge, fixedWidth, fixedHeight, fitBox, adaptiveWidth }

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MetadataPolicy { stripPrivate, stripAll, preserveSafe, preserveAll }

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum ConflictPolicy { rename, skip }

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum FileState { queued, reading, decoding, transforming, encoding, verifying, committing, completed, failed, cancelled }

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum JobState { draft, ready, running, pausing, paused, cancelling, cancelled, completed, completedWithErrors, failed }

public sealed record OutputOptions
{
    public CodecFormat Format { get; set; } = CodecFormat.mozjpeg;
    public CompressionStrategy Strategy { get; set; } = CompressionStrategy.fixedQuality;
    public int Quality { get; set; } = 75;
    public int? TargetBytes { get; set; }
    public int? SafetyTargetBytes { get; set; }
    public int MinimumQuality { get; set; } = 35;
    public int MaximumSearchAttempts { get; set; } = 8;
}

public sealed record ResizeOptions
{
    public ResizeMode Mode { get; set; } = ResizeMode.original;
    public int? Width { get; set; }
    public int? Height { get; set; }
    public int? LongestEdge { get; set; }
    public List<int> CandidateWidths { get; set; } = [];
    public bool AllowUpscale { get; set; }
    public bool PreserveAspectRatio { get; set; } = true;
}

public sealed record MetadataOptions
{
    public MetadataPolicy Policy { get; set; } = MetadataPolicy.stripPrivate;
    public bool PreserveOrientation { get; set; }
    public bool ApplyOrientationToPixels { get; set; } = true;
}

public sealed record ColorOptions
{
    public string OutputColorSpace { get; set; } = "sRGB";
}

public sealed record AlphaOptions
{
    public string JpegBackground { get; set; } = "#FFFFFF";
}

public sealed record NamingOptions
{
    public string Suffix { get; set; } = "";
    public ConflictPolicy ConflictPolicy { get; set; } = ConflictPolicy.rename;
}

public sealed record CompressionPreset
{
    public int SchemaVersion { get; set; } = 1;
    public string Id { get; set; } = Guid.NewGuid().ToString("D");
    public string Name { get; set; } = "未命名预设";
    public string? Notes { get; set; }
    public string Kind { get; set; } = "user";
    public OutputOptions Output { get; set; } = new();
    public ResizeOptions Resize { get; set; } = new();
    public MetadataOptions Metadata { get; set; } = new();
    public ColorOptions Color { get; set; } = new();
    public AlphaOptions Alpha { get; set; } = new();
    public NamingOptions Naming { get; set; } = new();
    public Dictionary<string, double> FormatOptions { get; set; } = [];

    public CompressionPreset DeepClone() => JsonSerializer.Deserialize<CompressionPreset>(JsonSerializer.Serialize(this, JsonOptions.Default), JsonOptions.Default)!;
}

public sealed record EncodedImageResult(byte[] Data, byte[] PreviewPng, CodecFormat Format, int Width, int Height, int Quality);

public sealed record SourceFingerprint(long Length, long LastWriteUtcTicks, string Sha256)
{
    public static async Task<SourceFingerprint> CaptureAsync(string path, CancellationToken cancellationToken = default)
    {
        var info = new FileInfo(path);
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1024 * 1024, true);
        var hash = await System.Security.Cryptography.SHA256.HashDataAsync(stream, cancellationToken);
        info.Refresh();
        return new SourceFingerprint(info.Length, info.LastWriteTimeUtc.Ticks, Convert.ToHexString(hash));
    }
}

public sealed record JobItemRecord
{
    public Guid ItemID { get; set; } = Guid.NewGuid();
    public string SourceFileName { get; set; } = "";
    public FileState State { get; set; } = FileState.queued;
    public long InputBytes { get; set; }
    public string? OutputFileName { get; set; }
    public long? OutputBytes { get; set; }
    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
}

public sealed record JobReport
{
    public int SchemaVersion { get; set; } = 1;
    public Guid JobID { get; set; } = Guid.NewGuid();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;
    public JobState State { get; set; } = JobState.ready;
    public string PresetID { get; set; } = "";
    public string OutputDirectoryName { get; set; } = "";
    public List<JobItemRecord> Items { get; set; } = [];
}

public static class JsonOptions
{
    public static readonly JsonSerializerOptions Default = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };
}

public sealed class SquooshException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
}
