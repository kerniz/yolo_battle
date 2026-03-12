#!/bin/zsh
# ════════════════════════════════════════
# yolo_ui.zsh — UI components for yolo.zsh
# Sourced by yolo.zsh
# ════════════════════════════════════════

_yolo_loading() {
  local tool_name="$1"
  local tool_color="$2"
  local frames=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
  local sparks=("✦" "✧" "✦" "✧" "★" "✧" "✦" "✧")
  local bar_colors=("$red" "$orange" "$yellow" "$green" "$cyan" "$blue" "$purple" "$pink")
  local msg_frames=(
    "Initializing" "Initializing." "Initializing.." "Initializing..."
    "Loading modules" "Loading modules." "Loading modules.." "Loading modules..."
    "Warming up" "Warming up." "Warming up.." "Warming up..."
    "Almost ready" "Almost ready." "Almost ready.." "Almost ready..."
  )
  local total=10
  local width=30

  printf "\n"
  printf "${dim}  ╔══════════════════════════════════════════╗${reset}\n"
  printf "${dim}  ║                                          ║${reset}\n"
  printf "${dim}  ║                                          ║${reset}\n"
  printf "${dim}  ╚══════════════════════════════════════════╝${reset}\n"
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

    printf "\r${dim}  ║${reset}  ${tool_color}${bold}${spin}${reset} ${white}${bold}${msg}${reset}"
    printf "\033[K"
    printf "\n\r${dim}  ║${reset}  ${bar}${reset} ${tool_color}${spark} ${bold}${pct}%%${reset}"
    printf "\033[K"
    printf "\033[1A"

    sleep 0.05
  done

  printf "\r${dim}  ║${reset}  ${tool_color}${bold}✔${reset} ${white}${bold}Ready! Launching ${tool_color}${tool_name}${white}...${reset}"
  printf "\033[K\n"
  printf "\r${dim}  ║${reset}  "
  for ((b=1; b<=width; b++)); do
    local ci=$(( (b * ${#bar_colors[@]} / width) ))
    [ $ci -eq 0 ] && ci=1
    [ $ci -gt ${#bar_colors[@]} ] && ci=${#bar_colors[@]}
    printf "${bar_colors[$ci]}█"
  done
  printf "${reset} ${green}${bold}✦ 100%%${reset}"
  printf "\033[K\n"
  printf "${dim}  ╚══════════════════════════════════════════╝${reset}\n"
  printf "\n"
}

_yolo_select_weapon() {
  local -a opts=("$@")
  local i=0
  local key
  local cursor_up=$'\033'A
  local cursor_down=$'\033'B

  printf "\033[?25l"
  trap 'printf "\033[?25h"' INT

  local total_lines=0
  printf "\n"
  printf "  ${purple}${bold}⚡ PICK YOUR WEAPON ⚡${reset}\n"
  printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
  total_lines=2

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

  _selected_idx=$((i + 1))
  printf "\033[%dA" "$total_lines"
  printf "\033[J"
  printf "\033[?25h"
  trap - INT
}
