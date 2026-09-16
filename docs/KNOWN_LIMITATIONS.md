# Known Limitations

- The GitHub prerelease is ad-hoc signed. Developer ID signing, notarization, App Store submission, and automatic updates still require user-owned Apple distribution credentials.
- The pinned upstream AVIF WASM encoder still fails generated 48MP input. The application now uses a killable helper process around runtime-detected native ImageIO AVIF encoding when available; generated 8000x6000 encode, signature, decode, dimensions, source preservation, and in-progress interruption pass on this development Mac. macOS 13 and latest-stable release testing remain required.
- Real WKWebView checks pass for all four local codecs, CSP network blocking, in-progress interruption, host reconstruction, post-rebuild encoding, and sandboxed application startup. Long-duration Instruments profiling remains a later gate.
- Interrupted jobs persist security-scoped source/output bookmarks and source fingerprints and expose user-confirmed resume. The bookmark round trip passes; a complete automated Powerbox interruption matrix still requires a dedicated XCUITest target.
- The packaged application, AVIF helper, and command-line verification binaries contain `arm64 + x86_64` slices and run as arm64. This Mac has no Rosetta, so Intel hardware or Rosetta is still required for the x86_64 runtime gate.
- Animated GIF, animated WebP, animated AVIF, image editing, crop, filters, folder watching, Finder extensions, cloud sync, accounts, and Windows binaries are not first-release features.
