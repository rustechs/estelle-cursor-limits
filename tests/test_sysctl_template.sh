#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${ROOT}/sysctl/99-estelle-cursor-inotify.conf"

test -f "${CONF}"
grep -q '^fs.inotify.max_user_watches=524288$' "${CONF}"
echo "sysctl template test passed"
