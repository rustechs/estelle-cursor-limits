#!/usr/bin/env bash
# cursor-launch.sh applies limits to Electron's transient Chromium scope.
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=lib/setup_home.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/setup_home.sh"
estelle_test_begin "test_cursor_launch"

estelle_test_setup_home "${TMP}"
mkdir -p "${HOME}/.local/bin"
install -m 0755 "${ROOT}/bin/cursor-launch.sh" "${HOME}/.local/bin/cursor-launch.sh"

mock_bin="${TMP}/mock-bin"
mkdir -p "${mock_bin}"
cat >"${mock_bin}/cursor-stub" <<'EOF'
#!/usr/bin/env bash
echo "$$" >"${CURSOR_STUB_PID_FILE:?}"
sleep 2
EOF
chmod +x "${mock_bin}/cursor-stub"

cat >"${mock_bin}/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="${SYSTEMCTL_LOG:?}"
cmd="$1"; shift
case "${cmd}" in
  --user)
    cmd="$1"; shift
    case "${cmd}" in
      show)
        unit=""
        prop=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -p) prop="$2"; shift 2 ;;
            --value) shift; unit="${1:-}"; shift || true; break ;;
            *) unit="$1"; shift ;;
          esac
        done
        if [[ "${prop}" == "ActiveState" && -f "${SYSTEMCTL_ACTIVE_FILE:-}" ]]; then
          cat "${SYSTEMCTL_ACTIVE_FILE}"
        else
          echo "unknown"
        fi
        ;;
      set-property)
        unit="$1"; shift
        {
          echo "set-property ${unit}"
          printf '%s\n' "$@"
        } >>"${log}"
        ;;
      *)
        echo "unexpected systemctl: ${cmd}" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unexpected systemctl top-level: ${cmd}" >&2
    exit 1
    ;;
esac
EOF
chmod +x "${mock_bin}/systemctl"

export PATH="${mock_bin}:${PATH}"
export CURSOR_BIN="${mock_bin}/cursor-stub"
export CURSOR_STUB_PID_FILE="${TMP}/cursor.pid"
export SYSTEMCTL_LOG="${TMP}/systemctl.log"
export SYSTEMCTL_ACTIVE_FILE="${TMP}/scope.state"
export CURSOR_ELECTRON_SCOPE_WAIT_SECS=2

"${HOME}/.local/bin/cursor-launch.sh" --help &
launch_pid=$!
sleep 0.2
stub_pid="$(cat "${CURSOR_STUB_PID_FILE}")"
echo active >"${SYSTEMCTL_ACTIVE_FILE}"
wait "${launch_pid}"

grep -q "set-property app-org.chromium.Chromium-${stub_pid}.scope" "${SYSTEMCTL_LOG}" \
  || fail "expected set-property for electron scope"
grep -q 'MemoryMax=18G' "${SYSTEMCTL_LOG}" || fail "expected MemoryMax=18G"
grep -q 'CPUQuota=700%' "${SYSTEMCTL_LOG}" || fail "expected CPUQuota=700%"

echo "cursor-launch test passed"
