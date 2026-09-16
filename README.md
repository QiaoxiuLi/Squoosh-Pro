# Squoosh Pro

Squoosh Pro is a native macOS batch image compressor designed around a simple workflow: add images, choose a purpose, inspect the result, and compress safely. Images are processed locally and the app never overwrites source files.

> Squoosh Pro is an independent project by Qiaoxiu Li. It is not an official Google product and is not affiliated with or endorsed by Google. The project reuses separately licensed codec components from the open-source Squoosh project; see `third_party/THIRD_PARTY_NOTICES.md`.

## Current Development Status

The repository contains the native SwiftUI application source, platform-neutral preset and job contracts, safe output handling, strict JPEG byte targeting, batch state management, tests, and an offline codec-host adapter. Explicit JPEG output uses the bundled MozJPEG encoder so progressive, baseline, and coding-optimization settings affect the real output. Squoosh WASM assets for MozJPEG, OxiPNG, WebP, and AVIF are vendored for the offline host integration.

The native application is built and tested with Xcode 27.0. Core, recovery, strict-size, native 48MP AVIF, sandboxed WKWebView codec-host, and protected-file checks pass. The packaged application and its AVIF helper contain both `arm64` and `x86_64` slices. The downloadable prerelease is ad-hoc signed for local evaluation; Developer ID signing, notarization, Intel runtime testing, and App Store publication are not represented as completed. See `docs/KNOWN_LIMITATIONS.md` for the exact release boundary.

## Highlights

- Native SwiftUI and AppKit interface for macOS 13 and later
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

## Requirements

- macOS 13 or newer
- Swift 6 toolchain
- Full Xcode is recommended for application and UI testing

## Build

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

## Test

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

## Default 150KB Preset

The app displays size limits in decimal KB, where `1 KB = 1,000 bytes`. The built-in preset therefore interprets `150 KB` as exactly `150,000 bytes`, with a `145,000-byte` safety target. It tries widths `1000`, `960`, and `920` without upscaling, and searches for the highest JPEG quality that satisfies the actual byte cap. If no valid candidate meets the limit, the item fails with `targetNotMet`; an oversized image is never reported as successful.

## Documentation

- [普通用户使用说明（中文）](docs/USER_GUIDE_ZH.md)
- [0.1.0 Beta 1 发布说明（中文）](docs/RELEASE_NOTES_0.1.0_BETA1_ZH.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data safety](docs/DATA_SAFETY.md)
- [Preset schema](docs/PRESET_SCHEMA.md)
- [Testing](docs/TESTING.md)
- [Release process](docs/RELEASE.md)
- [Future Windows foundation](docs/WINDOWS_FUTURE.md)
- [Implementation status and release gates](docs/IMPLEMENTATION_STATUS.md)
- [Recorded test results](docs/TEST_RESULTS.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Privacy

Squoosh Pro does not require an account or upload images. Runtime codec files are bundled with the app. Logs avoid image contents and full source paths.

## License

Original Squoosh Pro code is licensed under the MIT License. Third-party components retain their respective licenses and notices.
