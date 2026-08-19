#!/usr/bin/env bash
# Remove estelle-cursor-limits user artifacts.
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
APPS_DIR="${HOME}/.local/share/applications"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-limits"

rm -f "${BIN_DIR}/cursor-cgwrap" "${BIN_DIR}/agent"
# Leave agent-raw pointing at cursor-agent — other tools may still use it.

if [[ "${REMOVE_CURSOR_DESKTOP:-}" == "1" ]]; then
  rm -f "${APPS_DIR}/cursor.desktop"
fi

if [[ "${REMOVE_CURSORIGNORE:-}" == "1" ]]; then
  rm -f "${HOME}/.cursorignore"
fi

rm -f "${UNIT_DIR}/cursor.slice"
rm -rf "${CONF_DIR}"

if [[ "${REMOVE_INOTIFY_SYSCTL:-}" == "1" && -f /etc/sysctl.d/99-estelle-cursor-inotify.conf ]]; then
  echo "Removing /etc/sysctl.d/99-estelle-cursor-inotify.conf ..."
  pkexec bash -c "rm -f /etc/sysctl.d/99-estelle-cursor-inotify.conf && sysctl --system >/dev/null"
fi

systemctl --user daemon-reload 2>/dev/null || true

echo "Uninstalled estelle-cursor-limits (agent-raw left in place)."
