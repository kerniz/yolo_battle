#!/bin/zsh
# yolo battle - multi-agent battle mode
# Usage: yolo battle [-p|-s|-c] "prompt"
#   -p  parallel  (동시)   : 각 AI 독립 컨텍스트, 서로 열람 가능, 사용자가 최종 선택
#   -s  sequential(순차)   : 1개 컨텍스트 릴레이, /next로 라운드로빈 무한순환
#   -c  collaborative(협동): 역할분리 + 3개 작업컨텍스트 + 1개 공유보드, worktree 격리

_yolo_battle() {
  # Receive context from parent yolo function via these globals:
  #   _yolo_opts, _yolo_icons, tcolors (arrays)
  #   reset, bold, dim, red, orange, yellow, green, cyan, blue, purple, pink, white (colors)

  # source lib modules
  source "${YOLO_DIR}/lib/ui_select.zsh"
  source "${YOLO_DIR}/lib/workspace.zsh"
  source "${YOLO_DIR}/lib/scriptgen.zsh"
  source "${YOLO_DIR}/lib/tmux_layout.zsh"

  # ── parse mode flag ──
  local mode=""
  local -a _seq_order
  case "$1" in
    -p|--parallel)      mode="parallel"; shift ;;
    -s|--sequential)    mode="sequential"; shift ;;
    -c|--collaborative) mode="collaborative"; shift ;;
  esac

  # ── interactive mode selection if no flag given ──
  if [ -z "$mode" ] && [ -t 0 ]; then
    _battle_select_mode
  elif [ -z "$mode" ]; then
    mode="collaborative"
  fi

  local prompt="$*"

  command -v tmux >/dev/null 2>&1 || {
    printf "${red}${bold} ✖  tmux is required for battle mode${reset}\n"
    return 1
  }

  # ── interactive agent selection ──
  local cnt=${#_yolo_opts[@]}
  if [ $cnt -ge 2 ] && [ -t 0 ]; then
    _battle_select_agents
  fi

  if [ $cnt -lt 2 ]; then
    printf "${red}${bold} ✖  Need at least 2 CLIs for battle${reset}\n"
    return 1
  fi

  # ── prepare workspace ──
  local tmpdir savedir workdir _coop_use_worktree
  _battle_setup_workspace

  local _is_restart=false
  while true; do
  # ── re-source mode skill file (critical for mode switch) ──
  local _mode_file="${YOLO_DIR}/modes/${mode}.zsh"
  if [ -f "$_mode_file" ]; then
    source "$_mode_file"
  else
    printf "${red}${bold} ✖  Mode skill file not found: ${_mode_file}${reset}\n"
    return 1
  fi

  # ── set default prompt after mode skill is loaded ──
  if [ -z "$prompt" ]; then
    if typeset -f _mode_default_prompt > /dev/null 2>&1; then
      prompt="$(_mode_default_prompt)"
    else
      prompt="사용자의 지시를 대기하세요. 스스로 판단해서 코드를 수정하거나 파일을 변경하지 마세요."
    fi
  fi
  printf '%s' "$prompt" > "$tmpdir/prompt.txt"
  printf '%s' "$prompt" > "$tmpdir/user_cmd.txt"

  # ── setup context files for current mode ──
  _mode_setup_context "$tmpdir" "$cnt" "${_yolo_opts[@]}"

  # ── reset mode-dependent state for restart ──
  _battle_reset_state

  # ── role definitions (from mode skill) ──
  local -a _roles _role_prompts
  _roles=("${_mode_roles[@]}")
  if [ ${#_mode_roles[@]} -eq 0 ]; then
    _roles=()
    _role_prompts=()
  fi

  # ── collaborative mode: interactive role selection ──
  if [[ "$mode" == "collaborative" ]] && [ -t 0 ] && ! $_is_restart && [ ${#_mode_available_roles[@]} -gt 0 ]; then
    _battle_select_roles
  fi

  if [ -n "$prompt" ]; then
    _mode_setup_roles "$tmpdir" "$prompt"
    _role_prompts=("${_mode_role_prompts[@]}")
  fi

  # ── sequential mode: order selection ──
  _seq_order=()
  if $_mode_needs_order && [ -t 0 ] && ! $_is_restart; then
    _battle_select_order
  else
    for ((j=1; j<=$cnt; j++)); do _seq_order+=($j); done
  fi

  # write order to file for scripts to read
  for ((j=1; j<=${#_seq_order[@]}; j++)); do
    local oidx=${_seq_order[$j]}
    echo "$oidx:$j" >> "$tmpdir/seq_order_map.txt"
  done

  # ── generate scripts ──
  local -a _battle_scripts
  local session="yolo-battle"
  _battle_gen_tool_scripts

  # ── launch banner ──
  _battle_gen_banner

  # ── generate helper scripts ──
  local help_script cmd_script monitor
  _battle_gen_help_panel
  _battle_gen_cmd_center

  # ── layout selection for 3+ tools ──
  local _layout_choice="top3"
  if [ $cnt -ge 3 ] && [ -t 0 ] && ! $_is_restart; then
    _battle_select_layout
  fi

  # ── create tmux session ──
  local -a _ai_pane_ids
  local _cmd_pane_id
  _battle_setup_tmux
  _battle_setup_tmux_options

  # ── status bar monitor ──
  _battle_gen_monitor

  zsh "$monitor" &
  local monitor_pid=$!

  # focus on command center
  tmux select-pane -t "${_cmd_pane_id}"

  tmux attach -t "$session"

  # cleanup
  kill $monitor_pid 2>/dev/null
  tmux kill-session -t "$session" 2>/dev/null

  _battle_cleanup_worktrees

  # check for mode restart request
  if [ -f "$tmpdir/new_mode.txt" ]; then
    mode=$(cat "$tmpdir/new_mode.txt")
    rm -f "$tmpdir/new_mode.txt"
    _is_restart=true
    printf "\n  ${green}${bold}⚡ ${mode} 모드로 재시작합니다...${reset}\n\n"
    sleep 0.5
    continue
  fi
  break
  done  # end while true restart loop

  return 0
}
