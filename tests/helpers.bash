setup() {
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d)"
  export BIN_DIR="$TEST_ROOT/bin"
  mkdir -p "$BIN_DIR"

  export ROOT_DIR
  ROOT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
}

teardown() {
  if [ -n "${TEST_ROOT:-}" ] && [ -d "${TEST_ROOT}" ]; then
    rm -rf "$TEST_ROOT"
  fi
}
