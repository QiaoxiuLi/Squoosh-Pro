# Windows Implementation

The Windows application is implemented under `apps/windows`.

## Platform

- UI: WinUI 3 with Windows App SDK 1.6
- Language: C# on .NET 8
- Package type: unpackaged, self-contained x64 desktop application
- Minimum target: Windows 10 version 1809
- Verified systems: Windows 10 10.0.19045.6456 and Windows 11 10.0.26200.9457
- Image engine: Magick.NET-Q8-x64 14.17.1

## Projects

- `SquooshPro.Core`: presets, resize calculations, target-byte search, output encoding, file verification, atomic commit, source fingerprints, and bounded cache
- `SquooshPro.Windows`: WinUI workspace, preview, settings, presets, queue, history, drag and drop, and batch state
- `SquooshPro.WindowsChecks`: generated-image core verification for all four formats and output safety
- `SquooshPro.WindowsUiTests`: UI Automation plus application-internal WinUI render capture and visual-content analysis

## Release Boundary

The 0.2.0 Beta 1 package is x64 only. It contains the .NET runtime, Windows App SDK runtime, and image codec dependencies, so end users do not install a separate runtime. It is not Authenticode signed and can trigger SmartScreen.

Windows ARM64, a signed installer, Microsoft Store packaging, automatic updates, and long-duration performance profiling remain future work. They are not represented as completed.
