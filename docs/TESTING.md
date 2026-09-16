# Testing

Run the checks supported by the current machine:

```bash
./scripts/test-all.sh
```

With full Xcode, the script runs XCTest. With Command Line Tools only, it runs `SquooshCoreCheck`, which exercises preset validation, target-byte search, resize calculation, generated-image encoding, atomic commit, output re-decode, byte and dimension verification, conflict naming, source fingerprint preservation, and security-scoped recovery bookmarks. It also runs `SquooshWebKitCheck` against a real local WKWebView for all four codecs, CSP network isolation, cancellation, host reconstruction, and post-rebuild encoding. `SquooshNativeCodecCheck` verifies that the separate ImageIO AVIF helper can be terminated mid-encode and then encode and validate a generated 48MP image without changing its source.

`shared/codec-worker/tests/contracts.test.mjs` checks contract syntax, required fields, and stable enum values using Node's built-in test runner. `shared/codec-worker/tests/codec-smoke.test.mjs` loads each vendored encoder and encodes a generated 100x100 RGBA image.

`scripts/e2e-generated.sh` creates its fixtures in a temporary directory, processes them, verifies each output, and removes only that temporary directory. It never reads `Task`.

## Full Xcode Matrix

The checked-in XCTest sources cover pure core behavior and generated files. XCUITest must additionally cover image and folder selection, Finder drag and drop, comparison divider, quality and byte fields, advanced settings, preset save, batch start, pause/resume/cancel, failures, output opening, recovery, light/dark appearance, keyboard access, accessibility identifiers, and narrow/wide windows.

Performance acceptance requires Instruments or equivalent measurement for 1000 imported paths, 100 previews, 500 synthetic encodes, 48MP processing, cancellation recovery, and bounded worker memory. These are release gates, not claims made from source inspection.

## Recorded Command-Line Results

On 2026-09-15, all four WASM encoders successfully encoded generated `4000x3000` RGBA input. MozJPEG, WebP, and OxiPNG also encoded generated `8000x6000` (48MP) input. The pinned AVIF WASM returned no result at 48MP even in a fresh process with a 4GB Node heap, so Squoosh Pro now selects a separate native ImageIO helper when the running system exposes `public.avif`. The helper passed interruption and subsequent 8000x6000 encode, signature, decode, dimension, and source-preservation verification.

`scripts/build-universal-core.sh` builds `SquooshCoreCheck`, `SquooshWebKitCheck`, `SquooshNativeCodecWorker`, and `SquooshNativeCodecCheck` for both architectures and combines each with `lipo`. All report `x86_64 arm64`; the three check executables pass when launched natively as arm64. Explicit x86_64 execution requires Rosetta or Intel hardware; Rosetta is not installed on this development Mac.

Two consecutive 100-file cycles alternating all four codecs measured 73MB before first use, 147MB after the first cycle, and 149MB after the second. The 2MB second-cycle increase shows that one-time WASM heap initialization dominates this smoke test, but it is not a substitute for Instruments testing inside WKWebView.
