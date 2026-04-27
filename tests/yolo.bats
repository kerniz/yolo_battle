#!/usr/bin/env bats

load ./helpers.bash

@test "yolo errors when no CLI is available" {
  run /bin/zsh -c 'PATH=""; source "'"$ROOT_DIR"'/yolo.zsh"; yolo'
  [ "$status" -eq 1 ]
  [[ "$output" == *"No CLI found"* ]]
}

@test "yolo rejects unknown tool" {
  cat > "$BIN_DIR/codex" <<'STUB'
#!/bin/sh
exit 0
STUB
  chmod +x "$BIN_DIR/codex"

  run env PATH="$BIN_DIR" /bin/zsh -c 'source "'"$ROOT_DIR"'/yolo.zsh"; yolo unknown'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown tool"* ]]
}

@test "yolo codex passes expected flags" {
  cat > "$BIN_DIR/codex" <<'STUB'
#!/bin/sh
printf "%s" "$*" > "$TEST_ARGS_FILE"
STUB
  chmod +x "$BIN_DIR/codex"

  TEST_ARGS_FILE="$TEST_ROOT/args.txt" \
    run env PATH="$BIN_DIR" /bin/zsh -c 'source "'"$ROOT_DIR"'/yolo.zsh"; yolo codex foo bar'

  [ "$status" -eq 0 ]
  args=$(cat "$TEST_ROOT/args.txt")
  [ "$args" = "--sandbox danger-full-access --ask-for-approval never -- foo bar" ]
}

@test "yolo opencode passes expected flags" {
  cat > "$BIN_DIR/opencode" <<'STUB'
#!/bin/sh
printf "%s" "$*" > "$TEST_ARGS_FILE"
STUB
  chmod +x "$BIN_DIR/opencode"

  TEST_ARGS_FILE="$TEST_ROOT/args.txt" \
    run env PATH="$BIN_DIR" /bin/zsh -c 'source "'"$ROOT_DIR"'/yolo.zsh"; yolo opencode foo bar'

  [ "$status" -eq 0 ]
  args=$(cat "$TEST_ROOT/args.txt")
  [ "$args" = "-- foo bar" ]
}

@test "yolo battle fails without tmux" {
  cat > "$BIN_DIR/claude" <<'STUB'
#!/bin/sh
exit 0
STUB
  cat > "$BIN_DIR/gemini" <<'STUB'
#!/bin/sh
exit 0
STUB
  chmod +x "$BIN_DIR/claude" "$BIN_DIR/gemini"

  run env PATH="$BIN_DIR" YOLO_DIR="$ROOT_DIR" /bin/zsh -c 'source "'"$ROOT_DIR"'/yolo.zsh"; yolo battle "hi"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"tmux is required"* ]]
}
