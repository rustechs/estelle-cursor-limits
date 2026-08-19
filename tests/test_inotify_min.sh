#!/usr/bin/env bash
# Reject invalid CURSOR_INOTIFY_MIN_WATCHES before sysctl install.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/setup_home.sh
source "${ROOT}/tests/lib/setup_home.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() {
  echo "test_inotify_min: $*" >&2
  exit 1
}

expect_invalid() {
  local value="$1"
  local needle="$2"
  echo "CURSOR_INOTIFY_MIN_WATCHES=${value}" >"${HOME}/.config/cursor-limits/env"
  if bash "${ROOT}/install.sh" >"${TMP}/out.txt" 2>"${TMP}/err.txt"; then
    fail "install should reject CURSOR_INOTIFY_MIN_WATCHES=${value}"
  fi
  grep -q "${needle}" "${TMP}/err.txt" \
    || fail "unexpected error for ${value}: $(cat "${TMP}/err.txt")"
}

estelle_test_setup_home "${TMP}"
export SKIP_INOTIFY_SYSCTL=1
mkdir -p "${HOME}/.config/cursor-limits"

expect_invalid 'abc' 'must be a positive integer'
expect_invalid '0' 'must be greater than zero'
expect_invalid '-1' 'must be a positive integer'
expect_invalid '524288x' 'must be a positive integer'

echo 'CURSOR_INOTIFY_MIN_WATCHES=524288' >"${HOME}/.config/cursor-limits/env"
bash "${ROOT}/install.sh" >/dev/null 2>&1 || fail "valid min watches should install"

echo "inotify min validation test passed"
