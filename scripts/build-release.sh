#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${SQUOOSH_VERSION:-0.1.0}"
BUILD_NUMBER="${SQUOOSH_BUILD_NUMBER:-1}"
BUILD_ROOT="$PROJECT_ROOT/.build/release-app"
ARTIFACT_DIR="$PROJECT_ROOT/Artifacts"
APP_PATH="$ARTIFACT_DIR/Squoosh Pro.app"
ZIP_NAME="Squoosh-Pro-$VERSION-macOS-universal.zip"
ZIP_PATH="$ARTIFACT_DIR/$ZIP_NAME"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode must be active before building a macOS release." >&2
  exit 2
fi

for arch in arm64 x86_64; do
  scratch="$BUILD_ROOT/$arch"
  swift build --package-path "$PROJECT_ROOT" --scratch-path "$scratch" \
    --configuration release --arch "$arch" --product SquooshPro
  swift build --package-path "$PROJECT_ROOT" --scratch-path "$scratch" \
    --configuration release --arch "$arch" --product SquooshNativeCodecWorker
done

ARM_PRODUCTS="$BUILD_ROOT/arm64/out/Products/Release"
INTEL_PRODUCTS="$BUILD_ROOT/x86_64/out/Products/Release"

required=(
  "$ARM_PRODUCTS/SquooshPro"
  "$INTEL_PRODUCTS/SquooshPro"
  "$ARM_PRODUCTS/SquooshNativeCodecWorker"
  "$INTEL_PRODUCTS/SquooshNativeCodecWorker"
  "$ARM_PRODUCTS/SquooshPro_SquooshPro.bundle"
  "$ARM_PRODUCTS/SquooshPro_SquooshCodecHost.bundle"
)
for path in "${required[@]}"; do
  [[ -e "$path" ]] || { echo "Missing release input: $path" >&2; exit 1; }
done

case "$APP_PATH" in
  "$PROJECT_ROOT"/Artifacts/*) ;;
  *) echo "Refusing to replace an app outside project Artifacts." >&2; exit 1 ;;
esac

rm -rf "$APP_PATH"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Helpers"

xcrun lipo -create "$ARM_PRODUCTS/SquooshPro" "$INTEL_PRODUCTS/SquooshPro" \
  -output "$APP_PATH/Contents/MacOS/SquooshPro"
xcrun lipo -create "$ARM_PRODUCTS/SquooshNativeCodecWorker" "$INTEL_PRODUCTS/SquooshNativeCodecWorker" \
  -output "$APP_PATH/Contents/Helpers/SquooshNativeCodecWorker"
cp -R "$ARM_PRODUCTS/SquooshPro_SquooshPro.bundle" "$APP_PATH/Contents/Resources/"
cp -R "$ARM_PRODUCTS/SquooshPro_SquooshCodecHost.bundle" "$APP_PATH/Contents/Resources/"

PLIST="$APP_PATH/Contents/Info.plist"
plutil -create xml1 "$PLIST"
plutil -insert CFBundleName -string "Squoosh Pro" "$PLIST"
plutil -insert CFBundleDisplayName -string "Squoosh Pro" "$PLIST"
plutil -insert CFBundleIdentifier -string "com.qiaoxiuli.squoosh-pro" "$PLIST"
plutil -insert CFBundleExecutable -string "SquooshPro" "$PLIST"
plutil -insert CFBundlePackageType -string "APPL" "$PLIST"
plutil -insert CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$PLIST"
plutil -insert LSApplicationCategoryType -string "public.app-category.graphics-design" "$PLIST"
plutil -insert LSMinimumSystemVersion -string "13.0" "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"

codesign --force --sign - --timestamp=none --options runtime \
  --entitlements "$PROJECT_ROOT/Config/SquooshProHelper.entitlements" \
  "$APP_PATH/Contents/Helpers/SquooshNativeCodecWorker"
codesign --force --sign - --timestamp=none --options runtime \
  --entitlements "$PROJECT_ROOT/Config/SquooshPro.entitlements" "$APP_PATH"

xcrun lipo -info "$APP_PATH/Contents/MacOS/SquooshPro"
xcrun lipo -info "$APP_PATH/Contents/Helpers/SquooshNativeCodecWorker"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$ARTIFACT_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
)

echo "Release app: $APP_PATH"
echo "Release archive: $ZIP_PATH"
echo "Checksum: $ZIP_PATH.sha256"
echo "Signing: ad-hoc only (not Developer ID signed or notarized)"
