#!/bin/zsh
# yolo - AI CLI launcher with YOLO mode (no guardrails)
# Supports: claude, gemini, codex
# https://github.com/kerniz/yolo_battle

YOLO_DIR="${YOLO_DIR:-$HOME/.yolo}"

yolo() {
  local tool="$1"
  local -a _yolo_opts
  local -a _yolo_icons
  local -a tcolors
  local i=0
  local key
  local cursor_up=$'\033[A'
  local cursor_down=$'\033[B'

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

  _yolo_loading() {
    local tool_name="$1"
    local tool_color="$2"
    local frames=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
    local sparks=("✦" "✧" "✦" "✧" "★" "✧" "✦" "✧")
    local bar_colors=("$red" "$orange" "$yellow" "$green" "$cyan" "$blue" "$purple" "$pink")
    local msg_frames=(
      "Initializing"
      "Initializing."
      "Initializing.."
      "Initializing..."
      "Loading modules"
      "Loading modules."
      "Loading modules.."
      "Loading modules..."
      "Warming up"
      "Warming up."
      "Warming up.."
      "Warming up..."
      "Almost ready"
      "Almost ready."
      "Almost ready.."
      "Almost ready..."
    )
    local total=20
    local width=30

    printf "\n"
    printf "${dim}  ┌──────────────────────────────────────────┐${reset}\n"
    printf "${dim}  │                                          │${reset}\n"
    printf "${dim}  │                                          │${reset}\n"
    printf "${dim}  └──────────────────────────────────────────┘${reset}\n"
    printf "\033[3A"

    for ((f=0; f<total; f++)); do
      local fidx=$((f % ${#frames[@]}))
      local spin="${frames[$((fidx+1))]}"
      local spark="${sparks[$((fidx+1))]}"
      local msg="${msg_frames[$((f % ${#msg_frames[@]} + 1))]}"
      local pct=$(( (f + 1) * 100 / total ))
      local filled=$(( (f + 1) * width / total ))
      local empty=$((width - filled))

      local bar=""
      for ((b=1; b<=filled; b++)); do
        local ci=$(( (b * ${#bar_colors[@]} / width) ))
        [ $ci -eq 0 ] && ci=1
        [ $ci -gt ${#bar_colors[@]} ] && ci=${#bar_colors[@]}
        bar+="${bar_colors[$ci]}█"
      done
      for ((b=1; b<=empty; b++)); do
        bar+="${dim}░"
      done

      printf "\r${dim}  │${reset}  ${tool_color}${bold}${spin}${reset} ${white}${bold}${msg}${reset}"
      printf "\033[K"
      printf "\n\r${dim}  │${reset}  ${bar}${reset} ${tool_color}${spark} ${bold}${pct}%%${reset}"
      printf "\033[K"
      printf "\033[1A"

      sleep 0.08
    done

    printf "\r${dim}  │${reset}  ${tool_color}${bold}✔${reset} ${white}${bold}Ready! Launching ${tool_color}${tool_name}${white}...${reset}"
    printf "\033[K\n"
    printf "\r${dim}  │${reset}  "
    for ((b=1; b<=width; b++)); do
      local ci=$(( (b * ${#bar_colors[@]} / width) ))
      [ $ci -eq 0 ] && ci=1
      [ $ci -gt ${#bar_colors[@]} ] && ci=${#bar_colors[@]}
      printf "${bar_colors[$ci]}█"
    done
    printf "${reset} ${green}${bold}✦ 100%%${reset}"
    printf "\033[K\n"
    printf "${dim}  └──────────────────────────────────────────┘${reset}\n"
    printf "\n"
  }

  if [ -z "$tool" ]; then
    if [ ! -t 0 ]; then
      echo "Usage: yolo <claude|gemini|codex|battle> [args...]"
      return 1
    fi

    printf "\033[?25l"
    trap 'printf "\033[?25h"' INT

    local total_lines=0
    printf "\n"
    printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${yellow}${bold}⚡ Y O L O   M O D E ⚡${reset}             ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${dim}Pick your weapon, no guardrails.${reset}   ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    total_lines=5

    for ((j=1; j<=${#_yolo_opts[@]}; j++)); do
      local name="${_yolo_opts[$j]}"
      local icon="${_yolo_icons[$j]}"
      local col="${tcolors[$j]}"
      if [ $((j-1)) -eq "$i" ]; then
        printf "  ${purple}${bold}║${reset} ${bg_sel} ${col}${bold} ▸ ${icon}  %-18s${reset}${bg_sel}      ${reset} ${purple}${bold}║${reset}\n" "${(U)name}"
      else
        printf "  ${purple}${bold}║${reset}   ${dim}   ${icon}  %-18s      ${reset} ${purple}${bold}║${reset}\n" "$name"
      fi
      total_lines=$((total_lines + 1))
    done

    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${dim}↑↓ navigate${reset}  ${dim}⏎ select${reset}             ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}╚══════════════════════════════════════╝${reset}\n"
    total_lines=$((total_lines + 3))

    while true; do
      read -rs -k1 key
      if [[ "$key" == $'\033' ]]; then
        read -rs -k2 key
        key=$'\033'"$key"
      fi

      case "$key" in
        "$cursor_up")
          i=$(( (i - 1 + ${#_yolo_opts[@]}) % ${#_yolo_opts[@]} ))
          ;;
        "$cursor_down")
          i=$(( (i + 1) % ${#_yolo_opts[@]} ))
          ;;
        $'\n')
          break
          ;;
        *)
          continue
          ;;
      esac

      printf "\033[%dA" "$(( ${#_yolo_opts[@]} + 3 ))"
      for ((j=1; j<=${#_yolo_opts[@]}; j++)); do
        local name="${_yolo_opts[$j]}"
        local icon="${_yolo_icons[$j]}"
        local col="${tcolors[$j]}"
        if [ $((j-1)) -eq "$i" ]; then
          printf "\r  ${purple}${bold}║${reset} ${bg_sel} ${col}${bold} ▸ ${icon}  %-18s${reset}${bg_sel}      ${reset} ${purple}${bold}║${reset}\n" "${(U)name}"
        else
          printf "\r  ${purple}${bold}║${reset}   ${dim}   ${icon}  %-18s      ${reset} ${purple}${bold}║${reset}\n" "$name"
        fi
      done
      printf "\033[3B"
    done

    tool="${_yolo_opts[$((i+1))]}"
    local tool_icon="${_yolo_icons[$((i+1))]}"
    local tool_color="${tcolors[$((i+1))]}"

    printf "\033[%dA" "$total_lines"
    printf "\033[J"

    printf "\n"
    printf "  ${tool_color}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    printf "  ${tool_color}${bold}  ${tool_icon}  ${white}Y O L O${reset} ${dim}→${reset} ${tool_color}${bold}${(U)tool}${reset}\n"
    printf "  ${tool_color}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"

    _yolo_loading "$tool" "$tool_color"

    printf "\033[?25h"
    trap - INT
  else
    shift
  fi

  case "$tool" in
    claude)
      command -v claude >/dev/null 2>&1 || { echo "${red}claude not found${reset}"; return 1; }
      command claude --dangerously-skip-permissions "$@"
      ;;
    gemini)
      command -v gemini >/dev/null 2>&1 || { echo "${red}gemini not found${reset}"; return 1; }
      command gemini --yolo "$@"
      ;;
    codex)
      command -v codex >/dev/null 2>&1 || { echo "${red}codex not found${reset}"; return 1; }
      command codex --sandbox danger-full-access --ask-for-approval never "$@"
      ;;
    *)
      printf "${red}${bold} ✖  Unknown tool: $tool${reset}\n"
      echo "Usage: yolo <claude|gemini|codex|battle> [args...]"
      return 1
      ;;
  esac
}
