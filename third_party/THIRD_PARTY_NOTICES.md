# Third-Party Notices

Squoosh Pro is an independent application. It is not an official product of Google, Microsoft, Apple, the Alliance for Open Media, or any other third-party project named below. No third-party name or trademark is used to imply endorsement.

This file lists third-party components used by the source tree or redistributed in Squoosh Pro release packages. Original Squoosh Pro code and documentation are covered by the repository's MIT License. Third-party components remain under their respective licenses.

## Bundled Squoosh codecs

The codec JavaScript, WebAssembly, and generated integration artifacts were copied without source modification from `GoogleChromeLabs/squoosh` commit `e8d35e0fb66eb16eff6fe8fc773eabcbb7128de3`. Source provenance is recorded in `UPSTREAM_COMMIT`.

- Squoosh integration and generated glue: Apache License 2.0, see `LICENSES/SQUOOSH-APACHE-2.0.txt`
- MozJPEG/libjpeg-turbo: IJG, BSD-style, and zlib-compatible terms, see `LICENSES/MOZJPEG.txt`
- OxiPNG: MIT License, see `LICENSES/OXIPNG.txt`
- WebP/libwebp: BSD-style license, see `LICENSES/WEBP.txt`
- libavif: BSD 2-Clause License, see `LICENSES/LIBAVIF.txt`
- libaom AV1 codec: BSD 3-Clause License, see `LICENSES/LIBAOM.txt`

These JavaScript/WebAssembly resources are bundled in the macOS application. The Windows application uses the native ImageMagick codecs supplied by Magick.NET rather than these JavaScript/WebAssembly binaries.

## Windows release components

The self-contained Windows x64 release additionally redistributes the following components:

- Magick.NET-Q8-x64 and Magick.NET.Core 14.17.1, copyright Dirk Lemstra and contributors: Apache License 2.0, see `LICENSES/MAGICK.NET-APACHE-2.0.txt`
- ImageMagick native components distributed by Magick.NET, copyright ImageMagick Studio LLC and contributors: ImageMagick License, see `LICENSES/IMAGEMAGICK.txt`
- Microsoft Windows App SDK 2.5.1 and its self-contained runtime files, copyright Microsoft Corporation: Microsoft Software License Terms. The unchanged upstream license and aggregate third-party notices are in `LICENSES/Windows-0.3.0/Microsoft.WindowsAppSDK-2.5.1-license.txt` and `LICENSES/Windows-0.3.0/Microsoft.WindowsAppSDK-2.5.1-NOTICE.txt`.
- The Windows App SDK modular packages resolved by this release are Base 2.0.4, Foundation 2.3.12, WinUI 2.3.9, DWrite 2.1.0, InteractiveExperiences 2.1.9, Runtime 2.5.1, Widgets 2.0.5, AI 2.5.5, Search 2.5.5, and ML 2.1.94. Their individual license texts and available NOTICE files are preserved under `LICENSES/Windows-0.3.0/` using their exact package names and versions.
- Microsoft Windows AI MachineLearning 2.1.74, including the ONNX Runtime and DirectML dependencies supplied by that package: Microsoft Windows ML Runtime terms and incorporated third-party licenses are in `LICENSES/Windows-0.3.0/Microsoft.Windows.AI.MachineLearning-2.1.74-license.txt` and `Microsoft.Windows.AI.MachineLearning-2.1.74-ThirdPartyNotices.txt` in the same directory. These files accompany the Windows App SDK runtime; Squoosh Pro does not run AI inference or require AI models for image compression.
- Microsoft WebView2 SDK 1.0.3719.77 loader and managed projection files, copyright Microsoft Corporation: BSD-style license and notices in `LICENSES/Windows-0.3.0/Microsoft.Web.WebView2-1.0.3719.77-LICENSE.txt` and the corresponding `NOTICE.txt`.
- Microsoft .NET Runtime 10.0.12 self-contained win-x64 runtime pack, copyright .NET Foundation and contributors: MIT License and third-party notices in `LICENSES/Windows-0.3.0/dotnet-10.0.12-LICENSE.TXT` and `dotnet-10.0.12-THIRD-PARTY-NOTICES.TXT` in that directory.
- System.Numerics.Tensors 9.0.0, copyright .NET Foundation and contributors: MIT License and incorporated notices in `LICENSES/Windows-0.3.0/System.Numerics.Tensors-9.0.0-LICENSE.TXT` and the corresponding `THIRD-PARTY-NOTICES.TXT`.
- Microsoft Windows SDK BuildTools 10.0.26100.4654 and BuildTools.MSIX 1.7.251221100 are build-time packages. Windows SDK .NET interop projection files come from the .NET 10 Windows targeting pack. Windows SDK terms are in `LICENSES/WINDOWS_SDK_LICENSE.rtf`; MSIX tool notices are also preserved under `LICENSES/Windows-0.3.0/`.

The complete 426,524-byte Magick.NET upstream notice is preserved as `LICENSES/Windows-0.3.0/Magick.NET-Q8-x64-14.17.1-Notice.txt`. It contains the ImageMagick 7.1.2-31 license and the exact versions, copyrights, and licenses for native dependencies such as libjpeg-turbo, libpng, libwebp, libheif, libaom, and their supporting libraries. The per-component notice, not only the top-level Magick.NET license, is redistributed in the Windows download.

The installed Evergreen WebView2 Runtime is supplied and serviced by Microsoft as part of Windows or through Microsoft's WebView2 Runtime distribution. Squoosh Pro redistributes the WebView2 SDK loader/projection files listed above, not a fixed Microsoft Edge browser runtime.

## Apple system frameworks

The macOS application links against Apple-provided SwiftUI, AppKit, WebKit, Core Image, ImageIO, Metal, Uniform Type Identifiers, and related system frameworks. These are operating-system components governed by Apple's platform terms and are not copied into the repository as independently licensed third-party packages.

## Development-only tooling

Swift Package Manager, Xcode, the .NET SDK, MSBuild, the Windows SDK build tools, Node.js, and test automation supplied by the operating system or SDK are used to build or verify the project. They are not bundled as separate applications or browser plug-ins. The codec worker package declares no external npm dependencies, and the Swift package declares no external Swift package dependencies.

## Trademarks

Google, Chrome, Microsoft, Windows, Apple, macOS, and other names may be trademarks of their respective owners. Their appearance identifies compatibility or upstream components only.
