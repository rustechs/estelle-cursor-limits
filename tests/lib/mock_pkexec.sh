#!/usr/bin/env bash
# Minimal pkexec stub for CI: run elevated commands without PolicyKit.
set -euo pipefail

if [[ $# -ge 3 && "$1" == "bash" && "$2" == "-c" ]]; then
  bash -c "$3"
  exit $?
fi

if [[ $# -ge 1 && "$1" == "sysctl" ]]; then
  "$@" >/dev/null 2>&1 || true
  exit 0
fi

exec "$@"
