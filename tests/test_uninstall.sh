#!/usr/bin/env bash
# Uninstall into a temporary HOME and verify artifact removal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/setup_home.sh
source "${ROOT}/tests/lib/setup_home.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() {
  echo "test_uninstall: $*" >&2
  exit 1
}

setup_case() {
  estelle_test_setup_home "${TMP}"
  export ESTELLE_SYSCTL_DST="${TMP}/etc/sysctl.d/99-estelle-cursor-inotify.conf"
  export SKIP_INOTIFY_SYSCTL=1
}

setup_case
bash "${ROOT}/install.sh" >/dev/null

test -x "${HOME}/.local/bin/cursor-cgwrap" || fail "precondition: cursor-cgwrap missing"
test -f "${HOME}/.config/systemd/user/cursor.slice" || fail "precondition: cursor.slice missing"

bash "${ROOT}/uninstall.sh" >/dev/null

test ! -e "${HOME}/.local/bin/cursor-cgwrap" || fail "cursor-cgwrap not removed"
test ! -e "${HOME}/.local/bin/agent" || fail "agent wrapper not removed"
test ! -e "${HOME}/.config/systemd/user/cursor.slice" || fail "cursor.slice not removed"
test ! -d "${HOME}/.config/cursor-limits" || fail "cursor-limits config dir not removed"
test -L "${HOME}/.local/bin/agent-raw" || fail "agent-raw should remain"

# Optional removals
setup_case
bash "${ROOT}/install.sh" >/dev/null
echo 'desktop-sentinel' >"${HOME}/.local/share/applications/cursor.desktop"
echo 'ignore-sentinel' >"${HOME}/.cursorignore"
REMOVE_CURSOR_DESKTOP=1 REMOVE_CURSORIGNORE=1 bash "${ROOT}/uninstall.sh" >/dev/null
test ! -f "${HOME}/.local/share/applications/cursor.desktop" || fail "desktop not removed"
test ! -f "${HOME}/.cursorignore" || fail "cursorignore not removed"

# Sysctl install/removal via mock pkexec and test-only sysctl path
setup_case
estelle_test_mock_pkexec "${TMP}"
mkdir -p "$(dirname "${ESTELLE_SYSCTL_DST}")"
unset SKIP_INOTIFY_SYSCTL
mkdir -p "${HOME}/.config/cursor-limits"
echo 'CURSOR_INOTIFY_MIN_WATCHES=999999' >"${HOME}/.config/cursor-limits/env"
rm -f "${ESTELLE_SYSCTL_DST}"
bash "${ROOT}/install.sh" >/dev/null
expected="$(sed 's/@MAX_USER_WATCHES@/999999/g' "${ROOT}/sysctl/99-estelle-cursor-inotify.conf")"
actual="$(cat "${ESTELLE_SYSCTL_DST}")"
[[ "${expected}" == "${actual}" ]] \
  || fail "dynamic sysctl drop-in not rendered from CURSOR_INOTIFY_MIN_WATCHES"

REMOVE_INOTIFY_SYSCTL=1 bash "${ROOT}/uninstall.sh" >/dev/null
test ! -f "${ESTELLE_SYSCTL_DST}" || fail "sysctl drop-in not removed"

echo "uninstall smoke test passed"
