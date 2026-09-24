using System.Text.Json;
using SquooshPro.Core;

namespace SquooshPro.Windows;

internal static class UserStorage
{
    public static string Root { get; } = Environment.GetEnvironmentVariable("SQUOOSH_PRO_DATA_ROOT")
        ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Squoosh Pro");
    public static string PresetsPath => Path.Combine(Root, "presets.json");
    public static string JobsPath => Path.Combine(Root, "Jobs");
    public static string SettingsPath => Path.Combine(Root, "settings.json");
    public static string StartupMarkerPath => Path.Combine(Root, "preview-startup.marker");

    public static List<CompressionPreset> LoadPresets() => Read(PresetsPath, new List<CompressionPreset>());
    public static void SavePresets(List<CompressionPreset> presets) => AtomicWrite(PresetsPath, presets);
    public static AppPreferences LoadPreferences() => Read(SettingsPath, new AppPreferences());
    public static void SavePreferences(AppPreferences settings) => AtomicWrite(SettingsPath, settings);

    public static void SaveJob(JobReport report)
    {
        Directory.CreateDirectory(JobsPath);
        AtomicWrite(Path.Combine(JobsPath, $"{report.JobID:D}.json"), report);
    }

    public static IReadOnlyList<JobReport> LoadJobs()
    {
        if (!Directory.Exists(JobsPath)) return [];
        return Directory.EnumerateFiles(JobsPath, "*.json")
            .Select(path => Read<JobReport?>(path, null))
            .Where(value => value is not null)
            .Cast<JobReport>()
            .OrderByDescending(value => value.CreatedAt)
            .ToList();
    }

    public static void AppendDiagnostic(string message)
    {
        try
        {
            Directory.CreateDirectory(Root);
            File.AppendAllText(Path.Combine(Root, "diagnostics.log"), $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}");
        }
        catch { }
    }

    private static T Read<T>(string path, T fallback)
    {
        try { return File.Exists(path) ? JsonSerializer.Deserialize<T>(File.ReadAllText(path), JsonOptions.Default) ?? fallback : fallback; }
        catch { return fallback; }
    }

    public static void AtomicWrite<T>(string path, T value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = $"{path}.tmp-{Guid.NewGuid():N}";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(value, JsonOptions.Default));
            File.Move(temporary, path, true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }
}

internal sealed record AppPreferences
{
    public bool RecursiveFolders { get; set; } = true;
    public bool HardwarePreview { get; set; } = true;
    public string? OutputParent { get; set; }
}
