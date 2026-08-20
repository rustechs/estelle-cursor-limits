#!/usr/bin/env bash
# Remove estelle-cursor-limits user artifacts.
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
APPS_DIR="${HOME}/.local/share/applications"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-limits"
SYSCTL_DST="${ESTELLE_SYSCTL_DST:-/etc/sysctl.d/99-estelle-cursor-inotify.conf}"

rm -f "${BIN_DIR}/cursor-cgwrap" "${BIN_DIR}/cursor-launch.sh" "${BIN_DIR}/agent"
# Leave agent-raw pointing at cursor-agent — other tools may still use it.

if [[ "${REMOVE_CURSOR_DESKTOP:-}" == "1" ]]; then
  rm -f "${APPS_DIR}/cursor.desktop" "${APPS_DIR}/cursor-url-handler.desktop"
fi

if [[ "${REMOVE_CURSORIGNORE:-}" == "1" ]]; then
  rm -f "${HOME}/.cursorignore"
fi

rm -f "${UNIT_DIR}/cursor.slice"
rm -rf "${CONF_DIR}"

if [[ "${REMOVE_INOTIFY_SYSCTL:-}" == "1" && -f "${SYSCTL_DST}" ]]; then
  echo "Removing ${SYSCTL_DST} ..."
  pkexec bash -c "rm -f \"${SYSCTL_DST}\" && sysctl --system >/dev/null"
fi

systemctl --user daemon-reload 2>/dev/null || true

echo "Uninstalled estelle-cursor-limits (agent-raw left in place)."
