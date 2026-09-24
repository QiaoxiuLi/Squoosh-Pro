using Microsoft.UI.Xaml.Media.Imaging;
using SquooshPro.Core;

namespace SquooshPro.Windows;

internal sealed class WorkspaceItem
{
    public WorkspaceItem(string path)
    {
        Path = path;
        InputBytes = new FileInfo(path).Length;
    }

    public Guid Id { get; } = Guid.NewGuid();
    public string Path { get; }
    public string FileName => System.IO.Path.GetFileName(Path);
    public long InputBytes { get; }
    public FileState State { get; set; } = FileState.queued;
    public long? OutputBytes { get; set; }
    public string? OutputPath { get; set; }
    public string? ErrorMessage { get; set; }
    public bool IsCached { get; set; }
    public BitmapImage? Thumbnail { get; set; }

    public string StatusText => State switch
    {
        FileState.queued => IsCached ? "已缓存" : "等待压缩",
        FileState.reading => "正在读取",
        FileState.decoding => "正在解码",
        FileState.transforming => "正在调整尺寸",
        FileState.encoding => "正在压缩",
        FileState.verifying => "正在验证",
        FileState.committing => "正在保存",
        FileState.completed => OutputBytes is null ? "已完成" : $"已完成 · {FormatBytes(OutputBytes.Value)}",
        FileState.failed => ErrorMessage ?? "失败",
        FileState.cancelled => "已取消",
        _ => State.ToString()
    };

    private static string FormatBytes(long value) => value >= 1_000_000 ? $"{value / 1_000_000d:0.0} MB" : $"{value / 1000d:0.#} KB";
}
