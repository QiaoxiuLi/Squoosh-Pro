# Changelog

## 0.2.0-beta.1 - 2026-09-24

- Added a native WinUI 3 application for Windows 10 and Windows 11 x64.
- Added local JPEG, PNG, WebP, and AVIF encoding through Magick.NET.
- Added strict per-image decimal 150 KB JPEG output with 1000, 960, and 920 pixel adaptive widths.
- Added searchable queues, click-to-preview, comparison slider, bounded preview cache, reusable preview results, and timestamped output folders.
- Added user presets with notes, import/export, batch pause/resume/cancel, retries, and history.
- Added a hardware-accelerated preview switch with automatic fallback after an interrupted preview startup.
- Added Windows core checks and UI Automation covering nonblank WinUI visual rendering, compact-window navigation and text visibility, settings, compression, byte limits, decode verification, and source preservation.
- Verified the same self-contained x64 candidate on Windows 10 10.0.19045.6456 and Windows 11 10.0.26200.9457.

This Windows beta is not Authenticode signed and may trigger SmartScreen. The existing macOS beta remains ad-hoc signed and not notarized.

## 0.1.0-beta.1 - 2026-09-15

- Native macOS batch image compression with local JPEG, PNG, WebP, and AVIF processing.
- Strict per-image JPEG size targeting with the built-in `Web JPEG <=150KB` preset.
- Timestamped output directories, atomic writes, conflict-safe file names, and source-file protection.
- Responsive compact layout for small windows, simplified settings, and clearer preview and batch status text.
- Searchable image queue, click-to-preview, and a bounded preview cache reused during export.
- Metal-backed preview rendering with a user-controlled hardware-acceleration switch and automatic safe fallback.
- Decimal KB size controls, clearer JPEG option explanations, and real progressive/baseline MozJPEG output.
- User preset names and notes, plus import and export of user-created presets.
- Universal 2 application and AVIF helper for Apple silicon and Intel Macs.
- Pause, resume, cancel, retry, job history, and interrupted-job recovery foundations.

This beta archive is ad-hoc signed and is not notarized. It is intended for local evaluation until Developer ID signing is configured.
