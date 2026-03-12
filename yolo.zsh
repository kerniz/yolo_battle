#!/bin/zsh
# yolo - AI CLI launcher with YOLO mode (no guardrails)
# https://github.com/kerniz/yolo_battle

YOLO_DIR="${YOLO_DIR:-$HOME/.yolo}"

yolo() {
  local tool="$1"
  local -a _yolo_opts _yolo_icons tcolors
  local _selected_idx

  # colors
  local reset=$'\033[0m'
  local bold=$'\033[1m'
  local dim=$'\033[2m'
  local blink=$'\033[5m'
  local red=$'\033[38;5;196m'
  local orange=$'\033[38;5;208m'
  local yellow=$'\033[38;5;220m'
  local green=$'\033[38;5;82m'
  local cyan=$'\033[38;5;51m'
  local blue=$'\033[38;5;33m'
  local purple=$'\033[38;5;141m'
  local pink=$'\033[38;5;213m'
  local white=$'\033[38;5;255m'
  local bg_sel=$'\033[48;5;236m'
  local bg_dark=$'\033[48;5;233m'

  # source modules
  source "${YOLO_DIR}/lib/yolo_ui.zsh"
  source "${YOLO_DIR}/lib/yolo_tools.zsh"

  _yolo_check_available

  if [ ${#_yolo_opts[@]} -eq 0 ]; then
    printf "${red}${bold} ✖  No CLI found: claude / gemini / codex${reset}\n"
    return 1
  fi

  # ── Battle mode: dispatch to battle.zsh ──
  if [[ "$1" == "battle" ]]; then
    shift
    source "${YOLO_DIR}/battle.zsh" && _yolo_battle "$@"
    return $?
  fi

  if [ -z "$tool" ]; then
    if [ ! -t 0 ]; then
      echo "Usage: yolo <claude|gemini|codex|battle> [args...]"
      return 1
    fi

    _yolo_select_weapon

    tool="${_yolo_opts[$_selected_idx]}"
    local tool_icon="${_yolo_icons[$_selected_idx]}"
    local tool_color="${tcolors[$_selected_idx]}"

    printf "\n"
    printf "  ${tool_color}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    printf "  ${tool_color}${bold}  ${tool_icon}  ${white}Y O L O${reset} ${dim}→${reset} ${tool_color}${bold}${(U)tool}${reset}\n"
    printf "  ${tool_color}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"

    _yolo_loading "$tool" "$tool_color"
  else
    shift
  fi

  _yolo_dispatch "$tool" "$@"
}
