#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$PROJECT_ROOT/scripts/build-codecs.sh"
(cd "$PROJECT_ROOT" && SQUOOSH_RUN_48MP_AVIF=1 swift run SquooshCoreCheck)
(cd "$PROJECT_ROOT" && swift run SquooshWebKitCheck)
(cd "$PROJECT_ROOT" && swift build --product SquooshNativeCodecWorker && swift run SquooshNativeCodecCheck)
(cd "$PROJECT_ROOT" && while IFS= read -r source; do swiftc -frontend -parse "$source"; done < <(find Sources -name '*.swift' -type f | sort))
(cd "$PROJECT_ROOT" && swiftc -typecheck -parse-as-library -target arm64-apple-macos13.0 -sdk "$(xcrun --show-sdk-path)" -I .build/out/Products/Debug Sources/SquooshPro/AppModel.swift)

if xcodebuild -version >/dev/null 2>&1; then
  (cd "$PROJECT_ROOT" && swift test)
else
  echo "SKIP XCTest/XCUITest: full Xcode is not installed; SquooshCoreCheck covered the executable core assertions." >&2
fi

"$PROJECT_ROOT/scripts/verify-protected-files.sh"
echo "All checks available in the current environment passed."
