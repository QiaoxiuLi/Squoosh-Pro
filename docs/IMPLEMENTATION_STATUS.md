# Implementation Status

This file distinguishes implemented behavior from current validation evidence. The latest release evidence is recorded in `TEST_RESULTS.md` under 0.3.0; older large-image and stress results remain historical, not new claims.

| Area | Status | Evidence or remaining gate |
| --- | --- | --- |
| Versioned preset/request/response/report contracts | Verified | Node contract tests pass |
| Preset validation and built-in presets | Verified | `SquooshCoreCheck` passes |
| JPEG fixed-quality output | Verified | Generated-image encode and re-decode pass |
| JPEG strict byte target | Verified | Actual bytes, adaptive width, decode, and dimension checks pass |
| PNG native output | Verified | Generated fixture encoding passes |
| Atomic no-overwrite output | Verified | Temporary write, `fsync`, hard-link commit, conflict rename pass |
| Source fingerprint preservation | Verified | SHA-256 before and after end-to-end test is unchanged |
| MozJPEG/OxiPNG/WebP/AVIF WASM at 100x100 | Verified | Four-format Node smoke test passes |
| MozJPEG/OxiPNG/WebP/AVIF WASM at 4000x3000 | Verified | Scale check passes |
| 48MP MozJPEG/OxiPNG/WebP | Verified | 8000x6000 scale check passes |
| 48MP AVIF | Verified on development macOS native helper | ImageIO 8000x6000 encode, signature, decode, dimensions, source preservation, and helper interruption pass; pinned WASM remains unsuitable at 48MP |
| 200-file steady-memory smoke test | Verified with limitation | Second 100-file cycle adds 2MB RSS; WKWebView Instruments gate remains |
| SwiftUI/AppKit workspace source | Verified | Xcode 27.0 builds the complete application target |
| WebKit offline codec adapter | Verified | Real WKWebView four-codec encode, CSP network block, cancellation, rebuild, post-rebuild encoding, and sandboxed app launch pass |
| Image/folder import, recursion, drag/drop, thumbnail list | Implemented, partial UI verification | Native launch and file picker were exercised; full automated Finder matrix still needs XCUITest |
| Responsive workspace and comparison controls | Verified with limitation | Native layer pixel/geometry tests and real SwiftUI hosting at four sizes pass; live selection, file-change invalidation, cache and export pass; a complete XCUITest interaction matrix remains |
| Batch pause/resume/cancel/failure retry | Implemented, UI automation gate remains | WASM interruption/rebuild and native AVIF helper termination pass; complete SwiftUI interaction matrix still needs XCUITest |
| Manifest history | Implemented | Atomic JSON manifests; SQLite index not added |
| Interrupted-task resume | Implemented, UI gate remains | Source/output bookmarks, stale handling, fingerprints, same-directory continuation, and cleanup implemented; bookmark round trip passes |
| XCTest/XCUITest | XCTest verified; XCUITest gate remains | 12 core plus 6 native preview/application tests pass; dedicated full-app XCUITest target is still required |
| Universal 2 command-line verification set | Verified slices | Core, WebKit check, native helper, and helper check report x86_64 + arm64; arm64 runs pass; Intel runtime blocked by absent Rosetta |
| Universal 2 application | Verified slices | Application and native helper report x86_64 + arm64; ad-hoc signature verifies |
| Developer ID signing/notarization/App Store | Not performed | No valid Developer ID identity is installed |
| Windows WinUI 3 application | Verified on Windows 10 and 11 x64 | Windows App SDK 2.5.1 / .NET 10.0.12; 52 targeted UI/visual checks pass on each tested system, not a claim of every possible workflow |
| Windows JPEG/PNG/WebP/AVIF | Verified | Generated-image encode, decode, format, dimensions, and signature checks pass |
| Windows strict 150 KB JPEG | Verified | Output is 142019 bytes at 999×636 on both tested systems; 150000-byte ceiling and source hash pass |
| Windows compact layout | Verified tested matrix | Outer-window sizes 640×480, 760×540, 920×680, 1280×800 and 1500×680; repeated compact/wide switching, settings and preset controls remain usable |
| Windows preview cache | Verified | Bounded item/byte checks pass and UI export reuses unchanged preview results |
| Windows release packaging | Verified with limitation | Self-contained x64 publish includes the required PRI resources; Authenticode signing is not configured |

Publication requires explicit user authorization. A public Release does not establish signing, notarization, Store readiness, universal device coverage, or completion of the remaining gates. Disclose those limits alongside the download; do not report skipped gates as passed.
