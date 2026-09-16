# Architecture

Squoosh Pro separates the native application from reusable compression contracts:

```text
SwiftUI / AppKit
        |
Application model and coordinators
        |
Safe file access + job persistence
        |
CodecHostProtocol
        |
SquooshCodecHost (WKWebView custom local scheme, no network)
        |
Bundled MozJPEG / OxiPNG / WebP / AVIF WASM
        +
Killable native ImageIO AVIF helper for large images
```

`SquooshCore` contains path-independent preset models, state machines, image transforms, target-byte search, source fingerprints, security-scoped recovery records, output verification, and atomic no-overwrite commits. It does not import SwiftUI, AppKit, or WebKit.

`SquooshPro` contains the native macOS interface, file panels, drag and drop, previews, and observable application state. `SquooshCodecHost` owns the invisible WebKit adapter and its bundled resources. A read-only `squoosh-pro://codec/` scheme serves only canonical files below the codec resource root; navigation rejects every other scheme and host. The page CSP denies external connections. `unsafe-eval` is limited to the isolated local page because WebKit's argument-bearing `callAsyncJavaScript` bridge requires it.

`shared/contracts` contains versioned JSON Schema files. Codec IDs and enums are stable strings. Paths in manifests are represented by platform adapters and never embedded in presets.

The first release processes one full-resolution image at a time. This intentionally bounds memory; thumbnails use ImageIO downsampling. A future implementation can raise concurrency after codec-specific memory measurements, but must keep the coordinator as the limit owner.

The native ImageIO encoder is the dependable JPEG/PNG path and output decoder/verifier. WebP is routed through bundled Squoosh WASM. AVIF uses a separately signed, sandbox-inheriting helper process when runtime capabilities expose `public.avif`, avoiding the pinned WASM encoder's 48MP memory limit while allowing a running encode to be terminated without killing the app. AVIF otherwise falls back to bundled WASM.
