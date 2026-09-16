# macOS Application

Open the repository's root `Package.swift` in full Xcode. The executable target is `SquooshPro`; reusable targets are `SquooshCore` and `SquooshCodecHost`; deployment starts at macOS 13.

The command-line development bundle script is `scripts/build-macos.sh`. It deliberately refuses to package the application when only Command Line Tools are active because the stateful SwiftUI source requires Xcode's macro plugins.

Use `Config/Development.xcconfig` and `Config/SquooshPro.entitlements` when creating an Xcode application scheme. Sign the native AVIF helper with `Config/SquooshProHelper.entitlements` so it inherits the parent sandbox and selected-file access. Do not add network client/server entitlements. Release signing values belong in a local, untracked configuration derived from `Config/Distribution.xcconfig.example`.
