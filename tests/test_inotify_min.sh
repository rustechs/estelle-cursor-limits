#!/usr/bin/env bash
# Reject invalid CURSOR_INOTIFY_MIN_WATCHES before sysctl install.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() {
  echo "test_inotify_min: $*" >&2
  exit 1
}

setup_home() {
  export HOME="${TMP}/home"
  export XDG_CONFIG_HOME="${HOME}/.config"
  export XDG_DATA_HOME="${HOME}/.local/share"
  export XDG_RUNTIME_DIR="${TMP}/runtime"
  export SKIP_INOTIFY_SYSCTL=1
  mkdir -p "${HOME}/.local/share/cursor-agent/versions/2099.01.01-test"
  cat >"${HOME}/.local/share/cursor-agent/versions/2099.01.01-test/cursor-agent" <<'EOF'
#!/usr/bin/env bash
echo cursor-agent-stub "$@"
EOF
  chmod +x "${HOME}/.local/share/cursor-agent/versions/2099.01.01-test/cursor-agent"
  mkdir -p "${XDG_RUNTIME_DIR}"
  chmod 700 "${XDG_RUNTIME_DIR}"
  mkdir -p "${HOME}/.config/cursor-limits"
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

setup_home
expect_invalid 'abc' 'must be a positive integer'
expect_invalid '0' 'must be greater than zero'
expect_invalid '-1' 'must be a positive integer'
expect_invalid '524288x' 'must be a positive integer'

echo 'CURSOR_INOTIFY_MIN_WATCHES=524288' >"${HOME}/.config/cursor-limits/env"
bash "${ROOT}/install.sh" >/dev/null 2>&1 || fail "valid min watches should install"

echo "inotify min validation test passed"
