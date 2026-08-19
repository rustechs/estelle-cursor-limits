#!/usr/bin/env bash
# cursor-cgwrap falls back when systemd-run is unavailable.
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
estelle_test_begin "test_cgwrap_fallback"

export HOME="${TMP}/home"
mkdir -p "${HOME}/.local/bin"
SHIM="${TMP}/shim"
mkdir -p "${SHIM}"
for cmd in bash env; do
  ln -sf "$(command -v "${cmd}")" "${SHIM}/${cmd}"
done

install -m 0755 "${ROOT}/bin/cursor-cgwrap" "${HOME}/.local/bin/cursor-cgwrap"

cat >"${HOME}/.local/bin/agent-raw" <<'EOF'
#!/usr/bin/env bash
echo agent-raw-stub "$@"
EOF
chmod +x "${HOME}/.local/bin/agent-raw"

# PATH with bash/env but without systemd-run (/bin and /usr/bin both ship it).
out="$(env PATH="${SHIM}:${HOME}/.local/bin" AGENT_BIN="${HOME}/.local/bin/agent-raw" \
  "${HOME}/.local/bin/cursor-cgwrap" agent hello 2>&1)"
echo "${out}" | grep -q 'cursor-cgwrap: systemd-run not found' \
  || fail "expected systemd-run not found message"
echo "${out}" | grep -q 'agent-raw-stub hello' \
  || fail "expected agent-raw-stub hello output"

echo "cgwrap fallback test passed"
