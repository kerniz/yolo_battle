#!/bin/zsh
# yolo battle - multi-agent battle mode
# Usage: yolo battle [-p|-s|-c] "prompt"
#   -p  parallel  (동시)   : all AIs run the same prompt simultaneously (default)
#   -s  sequential(순차)   : one AI at a time, /next to proceed
#   -c  collaborative(협동): role-based pipeline (code→review→test)

_yolo_battle() {
  # Receive context from parent yolo function via these globals:
  #   _yolo_opts, _yolo_icons, tcolors (arrays)
  #   reset, bold, dim, red, orange, yellow, green, cyan, blue, purple, pink, white (colors)

  # ── parse mode flag ──
  local mode="parallel"
  local -a _seq_order  # custom order for sequential mode
  case "$1" in
    -p|--parallel)      mode="parallel"; shift ;;
    -s|--sequential)    mode="sequential"; shift ;;
    -c|--collaborative) mode="collaborative"; shift ;;
  esac
  local prompt="$*"

  command -v tmux >/dev/null 2>&1 || {
    printf "${red}${bold} ✖  tmux is required for battle mode${reset}\n"
    return 1
  }

  local cnt=${#_yolo_opts[@]}
  if [ $cnt -lt 2 ]; then
    printf "${red}${bold} ✖  Need at least 2 CLIs for battle${reset}\n"
    return 1
  fi

  # ── prepare workspace ──
  local tmpdir
  tmpdir=$(mktemp -d /tmp/yolo-battle-XXXXXX)
  local savedir="$HOME/yolo-results/$(date +%Y%m%d-%H%M%S)"
  local workdir="$(pwd)"

  printf '%s' "$prompt" > "$tmpdir/prompt.txt"
  printf '%s' "$mode" > "$tmpdir/mode.txt"
  printf '%s' "$workdir" > "$tmpdir/workdir.txt"
  echo "0" > "$tmpdir/seq_turn.txt"

  # ── role definitions for collaborative mode ──
  local -a _roles _role_prompts
  _roles=("Developer" "Reviewer" "Tester")
  if [ -n "$prompt" ]; then
    _role_prompts=(
      "You are a developer. Write production-ready code for: ${prompt}"
      "You are a senior code reviewer. Review the implementation and suggest improvements for: ${prompt}"
      "You are a QA engineer. Write comprehensive tests for: ${prompt}"
    )
  fi

  # ── sequential mode: order selection ──
  _seq_order=()
  if [[ "$mode" == "sequential" ]] && [ -t 0 ]; then
    printf "\n"
    printf "  ${cyan}${bold}➡️  순차 모드 - 실행 순서${reset}\n"
    printf "  ${dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    for ((j=1; j<=$cnt; j++)); do
      printf "   ${white}${bold}%d)${reset} ${tcolors[$j]}${_yolo_icons[$j]}  ${_yolo_opts[$j]}${reset}\n" "$j"
    done
    printf "  ${dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"

    local default_order=""
    for ((j=1; j<=$cnt; j++)); do default_order+="$j "; done
    default_order="${default_order% }"

    printf "  ${yellow}순서 입력${reset} ${dim}(예: 2 1 3)${reset} [${dim}기본: ${default_order}${reset}]: "
    local order_input
    read -r order_input

    if [ -z "$order_input" ]; then
      for ((j=1; j<=$cnt; j++)); do _seq_order+=($j); done
    else
      _seq_order=( ${=order_input} )
      # validate
      local valid=true
      if [ ${#_seq_order[@]} -ne $cnt ]; then
        valid=false
      else
        for ((j=1; j<=$cnt; j++)); do
          local found=false
          for v in "${_seq_order[@]}"; do
            [ "$v" = "$j" ] && found=true
          done
          $found || valid=false
        done
      fi
      if ! $valid; then
        printf "  ${red}잘못된 입력. 기본 순서로 진행합니다.${reset}\n"
        _seq_order=()
        for ((j=1; j<=$cnt; j++)); do _seq_order+=($j); done
      fi
    fi

    printf "\n  ${green}${bold}✔ 실행 순서:${reset} "
    for ((j=1; j<=${#_seq_order[@]}; j++)); do
      local oidx=${_seq_order[$j]}
      [ $j -gt 1 ] && printf " ${dim}→${reset} "
      printf "${tcolors[$oidx]}${_yolo_icons[$oidx]} ${_yolo_opts[$oidx]}${reset}"
    done
    printf "\n\n"
  else
    for ((j=1; j<=$cnt; j++)); do _seq_order+=($j); done
  fi

  # write order to file for scripts to read
  # seq_order_map: maps tool index → its turn number
  # e.g., order "2 1 3" means tool2=turn1, tool1=turn2, tool3=turn3
  for ((j=1; j<=${#_seq_order[@]}; j++)); do
    local oidx=${_seq_order[$j]}
    echo "$oidx:$j" >> "$tmpdir/seq_order_map.txt"
  done

  # ── generate tool scripts ──
  local -a _battle_scripts
  local session="yolo-battle"

  for ((j=1; j<=$cnt; j++)); do
    local tname="${_yolo_opts[$j]}"
    local ticon="${_yolo_icons[$j]}"
    local script="$tmpdir/run_${tname}.sh"
    local toolworkdir="$tmpdir/work_${tname}"
    mkdir -p "$toolworkdir"

    {
      echo '#!/bin/zsh'
      echo "tmpdir=\"$tmpdir\""
      echo "statusfile=\"$tmpdir/status_${tname}\""
      echo "toolname=\"$tname\""
      echo "toolidx=$j"
      echo "mode=\"$mode\""
      echo "workdir=\"$workdir\""
      echo ""

      # banner
      case "$tname" in
        claude) cat << 'B'
printf '\n  \033[38;5;208m\033[1m  ╔═══════════════════════════════╗\033[0m\n'
printf '  \033[38;5;208m\033[1m  ║  🤖  C L A U D E             ║\033[0m\n'
printf '  \033[38;5;208m\033[1m  ╚═══════════════════════════════╝\033[0m\n\n'
B
        ;;
        gemini) cat << 'B'
printf '\n  \033[38;5;33m\033[1m  ╔═══════════════════════════════╗\033[0m\n'
printf '  \033[38;5;33m\033[1m  ║  ✨  G E M I N I              ║\033[0m\n'
printf '  \033[38;5;33m\033[1m  ╚═══════════════════════════════╝\033[0m\n\n'
B
        ;;
        codex) cat << 'B'
printf '\n  \033[38;5;82m\033[1m  ╔═══════════════════════════════╗\033[0m\n'
printf '  \033[38;5;82m\033[1m  ║  🧠  C O D E X               ║\033[0m\n'
printf '  \033[38;5;82m\033[1m  ╚═══════════════════════════════╝\033[0m\n\n'
B
        ;;
      esac

      # mode-specific behavior
      cat << 'WAIT_LOGIC'
# ── sequential mode: wait for turn ──
if [[ "$mode" == "sequential" ]]; then
  # find my turn number from order map
  my_turn=""
  while IFS=: read -r tidx tnum; do
    [ "$tidx" = "$toolidx" ] && my_turn="$tnum"
  done < "$tmpdir/seq_order_map.txt"
  [ -z "$my_turn" ] && my_turn="$toolidx"

  echo "waiting" > "$statusfile"
  printf '  \033[2m⏳ Waiting for turn (#%s)...\033[0m\n' "$my_turn"
  while true; do
    local turn=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
    [ "$turn" = "$my_turn" ] && break
    sleep 0.5
  done
  printf '  \033[38;5;220m\033[1m▶ Your turn!\033[0m\n\n'
fi
WAIT_LOGIC

      # determine prompt based on mode
      echo 'prompt=$(cat "$tmpdir/prompt.txt")'
      echo ""

      if [[ "$mode" == "collaborative" ]]; then
        local role="${_roles[$j]:-Developer}"
        local rprompt="${_role_prompts[$j]}"
        echo "role=\"$role\""
        echo "printf '  \\033[38;5;220m\\033[1m📋 Role: ${role}\\033[0m\\n\\n'"
        if [ -n "$rprompt" ]; then
          # Write role prompt to a file to avoid quoting issues
          printf '%s' "$rprompt" > "$tmpdir/role_prompt_${tname}.txt"
          echo "prompt=\$(cat \"$tmpdir/role_prompt_${tname}.txt\")"
        fi
      fi

      # mark as running + record start time
      echo 'echo "running" > "$statusfile"'
      echo '_start_ts=$SECONDS'
      echo ""
      echo "cd \"$workdir\""

      # tool command (with or without prompt)
      cat << 'RUN_TOOL'
if [ -n "$prompt" ]; then
  case "$toolname" in
    claude) claude --dangerously-skip-permissions "$prompt" ;;
    gemini) gemini --yolo "$prompt" ;;
    codex)  codex --sandbox danger-full-access --ask-for-approval never "$prompt" ;;
  esac
else
  case "$toolname" in
    claude) claude --dangerously-skip-permissions ;;
    gemini) gemini --yolo ;;
    codex)  codex --sandbox danger-full-access --ask-for-approval never ;;
  esac
fi
RUN_TOOL

      # mark as done
      cat << 'DONE_LOGIC'

_elapsed=$(( SECONDS - _start_ts ))
echo "done:${_elapsed}s" > "$statusfile"

# sequential mode: advance turn
if [[ "$mode" == "sequential" ]]; then
  next_turn=$(( my_turn + 1 ))
  echo "$next_turn" > "$tmpdir/seq_turn.txt"
fi

printf '\n  \033[2m[완료] 아무 키나 누르세요...\033[0m'
read -rs -k1
DONE_LOGIC
    } > "$script"
    chmod +x "$script"
    _battle_scripts+=("$script")
  done

  # ── mode labels ──
  local mode_label mode_icon mode_color
  case "$mode" in
    parallel)
      mode_label="PARALLEL (동시)"
      mode_icon="⚡"
      mode_color="$yellow"
      ;;
    sequential)
      mode_label="SEQUENTIAL (순차)"
      mode_icon="➡️"
      mode_color="$cyan"
      ;;
    collaborative)
      mode_label="COLLABORATIVE (협동)"
      mode_icon="🤝"
      mode_color="$green"
      ;;
  esac

  # ── launch banner ──
  printf "\n"
  printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
  printf "  ${purple}${bold}║${reset}  ${red}${bold}⚔️  Y O L O   B A T T L E${reset}          ${purple}${bold}║${reset}\n"
  printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
  printf "  ${purple}${bold}║${reset}  ${mode_color}${bold}${mode_icon} ${mode_label}${reset}%-$((21 - ${#mode_label}))s${purple}${bold}║${reset}\n" ""
  printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
  for ((j=1; j<=$cnt; j++)); do
    local extra=""
    if [[ "$mode" == "collaborative" ]]; then
      extra=" (${_roles[$j]:-Dev})"
    elif [[ "$mode" == "sequential" ]]; then
      extra=" [#$j]"
    fi
    printf "  ${purple}${bold}║${reset}   ${tcolors[$j]}${bold} ${_yolo_icons[$j]}  ${(U)_yolo_opts[$j]}${reset}${dim}${extra}${reset}%-$((26 - ${#_yolo_opts[$j]} - ${#extra}))s${purple}${bold}║${reset}\n" ""
  done
  if [ -n "$prompt" ]; then
    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${yellow}${bold}⚡${reset} ${white}%.34s${reset} ${purple}${bold}║${reset}\n" "$prompt"
  fi
  printf "  ${purple}${bold}╚══════════════════════════════════════╝${reset}\n"
  printf "\n  ${dim}Launching tmux session...${reset}\n"
  sleep 1

  # ── command center script ──
  local cmd_script="$tmpdir/cmd_center.sh"
  {
    echo '#!/bin/zsh'
    echo "session=\"$session\""
    echo "tmpdir=\"$tmpdir\""
    echo "cnt=$cnt"
    echo "mode=\"$mode\""
    echo "savedir=\"$savedir\""

    # embed tool names for display
    echo "_cmd_tools=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_yolo_opts[$j]}\""; done
    echo ")"
    echo "_cmd_icons=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_yolo_icons[$j]}\""; done
    echo ")"
    echo "_cmd_roles=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_roles[$j]:-}\""; done
    echo ")"
    # sequential order (turn_number → tool_index mapping)
    echo "_cmd_seq_order=("
    for ((j=1; j<=${#_seq_order[@]}; j++)); do echo "  ${_seq_order[$j]}"; done
    echo ")"

    cat << 'CMD_BODY'

rst=$'\033[0m'
bld=$'\033[1m'
dm=$'\033[2m'
red=$'\033[38;5;196m'
ylw=$'\033[38;5;220m'
grn=$'\033[38;5;82m'
cyn=$'\033[38;5;51m'
prp=$'\033[38;5;141m'
wht=$'\033[38;5;255m'
org=$'\033[38;5;208m'

# wait for pane index file
while [ ! -f "$tmpdir/ai_panes.txt" ]; do sleep 0.1; done
ai_panes=( $(cat "$tmpdir/ai_panes.txt") )

clear
printf "\n"
printf "  ${prp}${bld}╔══════════════════════════════════════╗${rst}\n"
printf "  ${prp}${bld}║${rst}  ${ylw}${bld}⌨️  C O M M A N D   C E N T E R${rst}    ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"

case "$mode" in
  parallel)
    printf "  ${prp}${bld}║${rst}  ${ylw}${bld}⚡ PARALLEL${rst} ${dm}동시 모드${rst}             ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}  ${dm}입력 → 모든 AI에 동시 전송${rst}         ${prp}${bld}║${rst}\n"
    ;;
  sequential)
    printf "  ${prp}${bld}║${rst}  ${cyn}${bld}➡️  SEQUENTIAL${rst} ${dm}순차 모드${rst}          ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}  ${dm}한 AI씩 순서대로 실행${rst}              ${prp}${bld}║${rst}\n"
    ;;
  collaborative)
    printf "  ${prp}${bld}║${rst}  ${grn}${bld}🤝 COLLABORATIVE${rst} ${dm}협동 모드${rst}        ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}  ${dm}역할별 동시 작업${rst}                   ${prp}${bld}║${rst}\n"
    ;;
esac

printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"
printf "  ${prp}${bld}║${rst}  ${cyn}명령어:${rst}                            ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}/status${rst}    각 AI 상태 확인        ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}/save${rst}      결과 저장              ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}/prompt X${rst}  프롬프트 변경          ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}/focus N${rst}   N번 pane 포커스        ${prp}${bld}║${rst}\n"

if [[ "$mode" == "sequential" ]]; then
  printf "  ${prp}${bld}║${rst}   ${ylw}${bld}/next${rst}      다음 AI 시작 ${cyn}★${rst}       ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/skip${rst}      현재 AI 건너뛰기     ${prp}${bld}║${rst}\n"
fi

printf "  ${prp}${bld}║${rst}   ${ylw}/mode X${rst}    모드 변경 후 재시작   ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}/quit${rst}      세션 종료              ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"
printf "  ${prp}${bld}║${rst}  ${cyn}단축키:${rst}                            ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}Ctrl+B → 방향키${rst}  pane 이동        ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}Ctrl+B → z${rst}      풀스크린 토글     ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}Ctrl+B → S${rst}      동기화 토글       ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}║${rst}   ${ylw}Ctrl+B → d${rst}      세션 나가기       ${prp}${bld}║${rst}\n"
printf "  ${prp}${bld}╚══════════════════════════════════════╝${rst}\n"

# collaborative mode: show roles
if [[ "$mode" == "collaborative" ]]; then
  printf "\n  ${grn}${bld}📋 역할 배정:${rst}\n"
  for ((r=1; r<=${#_cmd_tools[@]}; r++)); do
    printf "   ${_cmd_icons[$r]} ${_cmd_tools[$r]}: ${ylw}${_cmd_roles[$r]}${rst}\n"
  done
fi

# sequential mode: show order (using custom order)
if [[ "$mode" == "sequential" ]]; then
  printf "\n  ${cyn}${bld}📋 실행 순서:${rst}\n"
  for ((r=1; r<=${#_cmd_seq_order[@]}; r++)); do
    local oi=${_cmd_seq_order[$r]}
    printf "   ${dm}#${r}${rst} ${_cmd_icons[$oi]} ${_cmd_tools[$oi]}\n"
  done
  printf "\n  ${ylw}${bld}▶ #1 자동 시작됨. /next로 다음 진행${rst}\n"
fi

printf "\n"

_show_status() {
  printf "\n"
  for ((si=1; si<=${#_cmd_tools[@]}; si++)); do
    local sname="${_cmd_tools[$si]}"
    local sicon="${_cmd_icons[$si]}"
    local sfile="$tmpdir/status_${sname}"
    if [ -f "$sfile" ]; then
      local st=$(cat "$sfile" 2>/dev/null)
      case "$st" in
        done:*)  printf "  ${grn}${bld}✔ ${sicon} %-12s${rst} ${dm}완료 (${st#done:})${rst}\n" "$sname" ;;
        running) printf "  ${ylw}${bld}⣾ ${sicon} %-12s${rst} ${ylw}작업중...${rst}\n" "$sname" ;;
        waiting) printf "  ${dm}⏳ ${sicon} %-12s 대기중${rst}\n" "$sname" ;;
        *)       printf "  ${dm}·  ${sicon} %-12s --${rst}\n" "$sname" ;;
      esac
    else
      printf "  ${dm}·  ${sicon} %-12s --${rst}\n" "$sname"
    fi
  done
  printf "\n"
}

_do_save() {
  mkdir -p "$savedir"
  # capture each AI pane's output
  for ((si=0; si<${#ai_panes[@]}; si++)); do
    local pidx="${ai_panes[$((si+1))]}"
    local tname="${_cmd_tools[$((si+1))]}"
    tmux capture-pane -t "${session}:0.${pidx}" -p -S -500 > "$savedir/${tname}.txt" 2>/dev/null
  done
  # save prompt
  cp "$tmpdir/prompt.txt" "$savedir/prompt.txt" 2>/dev/null
  # save mode
  cp "$tmpdir/mode.txt" "$savedir/mode.txt" 2>/dev/null
  printf "  ${grn}${bld}✔ 저장됨:${rst} ${dm}${savedir}${rst}\n"
  printf "  ${dm}  파일: prompt.txt"
  for ((si=1; si<=${#_cmd_tools[@]}; si++)); do
    printf ", ${_cmd_tools[$si]}.txt"
  done
  printf "${rst}\n\n"
}

_do_next() {
  if [[ "$mode" != "sequential" ]]; then
    printf "  ${red}순차 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  local next=$(( cur + 1 ))
  if [ $next -gt ${#_cmd_seq_order[@]} ]; then
    printf "  ${grn}${bld}✔ 모든 AI가 완료되었습니다${rst}\n"
    return
  fi
  echo "$next" > "$tmpdir/seq_turn.txt"
  local next_tool_idx=${_cmd_seq_order[$next]}
  printf "  ${cyn}${bld}▶ #${next} ${_cmd_icons[$next_tool_idx]} ${_cmd_tools[$next_tool_idx]} 시작${rst}\n"
}

_do_skip() {
  if [[ "$mode" != "sequential" ]]; then
    printf "  ${red}순차 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  local cur_tool_idx=${_cmd_seq_order[$cur]}
  printf "  ${ylw}⏭ #${cur} ${_cmd_icons[$cur_tool_idx]} 건너뜀${rst}\n"
  local next=$(( cur + 1 ))
  echo "$next" > "$tmpdir/seq_turn.txt"
  if [ $next -le ${#_cmd_seq_order[@]} ]; then
    local next_tool_idx=${_cmd_seq_order[$next]}
    printf "  ${cyn}${bld}▶ #${next} ${_cmd_icons[$next_tool_idx]} ${_cmd_tools[$next_tool_idx]} 시작${rst}\n"
  else
    printf "  ${grn}${bld}✔ 모든 순서 완료${rst}\n"
  fi
}

# sequential mode: auto-start first AI
if [[ "$mode" == "sequential" ]]; then
  echo "1" > "$tmpdir/seq_turn.txt"
fi

# input loop
while true; do
  printf "  ${prp}${bld}▸${rst} "
  read -r input || break

  case "$input" in
    /quit)
      printf "  ${red}세션을 종료합니다...${rst}\n"
      tmux kill-session -t "$session" 2>/dev/null
      break
      ;;
    /status)
      _show_status
      ;;
    /save)
      _do_save
      ;;
    /next)
      _do_next
      ;;
    /skip)
      _do_skip
      ;;
    /prompt\ *)
      local new_prompt="${input#/prompt }"
      printf '%s' "$new_prompt" > "$tmpdir/prompt.txt"
      printf "  ${grn}${bld}✔ 프롬프트 변경됨:${rst} ${dm}${new_prompt}${rst}\n"
      ;;
    /focus\ *)
      local pnum="${input#/focus }"
      tmux select-pane -t "${session}:0.${pnum}" 2>/dev/null
      ;;
    /mode\ *)
      local new_mode="${input#/mode }"
      printf "\n  ${ylw}${bld}모드를 변경하려면 세션을 재시작하세요:${rst}\n"
      printf "  ${dm}  yolo battle -${new_mode[1]} \"프롬프트\"${rst}\n"
      printf "  ${dm}  -p: parallel  -s: sequential  -c: collaborative${rst}\n\n"
      ;;
    /help)
      printf "\n  ${ylw}/status${rst}  상태  ${ylw}/save${rst}  저장  ${ylw}/next${rst}  다음  ${ylw}/prompt X${rst}  변경\n"
      printf "  ${ylw}/focus N${rst} 포커스  ${ylw}/skip${rst}  건너뛰기  ${ylw}/mode X${rst}  모드  ${ylw}/quit${rst}  종료\n\n"
      ;;
    "")
      ;;
    *)
      if [[ "$mode" == "sequential" ]]; then
        # in sequential mode, send only to the current active AI (using order map)
        local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
        if [ $cur -ge 1 ] && [ $cur -le ${#_cmd_seq_order[@]} ]; then
          local cur_tool_idx=${_cmd_seq_order[$cur]}
          local target_pane="${ai_panes[$cur_tool_idx]}"
          tmux send-keys -t "${session}:0.${target_pane}" "$input" Enter 2>/dev/null
          printf "  ${dm}→ ${_cmd_icons[$cur_tool_idx]} ${_cmd_tools[$cur_tool_idx]}에 전송됨${rst}\n"
        else
          printf "  ${red}현재 활성 AI가 없습니다${rst}\n"
        fi
      else
        # parallel & collaborative: broadcast to all
        for p in "${ai_panes[@]}"; do
          tmux send-keys -t "${session}:0.${p}" "$input" Enter 2>/dev/null
        done
        printf "  ${dm}→ ${#ai_panes[@]}개 AI에 전송됨${rst}\n"
      fi
      ;;
  esac
done
CMD_BODY
  } > "$cmd_script"
  chmod +x "$cmd_script"

  # ── create tmux session ──
  tmux kill-session -t "$session" 2>/dev/null

  if [ $cnt -eq 2 ]; then
    # ┌──────────┬──────────┐
    # │  tool1   │  tool2   │
    # ├──────────┴──────────┤
    # │     ⌨️ COMMAND       │
    # └─────────────────────┘
    tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
    tmux split-window -v -t "${session}:0.0" -p 30 "zsh ${cmd_script}"
    tmux split-window -h -t "${session}:0.0" -p 50 "zsh ${_battle_scripts[2]}"
    echo "0 2" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${session}:0.0" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${session}:0.1" -T "⌨️  COMMAND CENTER"
    tmux select-pane -t "${session}:0.2" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
  elif [ $cnt -ge 3 ]; then
    # ┌──────────┬──────────┐
    # │  tool1   │  tool2   │
    # ├──────────┬──────────┤
    # │  tool3   │ ⌨️ CMD   │
    # └──────────┴──────────┘
    tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
    tmux split-window -v -t "${session}:0.0" -p 40 "zsh ${_battle_scripts[3]}"
    tmux split-window -h -t "${session}:0.0" -p 50 "zsh ${_battle_scripts[2]}"
    tmux split-window -h -t "${session}:0.1" -p 50 "zsh ${cmd_script}"
    echo "0 2 1" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${session}:0.0" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${session}:0.1" -T "${_yolo_icons[3]} ${(U)_yolo_opts[3]}"
    tmux select-pane -t "${session}:0.2" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${session}:0.3" -T "⌨️  COMMAND CENTER"
  fi

  # collaborative mode: add role to pane titles
  if [[ "$mode" == "collaborative" ]]; then
    if [ $cnt -eq 2 ]; then
      tmux select-pane -t "${session}:0.0" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]} (${_roles[1]})"
      tmux select-pane -t "${session}:0.2" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]} (${_roles[2]})"
    elif [ $cnt -ge 3 ]; then
      tmux select-pane -t "${session}:0.0" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]} (${_roles[1]})"
      tmux select-pane -t "${session}:0.1" -T "${_yolo_icons[3]} ${(U)_yolo_opts[3]} (${_roles[3]})"
      tmux select-pane -t "${session}:0.2" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]} (${_roles[2]})"
    fi
  fi

  # sequential mode: add order numbers to pane titles
  if [[ "$mode" == "sequential" ]]; then
    if [ $cnt -eq 2 ]; then
      tmux select-pane -t "${session}:0.0" -T "#1 ${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
      tmux select-pane -t "${session}:0.2" -T "#2 ${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    elif [ $cnt -ge 3 ]; then
      tmux select-pane -t "${session}:0.0" -T "#1 ${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
      tmux select-pane -t "${session}:0.1" -T "#3 ${_yolo_icons[3]} ${(U)_yolo_opts[3]}"
      tmux select-pane -t "${session}:0.2" -T "#2 ${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    fi
  fi

  # ── pane border styling ──
  tmux set-option -t "$session" pane-border-status top 2>/dev/null
  tmux set-option -t "$session" pane-border-style "fg=colour240" 2>/dev/null
  tmux set-option -t "$session" pane-active-border-style "fg=colour141" 2>/dev/null
  tmux set-option -t "$session" pane-border-format \
    " #{?pane_active,#[fg=colour220]⚡,#[fg=colour240]·} #[fg=colour255,bold]#{pane_title} " 2>/dev/null

  # ── tmux status bar ──
  local mode_status_label
  case "$mode" in
    parallel)      mode_status_label="⚡ PARALLEL" ;;
    sequential)    mode_status_label="➡️  SEQUENTIAL" ;;
    collaborative) mode_status_label="🤝 COLLAB" ;;
  esac

  tmux set-option -t "$session" status on 2>/dev/null
  tmux set-option -t "$session" status-style "bg=colour235,fg=colour255" 2>/dev/null
  tmux set-option -t "$session" status-left-length 50 2>/dev/null
  tmux set-option -t "$session" status-right-length 120 2>/dev/null
  tmux set-option -t "$session" status-left \
    " #[fg=colour196,bold]⚔️  BATTLE#[default] #[fg=colour240]│#[default] #[fg=colour220]${mode_status_label}#[default]  " 2>/dev/null
  tmux set-option -t "$session" status-right " #[fg=colour240]starting...#[default] " 2>/dev/null
  tmux set-option -t "$session" status-justify centre 2>/dev/null
  tmux set-option -t "$session" window-status-current-format "" 2>/dev/null
  tmux set-option -t "$session" window-status-format "" 2>/dev/null

  # ── keybindings ──
  tmux bind-key -T prefix S set-window-option synchronize-panes \; \
    display-message "#{?synchronize-panes,🔗 Sync ON - typing goes to ALL panes,🔓 Sync OFF}" 2>/dev/null

  # ── status bar monitor ──
  local monitor="$tmpdir/monitor.sh"
  {
    echo '#!/bin/zsh'
    echo "session=\"$session\""
    echo "tmpdir=\"$tmpdir\""
    echo "mode=\"$mode\""
    echo ""
    echo "tool_names=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_yolo_opts[$j]}\""; done
    echo ")"
    echo "tool_icons=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_yolo_icons[$j]}\""; done
    echo ")"

    cat << 'MONITOR_BODY'

frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
tick=0

while tmux has-session -t "$session" 2>/dev/null; do
  tick=$(( tick + 1 ))
  fidx=$(( (tick % ${#frames[@]}) + 1 ))
  spin="${frames[$fidx]}"

  all_done=true
  any_running=false
  status_parts=()

  for ((k=1; k<=${#tool_names[@]}; k++)); do
    tname="${tool_names[$k]}"
    ticon="${tool_icons[$k]}"
    sfile="$tmpdir/status_${tname}"

    if [ -f "$sfile" ]; then
      content=$(cat "$sfile" 2>/dev/null)
      case "$content" in
        done:*)
          elapsed="${content#done:}"
          status_parts+=("#[fg=colour82,bold]${ticon} ${tname} ✔ ${elapsed}#[default]")
          ;;
        running)
          all_done=false
          any_running=true
          status_parts+=("#[fg=colour220,bold]${ticon} ${tname} ${spin}#[default]")
          ;;
        waiting)
          all_done=false
          status_parts+=("#[fg=colour245]${ticon} ${tname} ⏳#[default]")
          ;;
        *)
          all_done=false
          status_parts+=("#[fg=colour240]${ticon} ${tname} ·#[default]")
          ;;
      esac
    else
      all_done=false
      status_parts+=("#[fg=colour240]${ticon} ${tname} ·#[default]")
    fi
  done

  sep="#[fg=colour240] │ #[default]"
  right=""
  for ((k=1; k<=${#status_parts[@]}; k++)); do
    [ -n "$right" ] && right+="$sep"
    right+="${status_parts[$k]}"
  done

  if $all_done; then
    tmux set-option -t "$session" status-right \
      " ${right} ${sep}#[fg=colour82,bold]ALL DONE ✦#[default] " 2>/dev/null
    break
  fi

  tmux set-option -t "$session" status-right " ${right} " 2>/dev/null
  sleep 1
done
MONITOR_BODY
  } > "$monitor"
  chmod +x "$monitor"

  # launch monitor
  zsh "$monitor" &
  local monitor_pid=$!

  # focus on command center
  if [ $cnt -eq 2 ]; then
    tmux select-pane -t "${session}:0.1"
  elif [ $cnt -ge 3 ]; then
    tmux select-pane -t "${session}:0.3"
  fi

  tmux attach -t "$session"

  # cleanup
  kill $monitor_pid 2>/dev/null
  return 0
}
