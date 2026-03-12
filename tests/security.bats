#!/usr/bin/env bats

load ./helpers.bash

@test "security: AI CLI call uses -- to prevent argument injection" {
  grep -q 'claude --dangerously-skip-permissions -- "\$@"' "$ROOT_DIR/yolo.zsh"
  grep -q 'gemini --yolo -- "\$@"' "$ROOT_DIR/yolo.zsh"
}

@test "security: install.sh restricts YOLO_DIR permissions" {
  grep -q 'chmod 700 "\$YOLO_DIR"' "$ROOT_DIR/install.sh"
}
