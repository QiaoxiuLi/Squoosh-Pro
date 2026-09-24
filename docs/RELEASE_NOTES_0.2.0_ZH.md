# Squoosh Pro 0.2.0 发布说明

Squoosh Pro 0.2.0 是面向 64 位 Windows 10 和 Windows 11 的正式 GitHub Release。应用在本机处理图片，不需要账号，不会上传图片，也不会覆盖原图。

## 主要功能

- 支持 JPEG（JPG）、PNG、WebP 和 AVIF 本地压缩。
- 支持添加多张图片、添加文件夹和拖放导入。
- 支持按文件名搜索图片，点击图片即可预览。
- 提供原图与输出图对比滑杆、适合窗口和 100% 查看方式。
- 预览结果会在限制范围内缓存，正式导出时可直接复用。
- 支持按质量压缩，或限制每张图片的 KB 大小。
- 内置“网页 JPEG ≤150KB”预设，每张图片严格不超过 150000 字节，并自动在 1000、960、920 像素宽度中选择。
- 支持保存带名称和备注的个人预设，以及导入、导出个人预设。
- 支持暂停、继续、取消、失败项重试和本地历史记录。
- 默认使用硬件加速预览，不适合的设备会自动回退。
- 每次任务建立带时间戳的输出目录，同名文件不会覆盖。

## 下载与启动

1. 下载 `Squoosh-Pro-0.2.0-Windows-x64.zip` 和同名 `.sha256` 文件。
2. 核对 SHA-256 后，对 ZIP 执行“全部解压”。
3. 保留完整文件夹，双击其中的 `SquooshPro.exe`。

发布包已经包含 .NET、Windows App SDK 和图片处理组件，无需另行安装这些运行库。

## 签名提示

当前 `0.2.0` 发布包尚未进行商业 Authenticode 代码签名，Windows Defender SmartScreen 可能在首次运行时显示提醒。请只从本项目的 GitHub Release 页面下载并核对 SHA-256，不要从第三方下载站获取，也不要关闭 Windows 安全中心。

## 系统范围

- 支持 64 位 Windows 10 和 Windows 11。
- 不支持 Windows 7、32 位 Windows 或 Windows ARM64 原生版本。
- macOS 版本仍单独提供 `0.1.0 Beta 1`，不包含在本次 Windows 下载包中。

## 第三方组件

发布包内的 `THIRD_PARTY_NOTICES.md` 和 `LICENSES` 文件夹列出了所有随包第三方组件、版本、版权声明和完整许可文本，包括 Squoosh 编码器、Magick.NET、ImageMagick、Windows App SDK、WebView2 SDK、.NET Runtime 和 Windows SDK 运行组件。
