#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed; skipping" >&2
  exit 0
fi

mapfile -t scripts < <(
  find "${ROOT}" -maxdepth 3 -type f \( -name '*.sh' -o -path '*/bin/*' \) \
    ! -path '*/tests/test_*.sh' -executable | sort
)
mapfile -t test_scripts < <(find "${ROOT}/tests" -maxdepth 2 -type f -name '*.sh' -executable | sort)
mapfile -t test_libs < <(find "${ROOT}/tests/lib" -maxdepth 1 -type f -name '*.sh' | sort)
shellcheck -x -P "${ROOT}/tests" "${scripts[@]}" "${test_libs[@]}" "${test_scripts[@]}"
echo "shellcheck passed"
