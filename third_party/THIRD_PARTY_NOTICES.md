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

These resources are bundled in both the macOS and Windows applications where the corresponding codec path is used.

## Windows release components

The self-contained Windows x64 release additionally redistributes the following components:

- Magick.NET-Q8-x64 and Magick.NET.Core 14.17.1, copyright Dirk Lemstra and contributors: Apache License 2.0, see `LICENSES/MAGICK.NET-APACHE-2.0.txt`
- ImageMagick native components distributed by Magick.NET, copyright ImageMagick Studio LLC and contributors: ImageMagick License, see `LICENSES/IMAGEMAGICK.txt`
- Microsoft Windows App SDK 1.6.250602001 and its self-contained runtime files, copyright Microsoft Corporation: Microsoft Software License Terms, see `LICENSES/WINDOWS_APP_SDK.txt`; incorporated open-source notices are in `LICENSES/WINDOWS_APP_SDK_NOTICE.txt` and `LICENSES/WINDOWS_APP_SDK_TOOLS_NOTICE.txt`
- Microsoft WebView2 SDK 1.0.2651.64 loader and managed projection files, copyright Microsoft Corporation: BSD-style license, see `LICENSES/WEBVIEW2.txt`; incorporated open-source notices are in `LICENSES/WEBVIEW2_NOTICE.txt`
- Microsoft .NET Runtime 8.0.31 self-contained win-x64 runtime pack, copyright .NET Foundation and contributors: MIT License, see `LICENSES/DOTNET_RUNTIME.txt`; incorporated third-party notices are in `LICENSES/DOTNET_RUNTIME_THIRD_PARTY_NOTICES.txt`
- Microsoft Windows SDK BuildTools 10.0.22621.756 and Microsoft Windows SDK .NET runtime projection 10.0.17763.56: Microsoft Windows SDK license terms, see `LICENSES/WINDOWS_SDK_LICENSE.rtf`

The installed Evergreen WebView2 Runtime is supplied and serviced by Microsoft as part of Windows or through Microsoft's WebView2 Runtime distribution. Squoosh Pro redistributes the WebView2 SDK loader/projection files listed above, not a fixed Microsoft Edge browser runtime.

## Apple system frameworks

The macOS application links against Apple-provided SwiftUI, AppKit, WebKit, Core Image, ImageIO, Metal, Uniform Type Identifiers, and related system frameworks. These are operating-system components governed by Apple's platform terms and are not copied into the repository as independently licensed third-party packages.

## Development-only tooling

Swift Package Manager, Xcode, the .NET SDK, MSBuild, the Windows SDK build tools, Node.js, and test automation supplied by the operating system or SDK are used to build or verify the project. They are not bundled as separate applications or browser plug-ins. The codec worker package declares no external npm dependencies, and the Swift package declares no external Swift package dependencies.

## Trademarks

Google, Chrome, Microsoft, Windows, Apple, macOS, and other names may be trademarks of their respective owners. Their appearance identifies compatibility or upstream components only.
