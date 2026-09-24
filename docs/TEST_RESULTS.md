# Test Results

Recorded on 2026-09-15 with Xcode 27.0, Apple Swift 6.4, macOS SDK 27.0, Node.js 24.18.0, and arm64.

Windows results were recorded on 2026-09-24 using the same self-contained x64 release candidate on:

- Windows 10 10.0.19045.6456
- Windows 11 10.0.26200.9457
- .NET SDK 8.0.425 and Visual Studio Build Tools 2022 on the Windows 11 build host
- Windows App SDK 1.6.250602001 and Magick.NET-Q8-x64 14.17.1

## Passed

- Windows release build: 0 warnings and 0 errors; required project PRI is present in the unpackaged publish output
- Windows core checks: built-in presets, resize/no-upscale, strict decimal 150 KB JPEG, JPEG/PNG/WebP/AVIF encode-decode-signature verification, atomic commit, source protection, conflict rename, and bounded preview cache
- Windows 10 and Windows 11 UI Automation: main window, search, preview comparison slider, target KB, quality slider, preset save, clickable advanced-option explanations, compact-window start command and fully visible preview labels, hardware acceleration default, batch start, output verification, source preservation, and completion
- Windows 10 and Windows 11 internal WinUI renders: workspace, compression settings, 920×680 compact window, application settings, and completed state all pass nonblank content analysis
- Windows strict-size UI result on both systems: 142019-byte JPEG, 999×636 pixels, no source hash change
- Four codec smoke tests: MozJPEG, WebP, AVIF, OxiPNG at 100x100
- Two contract tests: JSON Schema syntax/version fields and stable platform-neutral enums
- Core executable checks: built-in presets, target-byte binary search, aspect ratio, no-upscale, strict 150,000-byte result, width cap, atomic commit, decode/signature/dimension/byte verification, source SHA-256 preservation, and conflict renaming
- Security-scoped input/output bookmark persistence, restoration, and completed-record cleanup
- Native ImageIO AVIF helper: in-progress termination followed by 8000x6000 encode, AVIF signature, re-decode, exact dimensions, and source preservation
- Real WKWebView: all four local codecs, CSP external-network block, in-progress interruption, host reconstruction, and post-rebuild encoding
- Universal command-line binaries: core check, WebKit check, native AVIF worker, and native-helper check each contain x86_64 and arm64 slices; all check executables pass natively as arm64
- Universal application package: the application and AVIF helper each contain x86_64 and arm64 slices; deep ad-hoc signature verification and ZIP integrity checks pass
- Stateful SwiftUI application compilation and native launch
- Responsive empty-state layout, simplified settings copy, hidden empty batch summary, and sandboxed codec initialization
- Swift source parser over all core, application, and check sources
- Protected-file SHA-256 comparison for 31 original JPEGs and 30 existing result JPEGs
- 4000x3000 WASM encoding for all four codecs
- 8000x6000 WASM encoding for MozJPEG, WebP, and OxiPNG
- Two consecutive 100-file mixed-codec cycles: 73MB initial RSS, 147MB after first cycle, 149MB after second cycle

## Failed or Blocked

- Windows Authenticode signing, signed installer creation, Windows ARM64, and Microsoft Store packaging were not run.
- Pinned AVIF WASM at 8000x6000 returns no encoded result; runtime-native ImageIO AVIF is the verified large-image path.
- A dedicated Xcode project/UI-test target has not been added, so the complete XCUITest interaction and window-size matrix has not run.
- Intel runtime execution was not run because Rosetta is absent; explicit `arch -x86_64` returns `Bad CPU type in executable` even though both Intel slices build and link.
- Developer ID signing and notarization were not run because no valid distribution identity is installed.

No failing gate is reported as passed. See `docs/IMPLEMENTATION_STATUS.md` for the delivery boundary.
