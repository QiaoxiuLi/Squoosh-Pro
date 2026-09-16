#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  README.md LICENSE Package.swift
  docs/ARCHITECTURE.md docs/DATA_SAFETY.md docs/PRESET_SCHEMA.md docs/TESTING.md docs/RELEASE.md docs/WINDOWS_FUTURE.md
  shared/contracts/preset.schema.json shared/contracts/codec-request.schema.json shared/contracts/codec-response.schema.json shared/contracts/job-report.schema.json
  third_party/UPSTREAM_COMMIT third_party/THIRD_PARTY_NOTICES.md
)
for path in "${required[@]}"; do [[ -s "$PROJECT_ROOT/$path" ]] || { echo "Missing required file: $path" >&2; exit 1; }; done

if find "$PROJECT_ROOT" -path "$PROJECT_ROOT/.git" -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \) -print | grep -q .; then
  echo "Unexpected photographic fixture found in the repository." >&2
  exit 1
fi

if rg -n --hidden --glob '!.git/**' --glob '!scripts/verify-release.sh' '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_)' "$PROJECT_ROOT"; then
  echo "Potential credential material found." >&2
  exit 1
fi

"$PROJECT_ROOT/scripts/verify-protected-files.sh"
echo "Release source checks passed. Publishing and distribution signing are separate authorized steps."
