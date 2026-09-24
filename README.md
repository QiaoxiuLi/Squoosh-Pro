# Squoosh Pro

Squoosh Pro 是一款面向 macOS、Windows 10 和 Windows 11 的本地批量图片压缩工具。它可以在不上传图片、不覆盖原图的前提下，预览压缩效果并批量导出 JPEG（JPG）、PNG、WebP 或 AVIF。

[下载最新版本](https://github.com/QiaoxiuLi/Squoosh-Pro/releases/latest) · [Windows 使用说明](docs/USER_GUIDE_WINDOWS_ZH.md) · [macOS 使用说明](docs/USER_GUIDE_ZH.md)

## 主要功能

- 一次添加多张图片或整个文件夹，也可以直接拖入窗口。
- 在图片列表中搜索文件名，点击任意图片查看压缩效果。
- 使用滑杆对比原图与输出图，预览完成的结果会暂时缓存，正式导出时可直接复用。
- 按质量压缩，或为每张图片设置明确的 KB 上限。
- 按最长边、固定宽度、固定高度或指定范围等比例缩放，不会擅自裁切图片。
- 保存带名称和备注的个人预设，并可导入或导出自己的预设。
- 批量任务支持暂停、继续、取消和失败项重试。
- 每次导出自动建立带时间戳的结果文件夹，同名文件不会覆盖。
- 默认开启硬件加速预览；如果设备不适合，应用会自动回退到兼容模式。

## 支持的格式

| 格式 | 适合场景 | 说明 |
| --- | --- | --- |
| JPEG（JPG） | 照片、商品图、网站图片 | 兼容主流浏览器、Android、iPhone 和常见办公软件；不支持透明背景 |
| PNG | 截图、图标、文字图片、透明背景 | 无损保存，文件通常比 JPEG 大 |
| WebP | 现代网站和支持 WebP 的应用 | 通常比 JPEG 或 PNG 更小，可保留透明背景 |
| AVIF | 对文件大小要求更高的现代网站 | 压缩率高，但处理速度较慢，旧软件兼容性不如 JPEG |

## 下载与运行

### Windows 10 / 11

1. 从 [Releases](https://github.com/QiaoxiuLi/Squoosh-Pro/releases/latest) 下载 `Squoosh-Pro-0.2.0-Windows-x64.zip` 和同名 `.sha256` 文件。
2. 右键 ZIP 并选择“全部解压”。请保留解压后的完整文件夹，不能只复制 `SquooshPro.exe`。
3. 双击 `SquooshPro.exe` 启动。

Windows 版本支持 64 位 Windows 10 和 Windows 11。发布包已经包含所需运行组件，无需另行安装 .NET 或 Windows App SDK。

当前 `0.2.0` 下载包尚未进行商业 Authenticode 代码签名，因此 Windows Defender SmartScreen 可能在首次启动时显示提醒。请只从本仓库的 Release 页面下载并核对 SHA-256；不要为运行本软件而关闭 Windows 安全中心。

### macOS

macOS 版本支持 macOS 13 或更高版本，并同时支持 Apple 芯片和 Intel Mac。当前公开的 macOS `0.1.0 Beta 1` 为未公证测试版，可在 [历史版本](https://github.com/QiaoxiuLi/Squoosh-Pro/releases/tag/v0.1.0-beta.1) 下载。

## 快速开始

1. 点击“添加图片”或“添加文件夹”，也可以把图片拖入窗口。
2. 选择一个预设；普通照片可直接选择“JPEG（JPG）”。
3. 点击图片查看预览，用对比滑杆检查清晰度。
4. 如有需要，在“压缩设置”中调整质量、KB 上限和图片尺寸。
5. 点击“开始压缩”。
6. 完成后点击“打开输出目录”。

## 每张图片不超过 150 KB

需要网站图片每张不超过 150 KB 时，选择内置的“网页 JPEG ≤150KB”预设：

- `1 KB` 按 `1000` 字节计算，最终文件不会超过 `150000` 字节。
- 应用会在 `1000`、`960` 和 `920` 像素宽度中自动选择，并寻找满足上限的尽量高清结果。
- 原图较小时不会被放大。
- 如果允许的尺寸和最低质量仍无法满足限制，该图片会明确显示失败，不会把超限文件标记为成功。

这类 JPEG 可在主流桌面浏览器、Android 浏览器和 iPhone Safari 中正常使用。

## 隐私与文件安全

- 图片只在你的电脑上处理，不需要账号，也不会上传到服务器。
- 原图以只读方式使用，不会被覆盖或删除。
- 输出文件会先经过格式、尺寸、可解码性和大小检查，再保存为最终结果。
- 已存在同名文件时会自动使用新文件名。
- 预览缓存有容量上限，并会在任务完成、清空列表或退出应用时清理。
- 设置、个人预设和历史记录保存在本机。

## 第三方组件与致谢

Squoosh Pro 是独立项目，不是 Google、Microsoft 或 Apple 的官方产品，也不代表这些公司对本软件的认可。

本项目使用并感谢以下软件与平台组件：

- [GoogleChromeLabs/squoosh](https://github.com/GoogleChromeLabs/squoosh) 的本地编解码资源，以及 MozJPEG/libjpeg-turbo、OxiPNG、libwebp、libavif 和 libaom。
- Windows 版本使用 Magick.NET 14.17.1、ImageMagick、Microsoft Windows App SDK 1.6.250602001、Microsoft WebView2 SDK 1.0.2651.64、.NET Runtime 8.0.31 和 Microsoft Windows SDK 运行组件。
- macOS 版本使用 SwiftUI、AppKit、WebKit、Core Image、ImageIO 和 Metal 等 macOS 系统框架。

各组件的版权、版本、来源和完整许可文本见 [第三方公告](third_party/THIRD_PARTY_NOTICES.md)。Windows 下载包内也包含 `THIRD_PARTY_NOTICES.md` 和 `LICENSES` 文件夹，便于离线查阅。

## 许可

Squoosh Pro 的原创代码和文档采用 [MIT License](LICENSE)。第三方组件继续适用各自的许可证和版权声明。

## 获取帮助

如果遇到问题，请在 [GitHub Issues](https://github.com/QiaoxiuLi/Squoosh-Pro/issues) 中说明系统版本、输入图片格式、使用的预设、实际结果和错误提示。除非图片可以公开，否则不要上传私人原图。
