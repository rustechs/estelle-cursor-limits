#!/usr/bin/env bash
# Install into a temporary HOME and verify artifacts.
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# shellcheck source=lib/setup_home.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/setup_home.sh"
estelle_test_begin "test_install"

estelle_test_setup_home "${TMP}"
export SKIP_INOTIFY_SYSCTL=1

bash "${ROOT}/install.sh" >"${TMP}/install-out.txt" 2>&1 || {
  cat "${TMP}/install-out.txt" >&2
  fail "install.sh exited non-zero"
}

test -x "${HOME}/.local/bin/cursor-cgwrap" || fail "cursor-cgwrap missing"
test -x "${HOME}/.local/bin/cursor-launch.sh" || fail "cursor-launch.sh missing"
test -x "${HOME}/.local/bin/agent" || fail "agent wrapper missing"
test -L "${HOME}/.local/bin/agent-raw" || fail "agent-raw symlink missing"
grep -q 'cursor-agent-stub' "${HOME}/.local/bin/agent-raw" || readlink "${HOME}/.local/bin/agent-raw" | grep -q cursor-agent
test -f "${HOME}/.config/systemd/user/cursor.slice"
grep -q 'MemoryMax=18G' "${HOME}/.config/systemd/user/cursor.slice"
test -f "${HOME}/.local/share/applications/cursor.desktop"
grep -F "Exec=${HOME}/.local/bin/cursor-cgwrap cursor --ozone-platform=wayland" \
  "${HOME}/.local/share/applications/cursor.desktop"
test -f "${HOME}/.local/share/applications/cursor-url-handler.desktop"
grep -F "Exec=${HOME}/.local/bin/cursor-cgwrap cursor --ozone-platform=wayland" \
  "${HOME}/.local/share/applications/cursor-url-handler.desktop"
grep -e '--open-url %U' "${HOME}/.local/share/applications/cursor-url-handler.desktop"
test -f "${HOME}/.cursorignore"
grep -q 'worktrees' "${HOME}/.cursorignore"
test -f "${HOME}/.config/cursor-limits/env"

# Second install keeps custom desktop unless forced
echo 'sentinel=desktop' > "${HOME}/.local/share/applications/cursor.desktop"
echo 'sentinel=url-handler' > "${HOME}/.local/share/applications/cursor-url-handler.desktop"
bash "${ROOT}/install.sh" >/dev/null
grep -q 'sentinel=desktop' "${HOME}/.local/share/applications/cursor.desktop"
grep -q 'sentinel=url-handler' "${HOME}/.local/share/applications/cursor-url-handler.desktop"

FORCE_CURSOR_DESKTOP=1 bash "${ROOT}/install.sh" >/dev/null
if grep -q 'sentinel=desktop' "${HOME}/.local/share/applications/cursor.desktop"; then
  fail "FORCE_CURSOR_DESKTOP did not replace desktop file"
fi
if grep -q 'sentinel=url-handler' "${HOME}/.local/share/applications/cursor-url-handler.desktop"; then
  fail "FORCE_CURSOR_DESKTOP did not replace url-handler desktop file"
fi

# Migration: existing raw agent before wrapper install (fresh HOME)
MIG_HOME="${TMP}/mig-home"
mkdir -p "${MIG_HOME}/.local/bin"
cat >"${MIG_HOME}/.local/bin/agent" <<'EOF'
#!/usr/bin/env bash
echo legacy-agent "$@"
EOF
chmod +x "${MIG_HOME}/.local/bin/agent"
HOME="${MIG_HOME}" XDG_CONFIG_HOME="${MIG_HOME}/.config" XDG_DATA_HOME="${MIG_HOME}/.local/share" \
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" bash "${ROOT}/install.sh" >/dev/null
test -L "${MIG_HOME}/.local/bin/agent-raw"
readlink -f "${MIG_HOME}/.local/bin/agent-raw" | grep -q '/\.local/bin/agent$' || \
  grep -q 'legacy-agent' "${MIG_HOME}/.local/bin/agent-raw"

echo "install smoke test passed"
