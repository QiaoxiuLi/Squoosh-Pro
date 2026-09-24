# Known Limitations

- The GitHub prerelease is ad-hoc signed. Developer ID signing, notarization, App Store submission, and automatic updates still require user-owned Apple distribution credentials.
- The pinned upstream AVIF WASM encoder still fails generated 48MP input. The application now uses a killable helper process around runtime-detected native ImageIO AVIF encoding when available; generated 8000x6000 encode, signature, decode, dimensions, source preservation, and in-progress interruption pass on this development Mac. macOS 13 and latest-stable release testing remain required.
- Real WKWebView checks pass for all four local codecs, CSP network blocking, in-progress interruption, host reconstruction, post-rebuild encoding, and sandboxed application startup. Long-duration Instruments profiling remains a later gate.
- Interrupted jobs persist security-scoped source/output bookmarks and source fingerprints and expose user-confirmed resume. The bookmark round trip passes; a complete automated Powerbox interruption matrix still requires a dedicated XCUITest target.
- The packaged application, AVIF helper, and command-line verification binaries contain `arm64 + x86_64` slices and run as arm64. This Mac has no Rosetta, so Intel hardware or Rosetta is still required for the x86_64 runtime gate.
- The Windows 0.2.0 package is x64 only. Windows ARM64, 32-bit Windows, and Windows 7 are not supported.
- The Windows package has no Authenticode signature and can trigger SmartScreen. A signed installer and Microsoft Store package have not been produced.
- Windows core and GUI flows pass on Windows 10 10.0.19045.6456 and Windows 11 10.0.26200.9457. The project targets Windows 10 version 1809, but every intervening Windows build was not tested.
- Animated GIF, animated WebP, animated AVIF, image editing, crop, filters, folder watching, Finder extensions, cloud sync, accounts, and automatic updates are not first-release features.
