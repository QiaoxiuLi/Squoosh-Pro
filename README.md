# Squoosh Pro

Squoosh Pro is a native desktop batch image compressor for macOS and Windows. Its workflow is deliberately simple: add images, choose a purpose, inspect the result, and compress safely. Images are processed locally and the app never overwrites source files.

> Squoosh Pro is an independent project by Qiaoxiu Li. It is not an official Google product and is not affiliated with or endorsed by Google. The project reuses separately licensed codec components from the open-source Squoosh project; see `third_party/THIRD_PARTY_NOTICES.md`.

## Current Development Status

The repository contains a native SwiftUI/AppKit application for macOS and a native WinUI 3 application for Windows 10 and 11. Both implementations include safe output handling, strict JPEG byte targeting, batch state management, bounded preview caching, user presets, and local-only processing.

The macOS application is built and tested with Xcode 27.0. Core, recovery, strict-size, native 48MP AVIF, sandboxed WKWebView codec-host, and protected-file checks pass. Its packaged application and AVIF helper contain both arm64 and x86_64 slices.

The Windows x64 application is self-contained and uses Windows App SDK 1.6 plus Magick.NET 14.17.1. Core checks and full UI Automation flows pass on Windows 10 10.0.19045.6456 and Windows 11 10.0.26200.9457. The GUI test captures and analyzes the WinUI visual tree for the workspace, compression settings, compact 920×680 layout, application settings, and completed state instead of treating a blank desktop screenshot as success.

Both downloadable builds are unsigned evaluation prereleases. The macOS build is ad-hoc signed and not notarized; the Windows build has no Authenticode signature and can trigger SmartScreen. See `docs/KNOWN_LIMITATIONS.md` for the exact release boundary.

## Highlights

- Native SwiftUI and AppKit interface for macOS 13 and later
- Native WinUI 3 interface for Windows 10 and Windows 11 x64
- Multiple image and folder import, recursive folder discovery, and Finder drag and drop
- Searchable image queue with click-to-preview and bounded preview-result caching reused by export
- Original/output comparison with a draggable divider, fit, and 100% viewing modes
- Metal-backed Core Image preview rendering with a persistent hardware-acceleration switch and startup fallback
- Fixed-quality JPEG and PNG output
- Strict per-image JPEG limits entered as decimal KB and enforced using measured bytes and adaptive width/quality search
- Built-in presets including `网页 JPEG ≤150KB`
- Timestamped output directories and no-overwrite conflict renaming
- Temporary-file verification followed by atomic no-overwrite commit
- Pause, resume, cancel, per-file failures, retry, manifests, and history records
- Security-scoped bookmark restoration with source fingerprint checks for interrupted jobs
- Interruptible WebKit codec execution with automatic host reconstruction and one safe retry after a process crash
- Killable local ImageIO AVIF helper when the running macOS supports it, with bundled WASM fallback
- Versioned JSON Schema contracts kept free of macOS path types
- Bundled offline codec resources with CSP and navigation rules that block external requests
- Self-contained Windows distribution with no separate .NET or Windows App SDK installation required

## Runtime Requirements

- macOS 13 or newer on Apple silicon or Intel
- 64-bit Windows 10 or Windows 11 for the Windows x64 package

## Development Requirements

- macOS: Swift 6 and full Xcode
- Windows: .NET SDK 8.0.425 and Visual Studio 2022 Build Tools with MSBuild and Windows SDK support

## Build macOS

```bash
./scripts/bootstrap.sh
./scripts/build-codecs.sh
./scripts/build-macos.sh
./scripts/build-release.sh
```

The local development application is generated at:

```text
Artifacts/Squoosh Pro.app
```

## Build Windows

Run from PowerShell on a Windows x64 build machine:

~~~powershell
.\scripts\windows\build-release.ps1
~~~

The script creates the self-contained application folder, ZIP, and SHA-256 file under `Artifacts\WindowsRelease`.

## Test macOS

```bash
./scripts/test-all.sh
./scripts/verify-release.sh
./scripts/build-universal-core.sh
```

Tests only use generated fixtures. Files under a user's selected source directory are opened read-only and are never copied into this repository.

To rerun the generated 8000x6000 AVIF gate explicitly:

```bash
SQUOOSH_RUN_48MP_AVIF=1 swift run SquooshCoreCheck
```

## Test Windows

~~~powershell
.\scripts\windows\run-core-checks.ps1
.\scripts\windows\run-ui-tests.ps1 -ApplicationPath .\Artifacts\WindowsRelease\Squoosh-Pro-0.2.0-Windows-x64\SquooshPro.exe
~~~

The UI test must run from a signed-in interactive desktop session. It exercises real WinUI controls, strict output, source preservation, narrow-window layout, and nonblank visual rendering.

## Default 150KB Preset

The app displays size limits in decimal KB, where `1 KB = 1,000 bytes`. The built-in preset therefore interprets `150 KB` as exactly `150,000 bytes`, with a `145,000-byte` safety target. It tries widths `1000`, `960`, and `920` without upscaling, and searches for the highest JPEG quality that satisfies the actual byte cap. If no valid candidate meets the limit, the item fails with `targetNotMet`; an oversized image is never reported as successful.

## Documentation

- [普通用户使用说明（中文）](docs/USER_GUIDE_ZH.md)
- [Windows 普通用户使用说明（中文）](docs/USER_GUIDE_WINDOWS_ZH.md)
- [0.1.0 Beta 1 发布说明（中文）](docs/RELEASE_NOTES_0.1.0_BETA1_ZH.md)
- [0.2.0 Beta 1 Windows 发布说明（中文）](docs/RELEASE_NOTES_0.2.0_BETA1_ZH.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data safety](docs/DATA_SAFETY.md)
- [Preset schema](docs/PRESET_SCHEMA.md)
- [Testing](docs/TESTING.md)
- [Release process](docs/RELEASE.md)
- [Windows implementation](docs/WINDOWS_FUTURE.md)
- [Implementation status and release gates](docs/IMPLEMENTATION_STATUS.md)
- [Recorded test results](docs/TEST_RESULTS.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Privacy

Squoosh Pro does not require an account or upload images. Runtime codec files are bundled with the app. Logs avoid image contents and full source paths.

## License

Original Squoosh Pro code is licensed under the MIT License. Third-party components retain their respective licenses and notices.
