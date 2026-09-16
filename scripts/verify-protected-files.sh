#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
EXPECTED="$PROJECT_ROOT/docs/protected-files.sha256"
ACTUAL="$(mktemp -t squoosh-pro-protected.XXXXXX)"
trap 'rm -f "$ACTUAL"' EXIT

while IFS= read -r line; do
  hash="${line%%  *}"
  relative="${line#*  }"
  file="$WORKSPACE_ROOT/$relative"
  [[ -f "$file" ]] || { echo "Protected file missing: $relative" >&2; exit 1; }
  current="$(shasum -a 256 "$file" | awk '{print $1}')"
  printf '%s  %s\n' "$current" "$relative" >> "$ACTUAL"
  [[ "$current" == "$hash" ]] || { echo "Protected file changed: $relative" >&2; exit 1; }
done < "$EXPECTED"

diff -u "$EXPECTED" "$ACTUAL"
echo "Protected image hashes are unchanged."
