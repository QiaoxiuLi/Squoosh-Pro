namespace SquooshPro.Core;

public sealed class PreviewCache(int maximumEntries = 24, long maximumBytes = 128L * 1024 * 1024)
{
    private sealed record Entry(EncodedImageResult Result, DateTimeOffset LastAccess);
    private readonly Dictionary<string, Entry> entries = [];
    private readonly object gate = new();

    public EncodedImageResult? Get(string key)
    {
        lock (gate)
        {
            if (!entries.TryGetValue(key, out var entry)) return null;
            entries[key] = entry with { LastAccess = DateTimeOffset.UtcNow };
            return entry.Result;
        }
    }

    public void Put(string key, EncodedImageResult result)
    {
        lock (gate)
        {
            entries[key] = new Entry(result, DateTimeOffset.UtcNow);
            while (entries.Count > maximumEntries || entries.Values.Sum(value => (long)value.Result.Data.Length + value.Result.PreviewPng.Length) > maximumBytes)
            {
                var oldest = entries.MinBy(pair => pair.Value.LastAccess).Key;
                entries.Remove(oldest);
            }
        }
    }

    public bool Contains(string key) { lock (gate) return entries.ContainsKey(key); }
    public void Clear() { lock (gate) entries.Clear(); }
}
