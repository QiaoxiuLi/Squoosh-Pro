#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/Artifacts/Squoosh Pro.app"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required to compile the stateful SwiftUI target. The active developer directory is Command Line Tools only." >&2
  exit 2
fi

cd "$PROJECT_ROOT"
swift build -c debug --product SquooshPro
swift build -c debug --product SquooshNativeCodecWorker
BIN_PATH="$(swift build -c debug --show-bin-path)"

case "$APP_PATH" in
  "$PROJECT_ROOT"/Artifacts/*) ;;
  *) echo "Refusing to replace an app outside project Artifacts." >&2; exit 1 ;;
esac

if [[ -e "$APP_PATH" ]]; then rm -rf "$APP_PATH"; fi
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Helpers"
cp "$BIN_PATH/SquooshPro" "$APP_PATH/Contents/MacOS/SquooshPro"
cp "$BIN_PATH/SquooshNativeCodecWorker" "$APP_PATH/Contents/Helpers/SquooshNativeCodecWorker"
if [[ -d "$BIN_PATH/SquooshPro_SquooshPro.bundle" ]]; then cp -R "$BIN_PATH/SquooshPro_SquooshPro.bundle" "$APP_PATH/Contents/Resources/"; fi
if [[ -d "$BIN_PATH/SquooshPro_SquooshCodecHost.bundle" ]]; then cp -R "$BIN_PATH/SquooshPro_SquooshCodecHost.bundle" "$APP_PATH/Contents/Resources/"; fi

PLIST="$APP_PATH/Contents/Info.plist"
plutil -create xml1 "$PLIST"
plutil -insert CFBundleName -string "Squoosh Pro" "$PLIST"
plutil -insert CFBundleDisplayName -string "Squoosh Pro" "$PLIST"
plutil -insert CFBundleIdentifier -string "com.qiaoxiuli.squoosh-pro" "$PLIST"
plutil -insert CFBundleExecutable -string "SquooshPro" "$PLIST"
plutil -insert CFBundlePackageType -string "APPL" "$PLIST"
plutil -insert CFBundleShortVersionString -string "0.1.0" "$PLIST"
plutil -insert CFBundleVersion -string "1" "$PLIST"
plutil -insert LSMinimumSystemVersion -string "13.0" "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"
codesign --force --sign - --entitlements "$PROJECT_ROOT/Config/SquooshProHelper.entitlements" "$APP_PATH/Contents/Helpers/SquooshNativeCodecWorker"
codesign --force --sign - --entitlements "$PROJECT_ROOT/Config/SquooshPro.entitlements" "$APP_PATH"

echo "Development app: $APP_PATH"
