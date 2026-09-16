# Squoosh Pro 0.1.0 Beta 1

这是 Squoosh Pro 的首个 GitHub 公开测试版，面向需要在 Mac 本地批量压缩图片的用户。图片不会上传，原图不会被覆盖。

## 本版主要功能

- 原生 macOS 图形界面，支持 Apple 芯片和 Intel 芯片 Mac
- 批量添加图片、添加文件夹和 Finder 拖放
- JPEG（JPG）、PNG、WebP 和 AVIF 输出
- “网页 JPEG ≤150KB”预设，按真实文件字节逐张检查
- 图片列表搜索、点击预览、原图与输出对比
- 预览结果缓存，可在正式导出时直接复用
- Metal/Core Image 硬件加速预览，异常时自动切换兼容模式
- 可保存带备注的个人预设，并可批量导入、导出
- 带时间的结果文件夹、同名文件保护和原图保护
- 暂停、继续、取消、失败重试和任务历史

## 下载

下载 `Squoosh-Pro-0.1.0-macOS-universal.zip`，解压后将 `Squoosh Pro.app` 移到“应用程序”文件夹。

当前 Beta 安装包使用临时签名，尚未经过 Apple 公证。首次打开时，请在 Finder 中右键点击应用，选择“打开”，然后在系统提示中再次确认。不要关闭 macOS 的系统安全检查。

完整操作步骤和设置解释请阅读[普通用户使用说明](https://github.com/QiaoxiuLi/Squoosh-Pro/blob/v0.1.0-beta.1/docs/USER_GUIDE_ZH.md)。

## 兼容性说明

- 系统要求：macOS 13 或更高版本
- 安装包：Universal 2，包含 `arm64` 和 `x86_64`
- JPEG（JPG）：适合 Safari、Chrome、Edge、Firefox、Android 和 iPhone 等常见环境
- Intel 版本已完成构建检查，但尚未在真实 Intel Mac 上完成运行测试

## 文件校验

Release 附件中的 `.sha256` 文件可用于确认 ZIP 下载完整：

```bash
shasum -a 256 -c Squoosh-Pro-0.1.0-macOS-universal.zip.sha256
```

## 已知限制

- 尚未使用 Developer ID 签名和 Apple 公证，因此本版本以 prerelease 形式发布。
- AVIF 的处理时间可能明显长于 JPEG。
- 暂不支持动态图、裁切、滤镜、文件夹监控、Finder 扩展、云同步和自动更新。

遇到问题时，请通过 GitHub Issues 提供 macOS 版本、Mac 芯片类型、图片格式和可复现步骤。请勿上传不能公开的私人图片。
