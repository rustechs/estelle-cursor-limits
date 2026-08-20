#!/usr/bin/env bash
# Install Cursor cgroup limits into ~/.local/bin and user systemd.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
APPS_DIR="${HOME}/.local/share/applications"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-limits"
ENV_FILE="${CONF_DIR}/env"
DESKTOP_DST="${APPS_DIR}/cursor.desktop"
URL_HANDLER_DST="${APPS_DIR}/cursor-url-handler.desktop"
CURSORIGNORE_DST="${HOME}/.cursorignore"

die() {
  echo "install.sh: $*" >&2
  exit 1
}

load_extra_args() {
  local defaults extra
  defaults="$(grep '^CURSOR_DESKTOP_EXTRA_ARGS=' "${ROOT}/etc/cursor-limits.env" 2>/dev/null | cut -d= -f2- || true)"
  extra="${defaults}"
  if [[ -f "${ENV_FILE}" ]]; then
    extra="$(grep '^CURSOR_DESKTOP_EXTRA_ARGS=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || true)"
    extra="${extra:-${defaults}}"
  fi
  printf '%s' "${extra}"
}

resolve_agent_raw() {
  local candidate versions_dir latest

  if [[ -L "${BIN_DIR}/agent-raw" ]]; then
    readlink -f "${BIN_DIR}/agent-raw"
    return 0
  fi

  if [[ -x "${BIN_DIR}/agent" ]] && ! grep -q 'cursor-cgwrap' "${BIN_DIR}/agent" 2>/dev/null; then
    readlink -f "${BIN_DIR}/agent"
    return 0
  fi

  versions_dir="${HOME}/.local/share/cursor-agent/versions"
  if [[ -d "${versions_dir}" ]]; then
    latest="$(
      find "${versions_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null \
        | sort -V | tail -1 || true
    )"
    if [[ -n "${latest}" && -x "${versions_dir}/${latest}/cursor-agent" ]]; then
      echo "${versions_dir}/${latest}/cursor-agent"
      return 0
    fi
  fi

  return 1
}

render_desktop() {
  local extra="$1"
  sed \
    -e "s|@HOME@|${HOME}|g" \
    -e "s|@EXTRA_ARGS@|${extra}|g" \
    "${ROOT}/applications/cursor.desktop"
}

read_inotify_min() {
  local from_env from_file
  from_file="$(grep '^CURSOR_INOTIFY_MIN_WATCHES=' "${ROOT}/etc/cursor-limits.env" 2>/dev/null | cut -d= -f2- || true)"
  from_env=""
  if [[ -f "${ENV_FILE}" ]]; then
    from_env="$(grep '^CURSOR_INOTIFY_MIN_WATCHES=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || true)"
  fi
  echo "${from_env:-${from_file:-524288}}"
}

validate_inotify_min() {
  local value="$1"
  [[ "${value}" =~ ^[0-9]+$ ]] || die "CURSOR_INOTIFY_MIN_WATCHES must be a positive integer (got: ${value})"
  [[ "${value}" -gt 0 ]] || die "CURSOR_INOTIFY_MIN_WATCHES must be greater than zero (got: ${value})"
}

inotify_sysctl_dst() {
  echo "${ESTELLE_SYSCTL_DST:-/etc/sysctl.d/99-estelle-cursor-inotify.conf}"
}

render_inotify_sysctl() {
  local min_watches="$1"
  local template="${ROOT}/sysctl/99-estelle-cursor-inotify.conf"
  if [[ ! -f "${template}" ]]; then
    die "missing sysctl template: ${template}"
  fi
  sed "s/@MAX_USER_WATCHES@/${min_watches}/g" "${template}"
}

read_inotify_max_from_dropin() {
  local dst="$1"
  local line value
  line="$(grep -E '^[[:space:]]*fs\.inotify\.max_user_watches=' "${dst}" 2>/dev/null | tail -1 || true)"
  value="${line#*=}"
  value="${value//[[:space:]]/}"
  echo "${value}"
}

install_rendered_inotify_sysctl() {
  local dst="$1" rendered_tmp="$2"
  pkexec bash -c "install -d \"$(dirname "${dst}")\" && install -m 0644 \"${rendered_tmp}\" \"${dst}\" && sysctl --system >/dev/null"
}

maybe_install_inotify_sysctl() {
  local min_watches current dst rendered_tmp dst_value
  dst="$(inotify_sysctl_dst)"
  min_watches="$(read_inotify_min)"
  validate_inotify_min "${min_watches}"
  current="$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo 0)"
  rendered_tmp="$(mktemp)"
  render_inotify_sysctl "${min_watches}" >"${rendered_tmp}"
  trap 'rm -f "${rendered_tmp}"' RETURN

  if [[ "${SKIP_INOTIFY_SYSCTL:-}" == "1" ]]; then
    if [[ "${current}" -lt "${min_watches}" ]]; then
      echo "install.sh: note: inotify max_user_watches=${current} < ${min_watches} (SKIP_INOTIFY_SYSCTL=1)." >&2
    fi
    return 0
  fi

  if [[ -f "${dst}" ]] && cmp -s "${rendered_tmp}" "${dst}"; then
    if [[ "${current}" -lt "${min_watches}" ]]; then
      echo "install.sh: applying existing ${dst} (current max_user_watches=${current})..." >&2
      pkexec sysctl --system >/dev/null
    fi
    return 0
  fi

  if [[ -f "${dst}" ]] && ! cmp -s "${rendered_tmp}" "${dst}"; then
    dst_value="$(read_inotify_max_from_dropin "${dst}")"
    if [[ -n "${dst_value}" && "${dst_value}" =~ ^[0-9]+$ && "${dst_value}" -le "${min_watches}" ]]; then
      if [[ "${dst_value}" == "${min_watches}" ]]; then
        echo "install.sh: upgrading ${dst} to current template (max_user_watches=${min_watches})..." >&2
      else
        echo "install.sh: raising ${dst} to max_user_watches=${min_watches}..." >&2
      fi
      install_rendered_inotify_sysctl "${dst}" "${rendered_tmp}"
      return 0
    fi
    echo "install.sh: note: custom ${dst} present; applying sysctl --system without overwriting." >&2
    pkexec sysctl --system >/dev/null
    current="$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo 0)"
    if [[ "${current}" -ge "${min_watches}" ]]; then
      return 0
    fi
    echo "install.sh: warning: max_user_watches=${current} still below ${min_watches}; edit ${dst} manually or remove it and re-run install." >&2
    return 0
  fi

  if [[ "${current}" -ge "${min_watches}" ]]; then
    return 0
  fi

  echo "Installing ${dst} (max_user_watches ${current} -> ${min_watches})..."
  echo "  Approve the PolicyKit prompt for estelle-cursor-limits sysctl."
  install_rendered_inotify_sysctl "${dst}" "${rendered_tmp}"
}

install -d "${BIN_DIR}" "${UNIT_DIR}" "${APPS_DIR}" "${CONF_DIR}"

if candidate="$(resolve_agent_raw)"; then
  ln -sfn "${candidate}" "${BIN_DIR}/agent-raw"
else
  echo "install.sh: warning: cursor-agent not found; agent-raw not linked." >&2
  echo "  Install Cursor CLI, then re-run install.sh." >&2
fi

install -m 0755 "${ROOT}/bin/cursor-cgwrap" "${BIN_DIR}/cursor-cgwrap"
install -m 0755 "${ROOT}/bin/cursor-launch.sh" "${BIN_DIR}/cursor-launch.sh"
install -m 0755 "${ROOT}/bin/agent" "${BIN_DIR}/agent"
install -m 0644 "${ROOT}/systemd/cursor.slice" "${UNIT_DIR}/cursor.slice"

if [[ ! -f "${ENV_FILE}" ]]; then
  install -m 0644 "${ROOT}/etc/cursor-limits.env" "${ENV_FILE}"
fi

EXTRA_ARGS="$(load_extra_args)"
if [[ ! -f "${DESKTOP_DST}" || "${FORCE_CURSOR_DESKTOP:-}" == "1" ]]; then
  render_desktop "${EXTRA_ARGS}" >"${DESKTOP_DST}"
  chmod 0644 "${DESKTOP_DST}"
else
  echo "Keeping existing ${DESKTOP_DST} (set FORCE_CURSOR_DESKTOP=1 to replace)."
fi

if [[ ! -f "${URL_HANDLER_DST}" || "${FORCE_CURSOR_DESKTOP:-}" == "1" ]]; then
  sed \
    -e "s|@HOME@|${HOME}|g" \
    -e "s|@EXTRA_ARGS@|${EXTRA_ARGS}|g" \
    "${ROOT}/applications/cursor-url-handler.desktop" >"${URL_HANDLER_DST}"
  chmod 0644 "${URL_HANDLER_DST}"
else
  echo "Keeping existing ${URL_HANDLER_DST} (set FORCE_CURSOR_DESKTOP=1 to replace)."
fi

if [[ ! -f "${CURSORIGNORE_DST}" || "${FORCE_CURSORIGNORE:-}" == "1" ]]; then
  install -m 0644 "${ROOT}/etc/cursorignore.example" "${CURSORIGNORE_DST}"
else
  echo "Keeping existing ${CURSORIGNORE_DST} (set FORCE_CURSORIGNORE=1 to replace)."
fi

if systemctl --user daemon-reload >/dev/null 2>&1; then
  :
else
  echo "install.sh: warning: systemctl --user unavailable; skipped daemon-reload." >&2
fi

maybe_install_inotify_sysctl

echo "Installed estelle-cursor-limits."
echo "  Launch IDE from app menu or: cursor-cgwrap cursor"
echo "  Agent (capped): agent"
echo "  Agent (raw):    agent-raw   (alias: agent-unlimited — see contrib/bashrc.snippet)"
echo "  Monitor:        systemctl --user status cursor.slice"
current="$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo '?')"
inotify_dst="$(inotify_sysctl_dst)"
if [[ -f "${inotify_dst}" ]]; then
  echo "  inotify watches: ${current} (drop-in: ${inotify_dst})"
else
  echo "  inotify watches: ${current}"
fi
