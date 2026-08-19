#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed; skipping" >&2
  exit 0
fi

mapfile -t scripts < <(find "${ROOT}" -maxdepth 2 -type f \( -name '*.sh' -o -path '*/bin/*' \) ! -path '*/tests/*' -executable | sort)
shellcheck "${scripts[@]}"
echo "shellcheck passed"
