# Windows Implementation

The Windows application is implemented under `apps/windows`.

## Platform

- UI: WinUI 3 with Windows App SDK 2.5.1; Fluent controls, Mica where available, opaque fallback on older systems
- Language: C# on .NET 10, SDK 10.0.401 and self-contained runtime 10.0.12
- Package type: unpackaged, self-contained x64 desktop application
- Minimum target: Windows 10 version 1809
- Verified systems: Windows 10 10.0.19045.6466 and Windows 11 10.0.26200.9457
- Image engine: Magick.NET-Q8-x64 14.17.1

## Projects

- `SquooshPro.Core`: presets, resize calculations, target-byte search, output encoding, file verification, atomic commit, source fingerprints, and bounded cache
- `SquooshPro.Windows`: WinUI workspace, preview, settings, presets, queue, history, drag and drop, and batch state
- `SquooshPro.WindowsChecks`: generated-image core verification for all four formats and output safety
- `SquooshPro.WindowsUiTests`: UI Automation plus application-internal WinUI render capture and visual-content analysis

## Release Boundary

The 0.3.0 package is x64 only. It contains the .NET runtime, Windows App SDK runtime, and image codec dependencies, so end users do not install a separate runtime. It is not Authenticode signed and can trigger SmartScreen.

The workspace uses three permanent panes. Compact windows select one pane through SelectorBar instead of reparenting controls. Comparison images share geometry, with an in-canvas draggable divider, true pixel zoom and pan. Gestures do not invoke encoding. Preview work is debounced and serialized; successful results enter a bounded cache for export reuse. The tests use stable automation IDs and isolated data directories.

Windows ARM64, a signed installer, Microsoft Store packaging, automatic updates, and long-duration performance profiling remain future work. They are not represented as completed.
