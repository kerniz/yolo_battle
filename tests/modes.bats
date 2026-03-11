#!/usr/bin/env bats

load ./helpers.bash

@test "sequential mode creates shared context and log" {
  tmpdir="$TEST_ROOT/seq"
  mkdir -p "$tmpdir"

  run /bin/zsh -c 'source "'"$ROOT_DIR"'/modes/sequential.zsh"; _mode_setup_context "'"$tmpdir"'" 2'
  [ "$status" -eq 0 ]
  [ -f "$tmpdir/context.md" ]
  [ -f "$tmpdir/log.md" ]

  grep -q "Sequential Mode Context" "$tmpdir/context.md"
}

@test "parallel mode creates per-tool contexts" {
  tmpdir="$TEST_ROOT/par"
  mkdir -p "$tmpdir"

  run /bin/zsh -c 'source "'"$ROOT_DIR"'/modes/parallel.zsh"; _mode_setup_context "'"$tmpdir"'" 2 claude gemini'
  [ "$status" -eq 0 ]
  [ -f "$tmpdir/context_claude.md" ]
  [ -f "$tmpdir/context_gemini.md" ]
}

@test "collaborative mode creates shared board" {
  tmpdir="$TEST_ROOT/coop"
  mkdir -p "$tmpdir"

  run /bin/zsh -c 'source "'"$ROOT_DIR"'/modes/collaborative.zsh"; _mode_setup_context "'"$tmpdir"'" 2 claude gemini'
  [ "$status" -eq 0 ]
  [ -f "$tmpdir/shared.md" ]

  grep -q "Shared Board" "$tmpdir/shared.md"
}
