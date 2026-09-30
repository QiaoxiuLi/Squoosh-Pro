# Test Results

## 0.3.1: 2026-09-30

This release changes application icons, version labels and icon packaging checks. The compression engine, presets, storage format and preview interaction remain unchanged from 0.3.0.

### Current Passed Checks

| Gate | Evidence |
| --- | --- |
| Shared artwork | 1024 x 1024 RGBA master; ICNS representations from 16 to 1024 pixels; nine independently decoded ICO frames at 16, 20, 24, 32, 40, 48, 64, 128 and 256 pixels |
| macOS system icon | Release bundle declares `CFBundleIconFile` and contains the exact ICNS; NSWorkspace file-system icon and NSRunningApplication runtime/Dock icon match the branded artwork; unrelated Finder icon is rejected as a negative control |
| macOS regression | 18 XCTest tests pass on macOS 26.6.2 (25G83), Apple Silicon |
| macOS release | App and AVIF helper contain arm64 and x86_64 slices; ad-hoc deep signature verification, native launch and ZIP integrity pass |
| Windows 10 | 58 UI checks pass on 22H2, build 19045.6466, using the full extracted final release ZIP |
| Windows 11 | 58 UI checks pass on 25H2, build 26200.9457, against the same final release build |
| Windows icon resolution | New checks read the embedded EXE icon, resolve a temporary `.lnk` through Windows Shell, compare WM_GETICON large/small window icons and inspect the custom title-bar image; all pass on both systems |
| Windows regression | Existing decoded four-format previews, native divider drag, zoom, presets, responsive layouts and batch export pass on both systems; exported JPEG is 142019 bytes, 999 x 636, re-decodes successfully and preserves its source hash |
| Windows core | Nine core check groups pass on the isolated Windows 11 build host |
| Protected data | All 31 protected originals and 30 existing outputs retain their recorded SHA-256 values |

Windows ZIP SHA-256: `45dbcfed79adfc199d169645c1dc57872be7e00fd7d6af4a20e0959b94101b8f`.

macOS ZIP SHA-256: `55303f8d42aaa323c62ee00f985223af0cb28b6cba92487f0ed4a9d9ae7267ee`.

The Windows EXE SHA-256 is `70766ea5c15e7f54ccc820bb91da2a7ca1d2bdb6455c65c6c1443316bfdfa2f0`; the application DLL SHA-256 is `0011582e41f27d8375438132514606c8705f43c6efbf4db91141710165d1f4d2`. Both machines report these exact values. Local test JSON and generated-artwork renders are retained under `Artifacts/Release-0.3.1/`.

### Boundaries

- Windows testing used only the authorized SSH ports 2210 and 2211. No remote Codex or remote-control software was used. Temporary interactive scheduled tasks were removed; existing user desktop shortcuts and global icon caches were not changed.
- macOS applies an icon inset during system rendering. The first raw pixel comparison rejected that normal scaling difference; the final check normalizes artwork bounds, keeps its strict artwork threshold and rejects an unrelated icon rather than accepting any nonblank bitmap.
- Developer ID signing, notarization, Authenticode signing, Intel runtime execution, Windows ARM64 and full-app macOS XCUITest were not added or claimed by this icon-only release. Earlier codec/integration evidence is recorded below, not presented as newly rerun.

## 0.3.0: 2026-09-29

### Environment

- macOS 26.6.2 (25G83), Apple Silicon, Xcode 27.0; release app/helper build as Universal 2.
- Windows 10 22H2, 10.0.19045.6466, x64.
- Windows 11 25H2, 10.0.26200.9457, x64.
- Isolated .NET SDK 10.0.401, runtime 10.0.12, Windows App SDK 2.5.1 and Magick.NET 14.17.1. Existing machine SDKs were not replaced.
- Remote Windows testing used only the user-authorized SSH route, without remote Codex or remote-control software.

### Current Passed Checks

| Gate | Evidence |
| --- | --- |
| Windows core | Nine check groups on each OS: presets, resize/no-upscale, strict decimal KB, four-format encode/decode/signature, atomic commit, conflict rename, source preservation and bounded cache |
| Windows native UI | 52 targeted UI Automation/visual checks per OS: decoded preview, zoom, native pointer drag, preset dialog/name/notes persistence, help popup, settings, compact/wide switching, four-format preview and batch export |
| Windows layout | 640×480, 760×540, 920×680, 1280×800 and 1500×680 outer-window sizes; preview controls stay inside the window; preset/settings controls also checked at 640×480 |
| Windows strict-size GUI export | 142019-byte JPEG, 999×636 pixels, successful re-decode, source SHA-256 unchanged on both systems |
| macOS XCTest | 18 tests: 12 core and 6 preview/application cases; actual layer pixels verify original-left/output-right; fit, backing-scale-aware 100%, zoom, portrait/wide geometry, selection, cache/export and changed-source invalidation |
| macOS SwiftUI hosting | Real ContentView/NSHostingView at 1400×900, 960×680, 720×480 and 1400×480; native comparison view stays within the workspace. These are component/hosting tests, not full-app XCUITest |
| macOS integration | Core executable checks, four local WKWebView codecs and offline CSP, codec cancellation/rebuild, native 48MP AVIF helper and interruption |
| Shared worker | Six codec/schema tests |
| Protected data | SHA-256 checks for all 31 protected originals and 30 existing results remain unchanged |
| macOS package | Both app and helper contain arm64/x86_64 slices; deep ad-hoc signature verification; native arm64 app launch |

Final per-run JSON results and rendered images are retained locally under `Artifacts/`. Repository screenshots use generated test artwork, not private originals.

The final scripted Windows publish was tested directly on both systems, including Windows 10 extraction of the complete ZIP. ZIP SHA-256: `80fb168e71b4520126b2bb26a29b0ef6656f527c4874ed926491e019982a7fd8`; application DLL SHA-256: `806dac7f4abe2d13889fa11481fb8a0263a976e786c2d443f569127a2e2999ae`. This is the published package, not the earlier candidate whose assembly metadata differed.

### Limits and Corrected Test Failures

- Compact-to-wide TabView reparenting caused a real WinUI crash during development. The final implementation keeps all panels under a fixed parent and switches SelectorBar visibility instead; repeated resizing passes.
- The pointer test originally used cursor repositioning and an insufficient movement threshold. It now injects native SendInput mouse movement and requires more than ten percentage points of divider movement; both OS runs move from 65% to about 79.6%.
- On Windows 10, a test attempted to read a PNG before the application had finished writing it. The runner now waits for request completion as well as image existence; this does not bypass image analysis or the decode gate.
- Mica is compositor content and is not included in RenderTargetBitmap. Windows 11 internal renders may have transparent shell pixels; UI Automation supplies the real control bounds. Windows 10 repository screenshots use the opaque fallback shell.
- Full-app macOS XCUITest, Intel runtime execution, Windows ARM64, signed installers/Store packages, Authenticode signing, Developer ID and notarization remain unverified or unavailable. The local computer-use service failed internally during interactive macOS validation; native XCTest/SwiftUI hosting and live AppModel integration are the available evidence, not a substitute claim of complete XCUITest coverage.
- No claim is made that every display/DPI setting was tested or that 60/120 FPS was measured. Gesture handlers reuse decoded images and update only geometry/masks; hardware-dependent frame-rate measurement remains separate.

## Historical 0.2.0 Checks

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
