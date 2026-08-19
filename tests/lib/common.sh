#!/usr/bin/env bash
# Shared harness for integration tests (temp dir, fail helper, repo root).

estelle_test_begin() {
  local test_name="$1"

  ESTELLE_TEST_NAME="${test_name}"
  ESTELLE_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  ESTELLE_TEST_TMP="$(mktemp -d)"
  trap 'rm -rf "${ESTELLE_TEST_TMP}"' EXIT

  # Aliases for sourcing test scripts (set by estelle_test_begin at top level).
  # shellcheck disable=SC2034
  ROOT="${ESTELLE_TEST_ROOT}"
  # shellcheck disable=SC2034
  TMP="${ESTELLE_TEST_TMP}"
}

fail() {
  echo "${ESTELLE_TEST_NAME}: $*" >&2
  exit 1
}
