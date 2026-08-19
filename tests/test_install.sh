#!/usr/bin/env bash
# Install into a temporary HOME and verify artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export HOME="${TMP}/home"
mkdir -p "${HOME}/.local/share/cursor-agent/versions/2099.01.01-test"
cat >"${HOME}/.local/share/cursor-agent/versions/2099.01.01-test/cursor-agent" <<'EOF'
#!/usr/bin/env bash
echo cursor-agent-stub "$@"
EOF
chmod +x "${HOME}/.local/share/cursor-agent/versions/2099.01.01-test/cursor-agent"

export XDG_RUNTIME_DIR="${TMP}/runtime"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

bash "${ROOT}/install.sh" >"${TMP}/install-out.txt" 2>&1 || {
  cat "${TMP}/install-out.txt" >&2
  exit 1
}

test -x "${HOME}/.local/bin/cursor-cgwrap"
test -x "${HOME}/.local/bin/agent"
test -L "${HOME}/.local/bin/agent-raw"
grep -q 'cursor-agent-stub' "${HOME}/.local/bin/agent-raw" || readlink "${HOME}/.local/bin/agent-raw" | grep -q cursor-agent
test -f "${HOME}/.config/systemd/user/cursor.slice"
grep -q 'MemoryMax=18G' "${HOME}/.config/systemd/user/cursor.slice"
test -f "${HOME}/.local/share/applications/cursor.desktop"
grep -F "Exec=${HOME}/.local/bin/cursor-cgwrap cursor --ozone-platform=wayland" \
  "${HOME}/.local/share/applications/cursor.desktop"
test -f "${HOME}/.cursorignore"
grep -q 'worktrees' "${HOME}/.cursorignore"
test -f "${HOME}/.config/cursor-limits/env"

# Second install keeps custom desktop unless forced
echo 'sentinel=desktop' > "${HOME}/.local/share/applications/cursor.desktop"
bash "${ROOT}/install.sh" >/dev/null
grep -q 'sentinel=desktop' "${HOME}/.local/share/applications/cursor.desktop"

FORCE_CURSOR_DESKTOP=1 bash "${ROOT}/install.sh" >/dev/null
if grep -q 'sentinel=desktop' "${HOME}/.local/share/applications/cursor.desktop"; then
  echo "FORCE_CURSOR_DESKTOP did not replace desktop file" >&2
  exit 1
fi

# Migration: existing raw agent before wrapper install (fresh HOME)
MIG_HOME="${TMP}/mig-home"
mkdir -p "${MIG_HOME}/.local/bin"
cat >"${MIG_HOME}/.local/bin/agent" <<'EOF'
#!/usr/bin/env bash
echo legacy-agent "$@"
EOF
chmod +x "${MIG_HOME}/.local/bin/agent"
HOME="${MIG_HOME}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" bash "${ROOT}/install.sh" >/dev/null
test -L "${MIG_HOME}/.local/bin/agent-raw"
readlink -f "${MIG_HOME}/.local/bin/agent-raw" | grep -q '/\.local/bin/agent$' || \
  grep -q 'legacy-agent' "${MIG_HOME}/.local/bin/agent-raw"

echo "install smoke test passed"
