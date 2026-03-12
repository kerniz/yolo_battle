#!/usr/bin/env bats

load ./helpers.bash

@test "security: AI CLI call uses -- to prevent argument injection" {
  # We check yolo_tools.zsh which contains the dispatch logic
  grep -q "claude --dangerously-skip-permissions -- \"\$@\"" "$ROOT_DIR/lib/yolo_tools.zsh"
  grep -q "gemini --yolo -- \"\$@\"" "$ROOT_DIR/lib/yolo_tools.zsh"

  # We also check lib/scriptgen.zsh for generated scripts
  grep -q "claude --dangerously-skip-permissions -- \"\$prompt\"" "$ROOT_DIR/lib/scriptgen.zsh"
  grep -q "gemini --yolo -- \"\$prompt\"" "$ROOT_DIR/lib/scriptgen.zsh"
  grep -q "codex --sandbox danger-full-access --ask-for-approval never -- \"\$prompt\"" "$ROOT_DIR/lib/scriptgen.zsh"
}

@test "security: install.sh restricts YOLO_DIR permissions" {
  grep -q "chmod 700 \"\$YOLO_DIR\"" "$ROOT_DIR/install.sh"
}

@test "quality: yolo.zsh uses modular lib/ files" {
  grep -q "source \"\${YOLO_DIR}/lib/yolo_ui.zsh\"" "$ROOT_DIR/yolo.zsh"
  grep -q "source \"\${YOLO_DIR}/lib/yolo_tools.zsh\"" "$ROOT_DIR/yolo.zsh"
}
