#!/usr/bin/env bash
# Upgrade legacy single-line sysctl drop-ins when the value matches config.
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=lib/setup_home.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/setup_home.sh"
estelle_test_begin "test_sysctl_upgrade"

estelle_test_setup_home "${TMP}"
estelle_test_mock_pkexec "${TMP}"
export ESTELLE_SYSCTL_DST="${TMP}/etc/sysctl.d/99-estelle-cursor-inotify.conf"
mkdir -p "$(dirname "${ESTELLE_SYSCTL_DST}")"
mkdir -p "${HOME}/.config/cursor-limits"
echo 'CURSOR_INOTIFY_MIN_WATCHES=524288' >"${HOME}/.config/cursor-limits/env"
echo 'fs.inotify.max_user_watches=524288' >"${ESTELLE_SYSCTL_DST}"

bash "${ROOT}/install.sh" >/dev/null

expected="$(sed 's/@MAX_USER_WATCHES@/524288/g' "${ROOT}/sysctl/99-estelle-cursor-inotify.conf")"
actual="$(cat "${ESTELLE_SYSCTL_DST}")"
[[ "${expected}" == "${actual}" ]] || fail "legacy drop-in was not upgraded to current template"

# Custom limit must not be rewritten when it exceeds config.
echo 'fs.inotify.max_user_watches=999999' >"${ESTELLE_SYSCTL_DST}"
echo 'CURSOR_INOTIFY_MIN_WATCHES=524288' >"${HOME}/.config/cursor-limits/env"
bash "${ROOT}/install.sh" >/dev/null
actual="$(cat "${ESTELLE_SYSCTL_DST}")"
[[ "${actual}" == $'fs.inotify.max_user_watches=999999' ]] \
  || fail "custom drop-in with higher limit was overwritten"

# Raising config should upgrade a lower legacy drop-in.
echo 'fs.inotify.max_user_watches=524288' >"${ESTELLE_SYSCTL_DST}"
echo 'CURSOR_INOTIFY_MIN_WATCHES=999999' >"${HOME}/.config/cursor-limits/env"
bash "${ROOT}/install.sh" >/dev/null
expected_high="$(sed 's/@MAX_USER_WATCHES@/999999/g' "${ROOT}/sysctl/99-estelle-cursor-inotify.conf")"
actual="$(cat "${ESTELLE_SYSCTL_DST}")"
[[ "${expected_high}" == "${actual}" ]] || fail "lower legacy drop-in was not raised"

echo "sysctl upgrade test passed"
