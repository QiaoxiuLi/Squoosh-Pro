#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_ROOT/assets/icons/SquooshPro.png"
BUILD="$PROJECT_ROOT/Artifacts/IconBuild"
ICONSET="$BUILD/SquooshPro.iconset"
mkdir -p "$ICONSET" "$BUILD/windows"

for size in 16 32 128 256 512; do
  sips --resampleHeightWidth "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips --resampleHeightWidth "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$PROJECT_ROOT/assets/icons/SquooshPro.icns"

frames=()
for size in 16 20 24 32 40 48 64 128 256; do
  path="$BUILD/windows/$size.png"
  sips --resampleHeightWidth "$size" "$size" "$SOURCE" --out "$path" >/dev/null
  frames+=("$path")
done
swift "$PROJECT_ROOT/scripts/write-ico.swift" "$PROJECT_ROOT/assets/icons/SquooshPro.ico" "${frames[@]}"
echo "Platform icons rebuilt from assets/icons/SquooshPro.png"
