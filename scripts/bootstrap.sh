#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v swift >/dev/null || { echo "Swift is required." >&2; exit 1; }
command -v node >/dev/null || { echo "Node.js is required for codec contract tests." >&2; exit 1; }
command -v npm >/dev/null || { echo "npm is required for codec contract tests." >&2; exit 1; }

test -f "$PROJECT_ROOT/third_party/UPSTREAM_COMMIT"
test -f "$PROJECT_ROOT/Sources/SquooshCodecHost/Resources/CodecWorker/codecs/mozjpeg_enc.wasm"
test -f "$PROJECT_ROOT/Sources/SquooshCodecHost/Resources/CodecWorker/codecs/oxipng_bg.wasm" || test -f "$PROJECT_ROOT/Sources/SquooshCodecHost/Resources/CodecWorker/codecs/squoosh_oxipng_bg.wasm"

echo "Project prerequisites are present. No system software was installed."
