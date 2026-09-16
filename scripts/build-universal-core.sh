#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARM_BUILD="$PROJECT_ROOT/.build/universal-arm64"
INTEL_BUILD="$PROJECT_ROOT/.build/universal-x86_64"
OUTPUT_DIR="$PROJECT_ROOT/.build/universal"

swift build --package-path "$PROJECT_ROOT" --scratch-path "$ARM_BUILD" --configuration release --arch arm64 --product SquooshCoreCheck
swift build --package-path "$PROJECT_ROOT" --scratch-path "$ARM_BUILD" --configuration release --arch arm64 --product SquooshWebKitCheck
swift build --package-path "$PROJECT_ROOT" --scratch-path "$ARM_BUILD" --configuration release --arch arm64 --product SquooshNativeCodecWorker
swift build --package-path "$PROJECT_ROOT" --scratch-path "$ARM_BUILD" --configuration release --arch arm64 --product SquooshNativeCodecCheck
swift build --package-path "$PROJECT_ROOT" --scratch-path "$INTEL_BUILD" --configuration release --arch x86_64 --product SquooshCoreCheck
swift build --package-path "$PROJECT_ROOT" --scratch-path "$INTEL_BUILD" --configuration release --arch x86_64 --product SquooshWebKitCheck
swift build --package-path "$PROJECT_ROOT" --scratch-path "$INTEL_BUILD" --configuration release --arch x86_64 --product SquooshNativeCodecWorker
swift build --package-path "$PROJECT_ROOT" --scratch-path "$INTEL_BUILD" --configuration release --arch x86_64 --product SquooshNativeCodecCheck

mkdir -p "$OUTPUT_DIR"
xcrun lipo -create \
  "$ARM_BUILD/out/Products/Release/SquooshCoreCheck" \
  "$INTEL_BUILD/out/Products/Release/SquooshCoreCheck" \
  -output "$OUTPUT_DIR/SquooshCoreCheck"

xcrun lipo -info "$OUTPUT_DIR/SquooshCoreCheck"
"$OUTPUT_DIR/SquooshCoreCheck"

xcrun lipo -create \
  "$ARM_BUILD/out/Products/Release/SquooshWebKitCheck" \
  "$INTEL_BUILD/out/Products/Release/SquooshWebKitCheck" \
  -output "$OUTPUT_DIR/SquooshWebKitCheck"
rm -rf "$OUTPUT_DIR/SquooshPro_SquooshCodecHost.bundle"
cp -R "$ARM_BUILD/out/Products/Release/SquooshPro_SquooshCodecHost.bundle" "$OUTPUT_DIR/"

xcrun lipo -info "$OUTPUT_DIR/SquooshWebKitCheck"
"$OUTPUT_DIR/SquooshWebKitCheck"

for product in SquooshNativeCodecWorker SquooshNativeCodecCheck; do
  xcrun lipo -create \
    "$ARM_BUILD/out/Products/Release/$product" \
    "$INTEL_BUILD/out/Products/Release/$product" \
    -output "$OUTPUT_DIR/$product"
  xcrun lipo -info "$OUTPUT_DIR/$product"
done
"$OUTPUT_DIR/SquooshNativeCodecCheck"
