# Testing

Run the checks supported by the current machine:

```bash
./scripts/test-all.sh
```

With full Xcode, the script runs XCTest. With Command Line Tools only, it runs `SquooshCoreCheck`, which exercises preset validation, target-byte search, resize calculation, generated-image encoding, atomic commit, output re-decode, byte and dimension verification, conflict naming, source fingerprint preservation, and security-scoped recovery bookmarks. It also runs `SquooshWebKitCheck` against a real local WKWebView for all four codecs, CSP network isolation, cancellation, host reconstruction, and post-rebuild encoding. `SquooshNativeCodecCheck` verifies that the separate ImageIO AVIF helper can be terminated mid-encode and then encode and validate a generated 48MP image without changing its source.

`shared/codec-worker/tests/contracts.test.mjs` checks contract syntax, required fields, and stable enum values using Node's built-in test runner. `shared/codec-worker/tests/codec-smoke.test.mjs` loads each vendored encoder and encodes a generated 100x100 RGBA image.

`scripts/e2e-generated.sh` creates its fixtures in a temporary directory, processes them, verifies each output, and removes only that temporary directory. It never reads `Task`.

## Windows Matrix

Run the generated-image core checks:

~~~powershell
.\scripts\windows\run-core-checks.ps1
~~~

Build the self-contained release and then run the GUI test from a signed-in desktop:

~~~powershell
.\scripts\windows\build-release.ps1 -Version 0.3.0
.\scripts\windows\run-ui-tests.ps1 -ApplicationPath .\Artifacts\WindowsRelease\Squoosh-Pro-0.3.0-Windows-x64\SquooshPro.exe
~~~

The Windows core runner checks built-in presets, resize math, no-upscale behavior, strict decimal 150 KB JPEG, JPEG/PNG/WebP/AVIF signature and decode verification, atomic commit, source SHA-256 preservation, conflict renaming, and bounded cache eviction.

The UI runner imports a generated image through a test-only launch argument, then exercises search, decoded previews, native SendInput divider dragging, true 100%/zoom controls, compression settings, preset dialog/name/notes persistence, compact/wide resizing, settings, four-format previews, batch export, byte limit, output dimensions, decode verification, source preservation, and completion. Sizes cover 640×480 through 1500×680. For important states, the app renders its WinUI visual tree into a PNG. The runner waits until the render request is complete before checking minimum dimensions, nonwhite content, and color variation. It closes only the app instance it started.

Remote execution must still start the runner in the existing interactive Windows session. SSH is used only to copy files and invoke the configured test command; no remote-control software or Windows-hosted coding agent is required.

## Full Xcode Matrix

The checked-in XCTest sources cover core behavior and generated files, native comparison layer pixels/geometry, real SwiftUI hosting at four sizes, live preview selection, source changes, cache and export. XCUITest must additionally cover complete user interaction with image and folder selection, Finder drag and drop, comparison gestures, settings, preset save, batch start, pause/resume/cancel, failures, output opening, recovery, appearance and keyboard access. Hosting/component tests are not described as full XCUITest.

Performance acceptance requires Instruments or equivalent measurement for 1000 imported paths, 100 previews, 500 synthetic encodes, 48MP processing, cancellation recovery, and bounded worker memory. These are release gates, not claims made from source inspection.

## Recorded Command-Line Results

On 2026-09-15, all four WASM encoders successfully encoded generated `4000x3000` RGBA input. MozJPEG, WebP, and OxiPNG also encoded generated `8000x6000` (48MP) input. The pinned AVIF WASM returned no result at 48MP even in a fresh process with a 4GB Node heap, so Squoosh Pro now selects a separate native ImageIO helper when the running system exposes `public.avif`. The helper passed interruption and subsequent 8000x6000 encode, signature, decode, dimension, and source-preservation verification.

`scripts/build-universal-core.sh` builds `SquooshCoreCheck`, `SquooshWebKitCheck`, `SquooshNativeCodecWorker`, and `SquooshNativeCodecCheck` for both architectures and combines each with `lipo`. All report `x86_64 arm64`; the three check executables pass when launched natively as arm64. Explicit x86_64 execution requires Rosetta or Intel hardware; Rosetta is not installed on this development Mac.

Two consecutive 100-file cycles alternating all four codecs measured 73MB before first use, 147MB after the first cycle, and 149MB after the second. The 2MB second-cycle increase shows that one-time WASM heap initialization dominates this smoke test, but it is not a substitute for Instruments testing inside WKWebView.
