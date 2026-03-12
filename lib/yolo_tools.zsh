#!/bin/zsh
# ════════════════════════════════════════
# yolo_tools.zsh — Tool definitions and dispatch
# Sourced by yolo.zsh
# ════════════════════════════════════════

_yolo_check_available() {
  _yolo_opts=()
  _yolo_icons=()
  tcolors=()
  if command -v claude >/dev/null 2>&1; then
    _yolo_opts+=("claude"); _yolo_icons+=("🤖"); tcolors+=("$orange")
  fi
  if command -v gemini >/dev/null 2>&1; then
    _yolo_opts+=("gemini"); _yolo_icons+=("✨"); tcolors+=("$blue")
  fi
  if command -v codex >/dev/null 2>&1; then
    _yolo_opts+=("codex"); _yolo_icons+=("🧠"); tcolors+=("$green")
  fi
}

_yolo_dispatch() {
  local tool="$1"
  shift
  case "$tool" in
    claude)
      command -v claude >/dev/null 2>&1 || { echo "${red}claude not found${reset}"; return 1; }
      command claude --dangerously-skip-permissions -- "$@"
      ;;
    gemini)
      command -v gemini >/dev/null 2>&1 || { echo "${red}gemini not found${reset}"; return 1; }
      command gemini --yolo -- "$@"
      ;;
    codex)
      command -v codex >/dev/null 2>&1 || { echo "${red}codex not found${reset}"; return 1; }
      command codex --sandbox danger-full-access --ask-for-approval never -- "$@"
      ;;
    *)
      printf "${red}${bold} ✖  Unknown tool: $tool${reset}\n"
      echo "Usage: yolo <claude|gemini|codex|battle> [args...]"
      return 1
      ;;
  esac
}
