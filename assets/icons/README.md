# Squoosh Pro App Icon

The shared master is `SquooshPro.png`, a 1024 x 1024 RGBA image. Its blue/teal tile and stacked picture cards represent local image compression. It contains no text so the silhouette remains readable at small sizes.

The artwork was designed for this project using the built-in OpenAI image generation tool. It does not reuse the Google Squoosh logo or third-party icon/font assets. It is distributed with the project under the root MIT license.

Selected generation prompt:

> Production desktop application icon for Squoosh Pro, a local image-compression application on macOS and Windows. A rounded-square deep ocean-blue to teal tile, softly beveled with restrained tactile depth. Center a bold white folded photograph/card motif: two compact overlapping picture sheets, a teal mountain silhouette, a circular sun and a folded corner suggesting a compact image. Crisp silhouette, generous negative space, no text, no badges, no arrows, orthographic view, transparent outer margins.

`bash scripts/build-icons.sh` uses macOS `sips`, `iconutil` and the small Swift ICO container writer to regenerate platform resources without altering the master artwork:

- `SquooshPro.icns`: macOS 16, 32, 128, 256 and 512 point images at 1x/2x, up to 1024 pixels.
- `SquooshPro.ico`: Windows 16, 20, 24, 32, 40, 48, 64, 128 and 256 pixel lossless PNG frames.

macOS app bundles register the ICNS with `CFBundleIconFile`. Windows embeds the ICO in the native executable and also loads it into `AppWindow`; the PNG is used in the custom title bar. The separate asset files must remain beside the Windows executable in `Assets/`.

`swift scripts/check-app-icon.swift <project-root> [app-bundle] [pid]` validates resources and macOS system/runtime icon resolution. Windows UI checks validate executable, shortcut, small/large window and title-bar icons.
