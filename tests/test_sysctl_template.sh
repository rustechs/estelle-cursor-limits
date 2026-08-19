#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${ROOT}/sysctl/99-estelle-cursor-inotify.conf"

test -f "${CONF}"
grep -q '@MAX_USER_WATCHES@' "${CONF}"

rendered="$(
  sed 's/@MAX_USER_WATCHES@/524288/g' "${CONF}"
)"
grep -q '^fs.inotify.max_user_watches=524288$' <<<"${rendered}"

rendered_custom="$(
  sed 's/@MAX_USER_WATCHES@/999999/g' "${CONF}"
)"
grep -q '^fs.inotify.max_user_watches=999999$' <<<"${rendered_custom}"

echo "sysctl template test passed"
