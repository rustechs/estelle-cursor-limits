#!/usr/bin/env bash
# Launch Cursor and cap Electron's app-org.chromium.Chromium-PID.scope.
#
# Electron moves the browser process out of cursor-cgwrap's systemd scope into
# an unlimited app.slice scope. Poll for that transient unit and apply the same
# CPU/RAM limits as cursor.slice.
set -euo pipefail

CURSOR_BIN="${CURSOR_BIN:-/usr/share/cursor/cursor}"

: "${CURSOR_CPU_QUOTA:=700%}"
: "${CURSOR_MEMORY_MAX:=18G}"
: "${CURSOR_MEMORY_HIGH:=14G}"
: "${CURSOR_TASKS_MAX:=768}"
: "${CURSOR_ELECTRON_SCOPE_FIX:=1}"
: "${CURSOR_ELECTRON_SCOPE_WAIT_SECS:=5}"

apply_electron_scope_limits() {
  local pid="$1"
  local scope="app-org.chromium.Chromium-${pid}.scope"
  local deadline=$((SECONDS + CURSOR_ELECTRON_SCOPE_WAIT_SECS))

  while (( SECONDS < deadline )); do
    if systemctl --user show -p ActiveState --value "$scope" 2>/dev/null | grep -qx active; then
      if systemctl --user set-property "$scope" \
        "CPUQuota=${CURSOR_CPU_QUOTA}" \
        "MemoryMax=${CURSOR_MEMORY_MAX}" \
        "MemoryHigh=${CURSOR_MEMORY_HIGH}" \
        "TasksMax=${CURSOR_TASKS_MAX}" \
        ManagedOOMMemoryPressure=kill \
        ManagedOOMMemoryPressureLimit=60% \
        >/dev/null; then
        return 0
      fi
      echo "cursor-launch.sh: failed to cap ${scope}; IDE running without limits" >&2
      return 1
    fi
    sleep 0.05
  done
  echo "cursor-launch.sh: timed out waiting for ${scope}; IDE running without limits" >&2
  return 1
}

if [[ "${CURSOR_ELECTRON_SCOPE_FIX}" != "1" ]] || ! command -v systemctl >/dev/null 2>&1; then
  exec "${CURSOR_BIN}" "$@"
fi

"${CURSOR_BIN}" "$@" &
pid=$!

apply_electron_scope_limits "$pid" || true
wait "$pid"
