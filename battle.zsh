#!/bin/zsh
# yolo battle - multi-agent battle mode
# Usage: yolo battle [-p|-s|-c] "prompt"
#   -p  parallel  (동시)   : broadcast same message to all AIs (chat/planning)
#   -s  sequential(순차)   : relay chain, each AI builds on previous (끝말잇기)
#   -c  collaborative(협동): split roles + git worktree isolation, no file conflicts (co-op) (default)

_yolo_battle() {
  # Receive context from parent yolo function via these globals:
  #   _yolo_opts, _yolo_icons, tcolors (arrays)
  #   reset, bold, dim, red, orange, yellow, green, cyan, blue, purple, pink, white (colors)

  # ── parse mode flag ──
  local mode="collaborative"
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

  # save initial git state for diff tracking
  git -C "$workdir" diff HEAD --stat > "$tmpdir/git_baseline.txt" 2>/dev/null
  git -C "$workdir" rev-parse HEAD > "$tmpdir/git_head.txt" 2>/dev/null

  local _is_restart=false
  while true; do
  # ── reset mode-dependent state for restart ──
  printf '%s' "$mode" > "$tmpdir/mode.txt"
  echo "0" > "$tmpdir/seq_turn.txt"
  rm -f "$tmpdir/seq_order_map.txt" "$tmpdir/run_"*.sh "$tmpdir/cmd_center.sh" "$tmpdir/monitor.sh" "$tmpdir/ai_panes.txt"
  rm -f "$tmpdir/status_"* "$tmpdir/diff_"*
  # cleanup previous worktrees on restart
  for _wt in "$tmpdir"/work_*; do
    [ -d "$_wt" ] && git -C "$workdir" worktree remove "$_wt" 2>/dev/null
  done
  for _br in $(git -C "$workdir" branch --list "battle-coop-*" 2>/dev/null); do
    git -C "$workdir" branch -D "$_br" 2>/dev/null
  done

  # ── role definitions for co-op mode (file-scoped to avoid conflicts) ──
  local -a _roles _role_prompts
  _roles=("Core" "Tests" "Config")
  if [ -n "$prompt" ]; then
    _role_prompts=(
      "You are the core developer. Focus ONLY on main implementation/source code. Do NOT create or modify test files, config files, or documentation. Task: ${prompt}"
      "You are the test engineer. Write tests and test utilities ONLY. Do NOT modify any implementation/source code. Only create/edit files in test directories or files with test/spec in their name. Task: ${prompt}"
      "You are the DevOps/config engineer. Handle ONLY build config, documentation, CI/CD, and infrastructure files. Do NOT modify implementation code or test files. Task: ${prompt}"
    )
  fi

  # ── sequential mode: order selection ──
  _seq_order=()
  if [[ "$mode" == "sequential" ]] && [ -t 0 ] && ! $_is_restart; then
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

    # co-op mode: create git worktree for file isolation (no simultaneous writes)
    if [[ "$mode" == "collaborative" ]]; then
      git -C "$workdir" worktree add -q "$toolworkdir" -b "battle-coop-${tname}" HEAD 2>/dev/null || {
        printf "${yellow}  ⚠ worktree failed for ${tname}, using shared dir${reset}\n"
        mkdir -p "$toolworkdir"
      }
    else
      mkdir -p "$toolworkdir"
    fi

    {
      echo '#!/bin/zsh'
      echo "tmpdir=\"$tmpdir\""
      echo "statusfile=\"$tmpdir/status_${tname}\""
      echo "toolname=\"$tname\""
      echo "toolidx=$j"
      echo "mode=\"$mode\""
      echo "workdir=\"$workdir\""
      # tool_workdir: worktree path for co-op, main workdir for others
      if [[ "$mode" == "collaborative" ]]; then
        echo "tool_workdir=\"$toolworkdir\""
      else
        echo "tool_workdir=\"$workdir\""
      fi
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

      # collaborative mode: inject role variable early (needed by WAIT_LOGIC)
      if [[ "$mode" == "collaborative" ]]; then
        echo "collab_role=\"${_roles[$j]:-Developer}\""
        echo "collab_dev_tool=\"${_yolo_opts[1]}\""
      fi

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

  # ── inject previous AI's changes as context ──
  prev_diff_file="$tmpdir/diff_turn_$((my_turn - 1)).txt"
  if [ -f "$prev_diff_file" ] && [ -s "$prev_diff_file" ]; then
    printf '  \033[38;5;51m\033[1m📋 Previous AI changes:\033[0m\n'
    printf '  \033[2m%.60s...\033[0m\n' "$(head -1 "$prev_diff_file")"
    printf '  \033[2m(%d lines of diff)\033[0m\n\n' "$(wc -l < "$prev_diff_file")"
  fi
fi

# ── collaborative mode: all roles run simultaneously ──
WAIT_LOGIC

      # determine prompt based on mode
      echo 'prompt=$(cat "$tmpdir/prompt.txt")'
      echo ""

      # collaborative mode: set role prompt (before context inject so context appends to role prompt)
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

      # inject previous changes into prompt for sequential/collaborative mode
      cat << 'CONTEXT_INJECT'
if [[ "$mode" == "sequential" ]] && [ -n "$my_turn" ] && [ "$my_turn" -gt 1 ]; then
  prev_diff="$tmpdir/diff_turn_$((my_turn - 1)).txt"
  if [ -f "$prev_diff" ] && [ -s "$prev_diff" ]; then
    ctx=$(cat "$prev_diff")
    # truncate if too long (keep first 200 lines)
    if [ $(echo "$ctx" | wc -l) -gt 200 ]; then
      ctx="$(echo "$ctx" | head -200)"$'\n... (truncated)'
    fi
    prompt="${prompt}"$'\n\n'"[Context: Changes made by previous AI]"$'\n'"${ctx}"
  fi
fi

# collaborative mode: roles run simultaneously, no diff injection needed
CONTEXT_INJECT

      # mark as running + record start time + save git HEAD for diff tracking
      echo 'echo "running" > "$statusfile"'
      echo '_start_ts=$SECONDS'
      echo ""
      echo 'cd "$tool_workdir"'
      echo '_pre_head=$(git rev-parse HEAD 2>/dev/null)'

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

      # mark as done + capture diff + auto-commit
      cat << 'DONE_LOGIC'

_elapsed=$(( SECONDS - _start_ts ))
echo "done:${_elapsed}s" > "$statusfile"

# ── capture changes made by this AI (committed + uncommitted) ──
cd "$tool_workdir"

# first auto-commit any uncommitted changes
_uncommitted=$(git diff 2>/dev/null)
_staged=$(git diff --cached 2>/dev/null)
if [ -n "$_uncommitted" ] || [ -n "$_staged" ]; then
  printf '\n  \033[38;5;220m\033[1m💾 Auto-committing changes...\033[0m\n'
  git add -A 2>/dev/null
  git commit -m "battle(${toolname}): ${mode} mode changes

Prompt: $(head -1 "$tmpdir/prompt.txt" 2>/dev/null)
Mode: ${mode}
Tool: ${toolname}" 2>/dev/null

  if [ $? -eq 0 ]; then
    _commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
    printf '  \033[38;5;82m\033[1m✔ Committed: %s\033[0m\n' "$_commit_hash"
  else
    printf '  \033[2m  (nothing to commit)\033[0m\n'
  fi
fi

# diff from pre-head captures ALL changes (AI's own commits + auto-commit above)
_diff=""
_diff_stat=""
if [ -n "$_pre_head" ]; then
  _diff=$(git diff "$_pre_head"..HEAD 2>/dev/null)
  _diff_stat=$(git diff "$_pre_head"..HEAD --stat 2>/dev/null)
fi

if [ -n "$_diff" ]; then
  # save diff for next AI's context (끝말잇기: chain context to next AI)
  if [[ "$mode" == "sequential" ]] && [ -n "$my_turn" ]; then
    echo "$_diff" > "$tmpdir/diff_turn_${my_turn}.txt"
  fi
  # save diff by tool name (for collaborative mode review)
  echo "$_diff" > "$tmpdir/diff_${toolname}.txt"

  printf '\n  \033[38;5;51m\033[1m📊 Changes:\033[0m\n'
  echo "$_diff_stat" | while IFS= read -r line; do
    printf '  \033[2m  %s\033[0m\n' "$line"
  done
else
  printf '\n  \033[2m  (no changes detected)\033[0m\n'
fi

# sequential mode: auto-advance to next turn
if [[ "$mode" == "sequential" ]] && [ -n "$my_turn" ]; then
  next_turn=$(( my_turn + 1 ))
  echo "$next_turn" > "$tmpdir/seq_turn.txt"
  printf '\n  \033[38;5;220m\033[1m▶ 다음 턴 (#%s) 자동 시작\033[0m\n' "$next_turn"
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
      mode_label="CO-OP (협동)"
      mode_icon="🤝"
      mode_color="$green"
      ;;
  esac

  # ── launch banner ──
  if $_is_restart; then
    printf "\n  ${mode_color}${bold}${mode_icon} ${mode_label}${reset} ${dim}모드로 재시작합니다...${reset}\n\n"
    sleep 0.5
  else
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
  fi

  # ── help panel script (for split layouts) ──
  local help_script="$tmpdir/help_panel.sh"
  {
    echo '#!/bin/zsh'
    echo 'rst=$'"'"'\033[0m'"'"
    echo 'bld=$'"'"'\033[1m'"'"
    echo 'dm=$'"'"'\033[2m'"'"
    echo 'ylw=$'"'"'\033[38;5;220m'"'"
    echo 'grn=$'"'"'\033[38;5;82m'"'"
    echo 'cyn=$'"'"'\033[38;5;51m'"'"
    echo 'prp=$'"'"'\033[38;5;141m'"'"
    echo ""
    echo 'clear'
    echo 'printf "\n"'
    echo 'printf "  ${prp}${bld}╔════════════════════════════════╗${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${cyn}명령어${rst}                       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/status${rst}   각 AI 상태 확인   ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/diff${rst}     변경사항 확인     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/save${rst}     결과 저장         ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/prompt X${rst} 프롬프트 변경     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/focus N${rst}  N번 pane 포커스   ${prp}${bld}║${rst}\n"'

    if [[ "$mode" == "sequential" ]]; then
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}${bld}/next X${rst}   다음+프롬프트${cyn}★${rst} ${prp}${bld}║${rst}\n"'
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/skip${rst}     현재 AI 건너뛰기${prp}${bld}║${rst}\n"'
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/order N${rst}  순서 변경       ${prp}${bld}║${rst}\n"'
    fi

    if [[ "$mode" == "collaborative" ]]; then
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}${bld}/merge${rst}   브랜치 머지 ${cyn}★${rst}  ${prp}${bld}║${rst}\n"'
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/swap N M${rst} 역할 교체       ${prp}${bld}║${rst}\n"'
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/role N X${rst} 역할 변경       ${prp}${bld}║${rst}\n"'
      echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/roles${rst}    역할 확인        ${prp}${bld}║${rst}\n"'
    fi

    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/mode X${rst}   모드 변경 ${dm}(p/s/c)${rst}${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/help${rst}     도움말            ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/quit${rst}     세션 종료         ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${cyn}단축키${rst}                       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → 방향키${rst} pane 이동   ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → z${rst}     풀스크린     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → S${rst}     동기화       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → d${rst}     세션 나가기   ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╚════════════════════════════════╝${rst}\n"'

    # collaborative mode: show roles
    if [[ "$mode" == "collaborative" ]]; then
      echo 'printf "\n  ${grn}${bld}📋 역할 배정:${rst}\n"'
      for ((j=1; j<=$cnt; j++)); do
        echo "printf '   ${_yolo_icons[$j]} ${_yolo_opts[$j]}: ${_roles[$j]:-}\n'"
      done
    fi

    # sequential mode: show order
    if [[ "$mode" == "sequential" ]]; then
      echo 'printf "\n  ${cyn}${bld}📋 실행 순서:${rst}\n"'
      for ((j=1; j<=${#_seq_order[@]}; j++)); do
        local oi=${_seq_order[$j]}
        echo "printf '   ${j}) ${_yolo_icons[$oi]} ${_yolo_opts[$oi]}\n'"
      done
    fi

    echo ''
    echo '# keep alive'
    echo 'while true; do sleep 3600; done'
  } > "$help_script"
  chmod +x "$help_script"

  # ── command center script ──
  local cmd_script="$tmpdir/cmd_center.sh"
  {
    echo '#!/bin/zsh'
    echo "session=\"$session\""
    echo "tmpdir=\"$tmpdir\""
    echo "cnt=$cnt"
    echo "mode=\"$mode\""
    echo "savedir=\"$savedir\""
    echo "workdir=\"$workdir\""
    echo "has_help_pane=false"

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

# Ensure ZLE is loaded for vared and proper multibyte handling
zmodload zsh/zle 2>/dev/null

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

if [[ "$has_help_pane" == "true" ]]; then
  # compact header when help panel is separate
  printf "\n"
  printf "  ${prp}${bld}⌨️  COMMAND CENTER${rst}"
  case "$mode" in
    parallel)      printf "  ${ylw}${bld}⚡${rst} ${dm}동시${rst}" ;;
    sequential)    printf "  ${cyn}${bld}➡️${rst} ${dm}순차${rst}" ;;
    collaborative) printf "  ${grn}${bld}🤝${rst} ${dm}협동${rst}" ;;
  esac
  printf "\n  ${dm}텍스트 입력 → AI에 전송 │ /help 도움말${rst}\n\n"
else
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
      printf "  ${prp}${bld}║${rst}  ${dm}끝말잇기: 이전 결과 이어받기${rst}       ${prp}${bld}║${rst}\n"
      ;;
    collaborative)
      printf "  ${prp}${bld}║${rst}  ${grn}${bld}🤝 CO-OP${rst} ${dm}협동 모드${rst}                ${prp}${bld}║${rst}\n"
      printf "  ${prp}${bld}║${rst}  ${dm}역할분리 + worktree 격리${rst}           ${prp}${bld}║${rst}\n"
      ;;
  esac

  printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${cyn}명령어:${rst}                            ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/status${rst}    각 AI 상태 확인        ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/diff${rst}      각 AI 변경사항 확인   ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/save${rst}      결과 저장              ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/prompt X${rst}  프롬프트 변경          ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/focus N${rst}   N번 pane 포커스        ${prp}${bld}║${rst}\n"

  if [[ "$mode" == "sequential" ]]; then
    printf "  ${prp}${bld}║${rst}   ${ylw}${bld}/next X${rst}    다음+새프롬프트${cyn}★${rst}    ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}   ${ylw}/skip${rst}      현재 AI 건너뛰기     ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}   ${ylw}/order N..${rst} 순서 변경 ${dm}(예:2 1 3)${rst}${prp}${bld}║${rst}\n"
  fi

  if [[ "$mode" == "collaborative" ]]; then
    printf "  ${prp}${bld}║${rst}   ${ylw}${bld}/merge${rst}    브랜치 머지 ${cyn}★${rst}        ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}   ${ylw}/swap N M${rst}  N↔M 역할 교체        ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}   ${ylw}/role N X${rst}  N번 AI 역할 변경     ${prp}${bld}║${rst}\n"
    printf "  ${prp}${bld}║${rst}   ${ylw}/roles${rst}     현재 역할 확인        ${prp}${bld}║${rst}\n"
  fi

  printf "  ${prp}${bld}║${rst}   ${ylw}/mode X${rst}    모드 변경 ${dm}(p/s/c)${rst}   ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/help${rst}      도움말                ${prp}${bld}║${rst}\n"
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
fi

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

_send_to_pane() {
  local pane="$1"
  local tool="$2"
  local text="$3"
  # Use -l for literal string (better for multibyte)
  tmux send-keys -t "${pane}" -l "$text" 2>/dev/null
  case "$tool" in
    gemini)
      # Gemini CLI needs multiple enters to submit
      tmux send-keys -t "${pane}" Enter Enter Enter 2>/dev/null
      ;;
    codex)
      # Codex CLI needs double enter to submit
      tmux send-keys -t "${pane}" Enter Enter 2>/dev/null
      ;;
    *)
      tmux send-keys -t "${pane}" Enter 2>/dev/null
      ;;
  esac
}

_show_diffs() {
  printf "\n"
  local has_diff=false
  for ((di=1; di<=${#_cmd_tools[@]}; di++)); do
    local dname="${_cmd_tools[$di]}"
    local dicon="${_cmd_icons[$di]}"
    local dfile="$tmpdir/diff_${dname}.txt"
    if [ -f "$dfile" ] && [ -s "$dfile" ]; then
      has_diff=true
      local dlines=$(wc -l < "$dfile" | tr -d ' ')
      printf "  ${cyn}${bld}${dicon} ${dname}${rst} ${dm}(${dlines} lines)${rst}\n"
      # show colorized diff preview (first 20 lines)
      head -20 "$dfile" | while IFS= read -r dline; do
        case "$dline" in
          +*) printf "    ${grn}%s${rst}\n" "$dline" ;;
          -*) printf "    ${red}%s${rst}\n" "$dline" ;;
          @@*) printf "    ${cyn}%s${rst}\n" "$dline" ;;
          *)  printf "    ${dm}%s${rst}\n" "$dline" ;;
        esac
      done
      [ "$dlines" -gt 20 ] && printf "    ${dm}... (+$((dlines - 20)) more lines)${rst}\n"
      printf "\n"
    else
      printf "  ${dm}${dicon} ${dname}: (변경 없음)${rst}\n"
    fi
  done
  # also show current uncommitted changes
  local live_diff=$(git -C "$workdir" diff --stat 2>/dev/null)
  if [ -n "$live_diff" ]; then
    printf "  ${ylw}${bld}📊 현재 uncommitted 변경:${rst}\n"
    echo "$live_diff" | while IFS= read -r sl; do
      printf "    ${dm}%s${rst}\n" "$sl"
    done
    printf "\n"
  fi
  if ! $has_diff; then
    printf "  ${dm}아직 변경사항이 없습니다${rst}\n\n"
  fi
}

_do_save() {
  mkdir -p "$savedir"
  # capture each AI pane's output
  for ((si=0; si<${#ai_panes[@]}; si++)); do
    local pidx="${ai_panes[$((si+1))]}"
    local tname="${_cmd_tools[$((si+1))]}"
    tmux capture-pane -t "${pidx}" -p -S -500 > "$savedir/${tname}.txt" 2>/dev/null
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
  local new_prompt="$*"
  local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  local next=$(( cur + 1 ))
  if [ $next -gt ${#_cmd_seq_order[@]} ]; then
    printf "  ${grn}${bld}✔ 모든 AI가 완료되었습니다${rst}\n"
    return
  fi
  # 끝말잇기: update prompt for next AI if provided
  if [ -n "$new_prompt" ]; then
    printf '%s' "$new_prompt" > "$tmpdir/prompt.txt"
    printf "  ${ylw}📝 새 프롬프트:${rst} ${dm}${new_prompt}${rst}\n"
  fi
  echo "$next" > "$tmpdir/seq_turn.txt"
  local next_tool_idx=${_cmd_seq_order[$next]}
  printf "  ${cyn}${bld}▶ #${next} ${_cmd_icons[$next_tool_idx]} ${_cmd_tools[$next_tool_idx]} 시작${rst}\n"
  if [ -n "$new_prompt" ]; then
    printf "  ${dm}(이전 AI 변경사항 + 새 프롬프트 전달됨)${rst}\n"
  else
    printf "  ${dm}(이전 AI 변경사항 + 기존 프롬프트 전달됨)${rst}\n"
  fi
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

_do_swap() {
  if [[ "$mode" != "collaborative" ]]; then
    printf "  ${red}협동 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local a=$1 b=$2
  if [[ ! "$a" =~ ^[0-9]+$ ]] || [[ ! "$b" =~ ^[0-9]+$ ]] || \
     [ "$a" -lt 1 ] || [ "$a" -gt ${#_cmd_tools[@]} ] || \
     [ "$b" -lt 1 ] || [ "$b" -gt ${#_cmd_tools[@]} ] || \
     [ "$a" -eq "$b" ]; then
    printf "  ${red}사용법: /swap N M (1~${#_cmd_tools[@]}, N≠M)${rst}\n"
    return
  fi
  local tmp_role="${_cmd_roles[$a]}"
  _cmd_roles[$a]="${_cmd_roles[$b]}"
  _cmd_roles[$b]="$tmp_role"
  tmux select-pane -t "${ai_panes[$a]}" -T "${_cmd_icons[$a]} ${(U)_cmd_tools[$a]} (${_cmd_roles[$a]})" 2>/dev/null
  tmux select-pane -t "${ai_panes[$b]}" -T "${_cmd_icons[$b]} ${(U)_cmd_tools[$b]} (${_cmd_roles[$b]})" 2>/dev/null
  printf "  ${grn}${bld}✔ 역할 교체:${rst} ${_cmd_icons[$a]} ${_cmd_tools[$a]}=${ylw}${_cmd_roles[$a]}${rst} ↔ ${_cmd_icons[$b]} ${_cmd_tools[$b]}=${ylw}${_cmd_roles[$b]}${rst}\n"
}

_do_reorder() {
  if [[ "$mode" != "sequential" ]]; then
    printf "  ${red}순차 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local -a new_order
  new_order=( $@ )
  if [ ${#new_order[@]} -ne ${#_cmd_seq_order[@]} ]; then
    printf "  ${red}사용법: /order 2 1 3 (모든 번호 필요)${rst}\n"
    return
  fi
  local valid=true
  for ((oi=1; oi<=${#_cmd_seq_order[@]}; oi++)); do
    local found=false
    for v in "${new_order[@]}"; do
      [ "$v" = "$oi" ] && found=true
    done
    $found || valid=false
  done
  if ! $valid; then
    printf "  ${red}1~${#_cmd_seq_order[@]} 사이 숫자를 모두 입력하세요${rst}\n"
    return
  fi
  _cmd_seq_order=( "${new_order[@]}" )
  echo "1" > "$tmpdir/seq_turn.txt"
  for ((oi=1; oi<=${#_cmd_seq_order[@]}; oi++)); do
    local tidx=${_cmd_seq_order[$oi]}
    tmux select-pane -t "${ai_panes[$tidx]}" -T "#${oi} ${_cmd_icons[$tidx]} ${(U)_cmd_tools[$tidx]}" 2>/dev/null
  done
  printf "  ${grn}${bld}✔ 순서 변경:${rst} "
  for ((oi=1; oi<=${#_cmd_seq_order[@]}; oi++)); do
    local tidx=${_cmd_seq_order[$oi]}
    [ $oi -gt 1 ] && printf " ${dm}→${rst} "
    printf "${_cmd_icons[$tidx]} ${_cmd_tools[$tidx]}"
  done
  printf "\n  ${ylw}${bld}▶ #1부터 재시작${rst}\n"
}

_do_mode_switch() {
  local new_mode="$1"
  local mode_ok=false

  case "$new_mode" in
    p|parallel)      new_mode="parallel"; mode_ok=true ;;
    s|sequential)    new_mode="sequential"; mode_ok=true ;;
    c|collaborative) new_mode="collaborative"; mode_ok=true ;;
  esac

  if ! $mode_ok; then
    printf "  ${red}알 수 없는 모드: ${new_mode}${rst}\n"
    printf "  ${dm}사용 가능: p(parallel) s(sequential) c(collaborative)${rst}\n"
    return
  fi

  if [[ "$mode" == "$new_mode" ]]; then
    printf "  ${ylw}이미 ${new_mode} 모드입니다${rst}\n"
    return
  fi

  printf "  ${ylw}${bld}⚡ ${new_mode} 모드로 전환 중... 세션을 재시작합니다${rst}\n"
  sleep 1
  printf '%s' "$new_mode" > "$tmpdir/new_mode.txt"
  tmux kill-session -t "$session" 2>/dev/null
}

_do_merge() {
  if [[ "$mode" != "collaborative" ]]; then
    printf "  ${red}co-op 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  cd "$workdir"
  local merged=0 conflicts=0
  printf "\n  ${cyn}${bld}🔀 Co-op 브랜치 머지 시작${rst}\n"
  for ((mi=1; mi<=${#_cmd_tools[@]}; mi++)); do
    local branch="battle-coop-${_cmd_tools[$mi]}"
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      # check if branch has changes
      local branch_diff=$(git diff HEAD..."$branch" --stat 2>/dev/null)
      if [ -z "$branch_diff" ]; then
        printf "  ${dm}${_cmd_icons[$mi]} ${_cmd_tools[$mi]}: (변경 없음)${rst}\n"
        continue
      fi
      printf "  ${cyn}${_cmd_icons[$mi]} ${_cmd_tools[$mi]} 머지 중...${rst}"
      if git merge --no-edit "$branch" 2>/dev/null; then
        printf " ${grn}✔${rst}\n"
        merged=$((merged + 1))
      else
        printf " ${red}✖ 충돌!${rst}\n"
        git merge --abort 2>/dev/null
        conflicts=$((conflicts + 1))
        printf "  ${dm}  수동 머지 필요: git merge ${branch}${rst}\n"
      fi
    fi
  done
  printf "\n  ${grn}${bld}✔ 머지 완료: ${merged}개${rst}"
  [ $conflicts -gt 0 ] && printf "  ${red}${bld}✖ 충돌: ${conflicts}개${rst}"
  printf "\n"
  # cleanup worktrees (keep branches in case of conflict)
  if [ $conflicts -eq 0 ]; then
    for ((mi=1; mi<=${#_cmd_tools[@]}; mi++)); do
      local tname="${_cmd_tools[$mi]}"
      git worktree remove "$tmpdir/work_${tname}" 2>/dev/null
      git branch -D "battle-coop-${tname}" 2>/dev/null
    done
    printf "  ${dm}워크트리 정리 완료${rst}\n"
  else
    printf "  ${ylw}충돌 브랜치는 수동 머지 후 정리하세요${rst}\n"
  fi
  printf "\n"
}

# sequential mode: auto-start first AI
if [[ "$mode" == "sequential" ]]; then
  echo "1" > "$tmpdir/seq_turn.txt"
fi

# better line editing for multibyte input (e.g., Korean)
setopt multibyte 2>/dev/null
stty erase '^?' 2>/dev/null
# bind both DEL (^?) and BS (^H) for backspace compatibility across terminals/tmux
bindkey '^?' backward-delete-char 2>/dev/null
bindkey '^H' backward-delete-char 2>/dev/null
bindkey '\b' backward-delete-char 2>/dev/null

# ensure correct terminal width for vared line wrapping
COLUMNS=$(tput cols 2>/dev/null || echo 80)
trap 'COLUMNS=$(tput cols 2>/dev/null || echo 80)' WINCH

# ── command history + arrow key widgets ──
typeset -a _cmd_history
_cmd_hist_idx=0

_cmd_hist_up() {
  if (( _cmd_hist_idx < ${#_cmd_history[@]} )); then
    (( _cmd_hist_idx++ ))
    BUFFER="${_cmd_history[-$_cmd_hist_idx]}"
    CURSOR=${#BUFFER}
  fi
}
zle -N _cmd_hist_up

_cmd_hist_down() {
  if (( _cmd_hist_idx > 0 )); then
    (( _cmd_hist_idx-- ))
    if (( _cmd_hist_idx == 0 )); then
      BUFFER=""
    else
      BUFFER="${_cmd_history[-$_cmd_hist_idx]}"
    fi
    CURSOR=${#BUFFER}
  else
    BUFFER=""
    CURSOR=0
  fi
}
zle -N _cmd_hist_down

# kill whole line widget (Ctrl-U)
_cmd_kill_line() {
  BUFFER=""
  CURSOR=0
}
zle -N _cmd_kill_line

bindkey '^[[A' _cmd_hist_up     # Up arrow
bindkey '^[OA' _cmd_hist_up     # Up arrow (alt escape)
bindkey '^[[B' _cmd_hist_down   # Down arrow
bindkey '^[OB' _cmd_hist_down   # Down arrow (alt escape)
bindkey '^U'   _cmd_kill_line   # Ctrl-U to clear line

# input loop
while true; do
  # Use vared for better multibyte/Korean input handling
  # %{...%} wraps non-printing chars so zle calculates cursor position correctly
  input=""
  if vared -p "  %{${prp}${bld}%}▸%{${rst}%} " -c input 2>/dev/null; then
    # clean up display artifacts from wrapped lines
    printf '\033[J'
  else
    # fallback if vared fails
    printf "  ${prp}${bld}▸${rst} "
    read -r input || break
  fi

  # save to history (non-empty input only)
  if [[ -n "$input" ]]; then
    _cmd_history+=("$input")
    _cmd_hist_idx=0
  fi

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
    /diff)
      _show_diffs
      ;;
    /next|/next\ *)
      local next_prompt="${input#/next}"
      next_prompt="${next_prompt# }"
      _do_next $next_prompt
      ;;
    /merge)
      _do_merge
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
    /role\ *)
      local role_args="${input#/role }"
      local role_num="${role_args%% *}"
      local role_name="${role_args#* }"
      if [[ "$mode" != "collaborative" ]]; then
        printf "  ${red}협동 모드에서만 사용 가능합니다${rst}\n"
      elif [[ ! "$role_num" =~ ^[0-9]+$ ]] || [ "$role_num" -lt 1 ] || [ "$role_num" -gt ${#_cmd_tools[@]} ]; then
        printf "  ${red}잘못된 번호. 1~${#_cmd_tools[@]} 사이 입력${rst}\n"
      elif [[ "$role_num" == "$role_name" ]]; then
        printf "  ${red}사용법: /role N 역할명${rst}\n"
      else
        _cmd_roles[$role_num]="$role_name"
        tmux select-pane -t "${ai_panes[$role_num]}" -T "${_cmd_icons[$role_num]} ${(U)_cmd_tools[$role_num]} (${role_name})" 2>/dev/null
        printf "  ${grn}${bld}✔ ${_cmd_icons[$role_num]} ${_cmd_tools[$role_num]} 역할 변경:${rst} ${ylw}${role_name}${rst}\n"
      fi
      ;;
    /roles)
      if [[ "$mode" != "collaborative" ]]; then
        printf "  ${red}협동 모드에서만 사용 가능합니다${rst}\n"
      else
        printf "\n  ${grn}${bld}📋 현재 역할 배정:${rst}\n"
        for ((ri=1; ri<=${#_cmd_tools[@]}; ri++)); do
          printf "   ${ylw}%d)${rst} ${_cmd_icons[$ri]} ${_cmd_tools[$ri]}: ${ylw}${_cmd_roles[$ri]}${rst}\n" "$ri"
        done
        printf "\n"
      fi
      ;;
    /swap\ *)
      local swap_args="${input#/swap }"
      local swap_a="${swap_args%% *}"
      local swap_b="${swap_args##* }"
      _do_swap "$swap_a" "$swap_b"
      ;;
    /order\ *)
      local order_args="${input#/order }"
      _do_reorder ${=order_args}
      ;;
    /mode\ *)
      local new_mode="${input#/mode }"
      _do_mode_switch "$new_mode"
      ;;
    /help)
      printf "\n  ${ylw}/status${rst}  상태  ${ylw}/diff${rst}  변경사항  ${ylw}/save${rst}  저장\n"
      printf "  ${ylw}/next X${rst} 다음+프롬프트  ${ylw}/skip${rst} 건너뛰기\n"
      printf "  ${ylw}/merge${rst}  co-op 머지  ${ylw}/prompt X${rst} 프롬프트 변경\n"
      printf "  ${ylw}/focus N${rst} 포커스  ${ylw}/quit${rst}  종료\n"
      printf "  ${ylw}/mode p${rst}  동시  ${ylw}/mode s${rst}  순차  ${ylw}/mode c${rst}  co-op\n"
      printf "  ${ylw}/swap N M${rst} 역할교체  ${ylw}/order N..${rst} 순서변경\n"
      printf "  ${ylw}/role N X${rst} 역할변경  ${ylw}/roles${rst}  역할확인\n"
      printf "  ${dm}↑/↓ 화살표: 이전 입력 / 지우기${rst}\n\n"
      ;;
    /*)
      # unrecognized / command - do NOT forward to AI
      printf "  ${red}알 수 없는 명령어: ${input}${rst}  ${dm}/help 참고${rst}\n"
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
          _send_to_pane "${target_pane}" "${_cmd_tools[$cur_tool_idx]}" "$input"
          printf "  ${dm}→ ${_cmd_icons[$cur_tool_idx]} ${_cmd_tools[$cur_tool_idx]}에 전송됨${rst}\n"
        else
          printf "  ${red}현재 활성 AI가 없습니다${rst}\n"
        fi
      else
        # parallel & collaborative: broadcast to all
        for ((pi=1; pi<=${#ai_panes[@]}; pi++)); do
          _send_to_pane "${ai_panes[$pi]}" "${_cmd_tools[$pi]}" "$input"
        done
        printf "  ${dm}→ ${#ai_panes[@]}개 AI에 전송됨${rst}\n"
      fi
      ;;
  esac
done
CMD_BODY
  } > "$cmd_script"
  chmod +x "$cmd_script"

  # ── layout selection for 3+ tools ──
  local _layout_choice="top3"
  if [ $cnt -ge 3 ] && [ -t 0 ] && ! $_is_restart; then
    printf "\n"
    printf "  ${cyan}${bold}📐 레이아웃 선택${reset}\n"
    printf "  ${dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    printf "   ${white}${bold}1)${reset} 위 3개 + 아래 커맨드\n"
    printf "      ${dim}┌──────┬──────┬──────┐${reset}\n"
    printf "      ${dim}│ AI 1 │ AI 2 │ AI 3 │${reset}\n"
    printf "      ${dim}├──────┴──────┴──────┤${reset}\n"
    printf "      ${dim}│    ⌨️  COMMAND      │${reset}\n"
    printf "      ${dim}└────────────────────┘${reset}\n"
    printf "   ${white}${bold}2)${reset} 타일 (2x2 그리드)\n"
    printf "      ${dim}┌──────┬──────┐${reset}\n"
    printf "      ${dim}│ AI 1 │ AI 2 │${reset}\n"
    printf "      ${dim}├──────┼──────┤${reset}\n"
    printf "      ${dim}│ AI 3 │ CMD  │${reset}\n"
    printf "      ${dim}└──────┴──────┘${reset}\n"
    printf "  ${dim}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    printf "  ${yellow}선택${reset} [${dim}기본: 1${reset}]: "
    local _layout_input
    read -r _layout_input
    case "$_layout_input" in
      2) _layout_choice="tiled" ;;
      *) _layout_choice="top3" ;;
    esac
    printf "\n"
  fi

  # ── create tmux session ──
  # Use stable pane IDs (%N) instead of positional indices to avoid renumbering bugs
  tmux kill-session -t "$session" 2>/dev/null
  local -a _ai_pane_ids
  local _cmd_pane_id

  if [ $cnt -eq 2 ]; then
    # ┌──────────┬──────────┐
    # │  tool1   │  tool2   │
    # ├──────────┼──────────┤
    # │ ⌨️ INPUT  │ 📋 HELP  │
    # └──────────┴──────────┘
    sed -i '' 's/has_help_pane=false/has_help_pane=true/' "$cmd_script"
    tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
    _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
    tmux split-window -v -t "${_ai_pane_ids[1]}" -p 30 "zsh ${cmd_script}"
    _cmd_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
    tmux split-window -h -t "${_ai_pane_ids[1]}" -p 50 "zsh ${_battle_scripts[2]}"
    _ai_pane_ids[2]=$(tmux display-message -t "${session}" -p '#{pane_id}')
    tmux split-window -h -t "${_cmd_pane_id}" -p 45 "zsh ${help_script}"
    local _help_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
    echo "${_ai_pane_ids[1]} ${_ai_pane_ids[2]}" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${_ai_pane_ids[1]}" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${_ai_pane_ids[2]}" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND"
    tmux select-pane -t "${_help_pane_id}" -T "📋 GUIDE"
  elif [ $cnt -ge 3 ]; then
    if [[ "$_layout_choice" == "top3" ]]; then
      # ┌──────┬──────┬──────┐
      # │tool1 │tool2 │tool3 │
      # ├──────────┬─────────┤
      # │ ⌨️ INPUT  │ 📋 HELP │
      # └──────────┴─────────┘
      sed -i '' 's/has_help_pane=false/has_help_pane=true/' "$cmd_script"
      tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
      _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -v -t "${_ai_pane_ids[1]}" -p 30 "zsh ${cmd_script}"
      _cmd_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -h -t "${_ai_pane_ids[1]}" -p 67 "zsh ${_battle_scripts[2]}"
      _ai_pane_ids[2]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -h -t "${_ai_pane_ids[2]}" -p 50 "zsh ${_battle_scripts[3]}"
      _ai_pane_ids[3]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -h -t "${_cmd_pane_id}" -p 45 "zsh ${help_script}"
      local _help_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND"
      tmux select-pane -t "${_help_pane_id}" -T "📋 GUIDE"
    else
      # ┌──────────┬──────────┐
      # │  tool1   │  tool2   │
      # ├──────────┼──────────┤
      # │  tool3   │ ⌨️ CMD   │
      # └──────────┴──────────┘
      tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
      _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -h -t "${_ai_pane_ids[1]}" -p 50 "zsh ${_battle_scripts[2]}"
      _ai_pane_ids[2]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -v -t "${_ai_pane_ids[1]}" -p 50 "zsh ${_battle_scripts[3]}"
      _ai_pane_ids[3]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      tmux split-window -v -t "${_ai_pane_ids[2]}" -p 50 "zsh ${cmd_script}"
      _cmd_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
    fi
    echo "${_ai_pane_ids[1]} ${_ai_pane_ids[2]} ${_ai_pane_ids[3]}" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${_ai_pane_ids[1]}" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${_ai_pane_ids[2]}" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${_ai_pane_ids[3]}" -T "${_yolo_icons[3]} ${(U)_yolo_opts[3]}"
    if [[ "$_layout_choice" != "top3" ]]; then
      tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND CENTER"
    fi
  fi

  # collaborative mode: add role to pane titles
  if [[ "$mode" == "collaborative" ]]; then
    for ((j=1; j<=$cnt; j++)); do
      tmux select-pane -t "${_ai_pane_ids[$j]}" -T "${_yolo_icons[$j]} ${(U)_yolo_opts[$j]} (${_roles[$j]})"
    done
  fi

  # sequential mode: add order numbers to pane titles
  if [[ "$mode" == "sequential" ]]; then
    for ((j=1; j<=$cnt; j++)); do
      tmux select-pane -t "${_ai_pane_ids[$j]}" -T "#${j} ${_yolo_icons[$j]} ${(U)_yolo_opts[$j]}"
    done
  fi

  # ── mouse support ──
  tmux set-option -t "$session" mouse on 2>/dev/null

  # ── layout protection ──
  # Prevent AI TUIs (claude, gemini, codex) from resizing panes
  tmux set-option -t "$session" aggressive-resize on 2>/dev/null
  # Disable passthrough escape sequences that could trigger resize
  tmux set-option -t "$session" allow-passthrough off 2>/dev/null
  # Lock pane sizes: ignore resize requests from applications inside panes
  for _pid in "${_ai_pane_ids[@]}" "$_cmd_pane_id"; do
    tmux set-option -p -t "$_pid" remain-on-exit on 2>/dev/null
  done
  # Set fixed layout after all panes are created
  tmux select-layout -t "${session}:0" -E 2>/dev/null

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
    collaborative) mode_status_label="🤝 CO-OP" ;;
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
  tmux select-pane -t "${_cmd_pane_id}"

  tmux attach -t "$session"

  # cleanup
  kill $monitor_pid 2>/dev/null

  # cleanup co-op worktrees (if not already merged)
  for _wt in "$tmpdir"/work_*; do
    [ -d "$_wt" ] && git -C "$workdir" worktree remove "$_wt" 2>/dev/null
  done

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
