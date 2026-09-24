using System.Security.Cryptography;
using System.Text;
using SquooshPro.Core;

var root = Path.Combine(Path.GetTempPath(), $"SquooshProWindowsChecks-{Guid.NewGuid():N}");
Directory.CreateDirectory(root);
var failures = new List<string>();

async Task Check(string name, Func<Task> body)
{
    try
    {
        await body();
        Console.WriteLine($"PASS {name}");
    }
    catch (Exception error)
    {
        failures.Add($"{name}: {error}");
        Console.Error.WriteLine($"FAIL {name}: {error.Message}");
    }
}

void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

try
{
    var fixture = Path.Combine(root, "fixture.ppm");
    await WritePatternPpm(fixture, 2400, 1600);

    await Check("built-in preset validation", () =>
    {
        foreach (var preset in Presets.BuiltIns) Presets.Validate(preset);
        return Task.CompletedTask;
    });

    await Check("aspect-ratio resize and no upscale", () =>
    {
        var size = CompressionEngine.CalculateSize(2400, 1600, new ResizeOptions { Mode = ResizeMode.fixedWidth, Width = 1000 });
        Require(size == (1000, 667), $"unexpected size {size}");
        var small = CompressionEngine.CalculateSize(500, 300, new ResizeOptions { Mode = ResizeMode.fixedWidth, Width = 1000, AllowUpscale = false });
        Require(small == (500, 300), "small image was enlarged");
        var fit = CompressionEngine.CalculateSize(2400, 1600, new ResizeOptions { Mode = ResizeMode.fitBox, Width = 900, Height = 900 });
        Require(fit == (900, 600), $"fit box cropped or distorted: {fit}");
        return Task.CompletedTask;
    });

    var engine = new CompressionEngine();
    await Check("strict decimal 150KB JPEG", async () =>
    {
        var result = await engine.EncodeAsync(fixture, Presets.WebJpeg150Kb);
        Require(result.Data.Length <= 150_000, $"output was {result.Data.Length} bytes");
        Require(result.Width is >= 920 and <= 1000, $"unexpected adaptive width {result.Width}");
        Require(result.Quality >= 35, $"quality fell below minimum: {result.Quality}");
    });

    foreach (var (name, preset, signature) in new[]
    {
        ("JPEG", Presets.WebsiteJpeg, new byte[] { 0xFF, 0xD8 }),
        ("PNG", Presets.LosslessPng, new byte[] { 0x89, 0x50, 0x4E, 0x47 }),
        ("WebP", Presets.ModernWebP, Encoding.ASCII.GetBytes("RIFF")),
        ("AVIF", Presets.CompactAvif, Array.Empty<byte>())
    })
    {
        await Check($"{name} encode, decode, dimensions, and signature", async () =>
        {
            var local = preset.DeepClone();
            local.Resize = new ResizeOptions { Mode = ResizeMode.fixedWidth, Width = 640, AllowUpscale = false };
            var result = await engine.EncodeAsync(fixture, local);
            Require(result.Width == 640 && result.Height == 427, $"unexpected dimensions {result.Width}x{result.Height}");
            Require(result.Data.Length > 32 && result.PreviewPng.Length > 32, "empty output or preview");
            if (signature.Length > 0) Require(result.Data.AsSpan(0, signature.Length).SequenceEqual(signature), "signature mismatch");
            if (name == "WebP") Require(Encoding.ASCII.GetString(result.Data, 8, 4) == "WEBP", "WebP container marker missing");
            if (name == "AVIF") Require(Encoding.ASCII.GetString(result.Data, 4, Math.Min(24, result.Data.Length - 4)).Contains("ftyp"), "AVIF file type marker missing");
        });
    }

    await Check("atomic commit, source protection, and conflict rename", async () =>
    {
        var sourceBefore = Convert.ToHexString(await SHA256.HashDataAsync(File.OpenRead(fixture)));
        var output = CompressionEngine.CreateTimestampedDirectory(root, DateTimeOffset.Parse("2026-09-23T21:00:00-07:00"));
        var first = await engine.EncodeAndCommitAsync(fixture, output, Presets.WebsiteJpeg);
        var second = await engine.EncodeAndCommitAsync(fixture, output, Presets.WebsiteJpeg);
        Require(File.Exists(first) && File.Exists(second) && first != second, "conflict-safe output failed");
        Require(!Directory.EnumerateFiles(output).Any(path => Path.GetFileName(path).Contains(".sqbtmp-")), "temporary output remained");
        var sourceAfter = Convert.ToHexString(await SHA256.HashDataAsync(File.OpenRead(fixture)));
        Require(sourceBefore == sourceAfter, "source image changed");
    });

    await Check("bounded preview cache", () =>
    {
        var cache = new PreviewCache(2, 1024);
        for (var index = 0; index < 3; index++)
            cache.Put(index.ToString(), new EncodedImageResult(new byte[200], new byte[200], CodecFormat.mozjpeg, 10, 10, 75));
        Require(!cache.Contains("0") && cache.Contains("1") && cache.Contains("2"), "oldest entry was not evicted");
        cache.Clear();
        Require(!cache.Contains("2"), "cache did not clear");
        return Task.CompletedTask;
    });
}
finally
{
    try { Directory.Delete(root, true); } catch { }
}

if (failures.Count > 0)
{
    Console.Error.WriteLine($"{failures.Count} Windows core check(s) failed.");
    return 1;
}

Console.WriteLine("All Windows core checks passed");
return 0;

static async Task WritePatternPpm(string path, int width, int height)
{
    await using var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1024 * 1024, true);
    var header = Encoding.ASCII.GetBytes($"P6\n{width} {height}\n255\n");
    await stream.WriteAsync(header);
    var row = new byte[width * 3];
    for (var y = 0; y < height; y++)
    {
        for (var x = 0; x < width; x++)
        {
            var block = ((x / 48) + (y / 48)) % 2 == 0 ? 32 : 0;
            row[x * 3] = (byte)((x * 255 / width + block) % 256);
            row[x * 3 + 1] = (byte)((y * 255 / height + block * 2) % 256);
            row[x * 3 + 2] = (byte)(((x + y) * 127 / (width + height) + block * 3) % 256);
        }
        await stream.WriteAsync(row);
    }
}
