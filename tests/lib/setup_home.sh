#!/usr/bin/env bash
# Shared temp HOME layout for install/uninstall integration tests.
estelle_test_setup_home() {
  local tmp_root="$1"

  export HOME="${tmp_root}/home"
  export XDG_CONFIG_HOME="${HOME}/.config"
  export XDG_DATA_HOME="${HOME}/.local/share"
  export XDG_RUNTIME_DIR="${tmp_root}/runtime"
  mkdir -p "${HOME}/.local/share/cursor-agent/versions/2099.01.01-test"
  cat >"${HOME}/.local/share/cursor-agent/versions/2099.01.01-test/cursor-agent" <<'EOF'
#!/usr/bin/env bash
echo cursor-agent-stub "$@"
EOF
  chmod +x "${HOME}/.local/share/cursor-agent/versions/2099.01.01-test/cursor-agent"
  mkdir -p "${XDG_RUNTIME_DIR}"
  chmod 700 "${XDG_RUNTIME_DIR}"
}

estelle_test_mock_pkexec() {
  local tmp_root="$1"
  local mock_bin="${tmp_root}/mock-bin"

  mkdir -p "${mock_bin}"
  ln -sf "${BASH_SOURCE[0]%/*}/mock_pkexec.sh" "${mock_bin}/pkexec"
  export PATH="${mock_bin}:${PATH}"
}
