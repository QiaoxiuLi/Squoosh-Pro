#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)/squoosh-source"
RESOURCE_ROOT="$PROJECT_ROOT/Sources/SquooshCodecHost/Resources/CodecWorker/codecs"

if [[ ! -d "$UPSTREAM_ROOT/.git" ]]; then
  echo "Expected read-only Squoosh checkout at $UPSTREAM_ROOT" >&2
  exit 1
fi

EXPECTED_COMMIT="e8d35e0fb66eb16eff6fe8fc773eabcbb7128de3"
ACTUAL_COMMIT="$(git -C "$UPSTREAM_ROOT" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$EXPECTED_COMMIT" ]] || { echo "Unexpected Squoosh commit: $ACTUAL_COMMIT" >&2; exit 1; }

compare_asset() {
  local source_path="$1"
  local output_name="$2"
  cmp "$UPSTREAM_ROOT/$source_path" "$RESOURCE_ROOT/$output_name" || {
    echo "Vendored codec differs from pinned upstream: $output_name" >&2
    exit 1
  }
}

compare_asset "codecs/mozjpeg/enc/mozjpeg_enc.js" "mozjpeg_enc.js"
compare_asset "codecs/mozjpeg/enc/mozjpeg_enc.wasm" "mozjpeg_enc.wasm"
compare_asset "codecs/webp/enc/webp_enc.js" "webp_enc.js"
compare_asset "codecs/webp/enc/webp_enc.wasm" "webp_enc.wasm"
compare_asset "codecs/avif/enc/avif_enc.js" "avif_enc.js"
compare_asset "codecs/avif/enc/avif_enc.wasm" "avif_enc.wasm"
compare_asset "codecs/oxipng/pkg/squoosh_oxipng.js" "squoosh_oxipng.js"
compare_asset "codecs/oxipng/pkg/squoosh_oxipng_bg.wasm" "squoosh_oxipng_bg.wasm"

(cd "$PROJECT_ROOT/shared/codec-worker" && npm test)
echo "Pinned codec assets and four-format smoke tests passed."
