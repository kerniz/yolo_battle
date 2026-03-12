#!/bin/zsh
# ════════════════════════════════════════
# scriptgen.zsh — Script generation (run_*.sh, help, cmd_center, monitor)
# Sourced by battle.zsh (parent context)
# ════════════════════════════════════════

# ── generate per-AI run scripts ──
_battle_gen_tool_scripts() {
  _battle_scripts=()

  for ((j=1; j<=$cnt; j++)); do
    local tname="${_yolo_opts[$j]}"
    local ticon="${_yolo_icons[$j]}"
    local script="$tmpdir/run_${tname}.sh"
    local toolworkdir="$tmpdir/work_${tname}"

    # co-op mode: create git worktree for file isolation
    if [[ "$mode" == "collaborative" ]]; then
      local _wt_ok=false
      if $_coop_use_worktree; then
        local _old_wt
        _old_wt=$(git -C "$workdir" worktree list --porcelain 2>/dev/null | grep -B1 "branch.*battle-coop-${tname}$" | head -1 | sed 's/^worktree //')
        if [ -n "$_old_wt" ] && [ "$_old_wt" != "$toolworkdir" ]; then
          git -C "$workdir" worktree remove --force "$_old_wt" 2>/dev/null
        fi
        git -C "$workdir" worktree prune 2>/dev/null
        git -C "$workdir" branch -D "battle-coop-${tname}" 2>/dev/null

        if git -C "$workdir" worktree add -f -q "$toolworkdir" -b "battle-coop-${tname}" HEAD 2>/dev/null; then
          _wt_ok=true
        else
          printf "${yellow}  ⚠ worktree failed for ${tname}, using shared dir${reset}\n"
        fi
      fi

      if ! $_wt_ok; then
        rm -rf "$toolworkdir" 2>/dev/null
        ln -s "$workdir" "$toolworkdir"
      fi
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

      # inject role variable if mode has roles
      if [ ${#_roles[@]} -gt 0 ]; then
        echo "collab_role=\"${_roles[$j]:-Developer}\""
        echo "collab_dev_tool=\"${_yolo_opts[1]}\""
      fi

      _mode_gen_wait_logic

      echo 'prompt=$(cat "$tmpdir/prompt.txt")'
      echo ""

      _mode_prompt_inject "$tmpdir"
      echo ""

      if [ ${#_roles[@]} -gt 0 ]; then
        local role="${_roles[$j]:-Developer}"
        local rprompt="${_role_prompts[$j]}"
        echo "role=\"$role\""
        echo "printf '  \\033[38;5;220m\\033[1m📋 Role: ${role}\\033[0m\\n\\n'"
        if [ -n "$rprompt" ]; then
          printf '%s' "$rprompt" > "$tmpdir/role_prompt_${tname}.txt"
          echo "prompt=\$(cat \"$tmpdir/role_prompt_${tname}.txt\")"
        fi
      fi

      echo 'echo "running" > "$statusfile"'
      echo '_start_ts=$SECONDS'
      echo ""
      echo 'cd "$tool_workdir"'
      echo '_pre_head=$(git rev-parse HEAD 2>/dev/null)'

      cat << 'RUN_TOOL'
if [ -n "$prompt" ]; then
  case "$toolname" in
    claude) claude --dangerously-skip-permissions -- "$prompt" ;;
    gemini) gemini --yolo -- "$prompt" ;;
    codex)  codex --sandbox danger-full-access --ask-for-approval never -- "$prompt" ;;
  esac
else
  case "$toolname" in
    claude) claude --dangerously-skip-permissions ;;
    gemini) gemini --yolo ;;
    codex)  codex --sandbox danger-full-access --ask-for-approval never ;;
  esac
fi
RUN_TOOL

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

Mode: ${mode}
Tool: ${toolname}" 2>/dev/null

  if [ $? -eq 0 ]; then
    _commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
    printf '  \033[38;5;82m\033[1m✔ Committed: %s\033[0m\n' "$_commit_hash"
  else
    printf '  \033[2m  (nothing to commit)\033[0m\n'
  fi
fi

# diff from pre-head captures ALL changes
_diff=""
_diff_stat=""
if [ -n "$_pre_head" ]; then
  _diff=$(git diff "$_pre_head"..HEAD 2>/dev/null)
  _diff_stat=$(git diff "$_pre_head"..HEAD --stat 2>/dev/null)
fi

if [ -n "$_diff" ]; then
  echo "$_diff" > "$tmpdir/diff_${toolname}.txt"
  printf '\n  \033[38;5;51m\033[1m📊 Changes:\033[0m\n'
  echo "$_diff_stat" | while IFS= read -r line; do
    printf '  \033[2m  %s\033[0m\n' "$line"
  done
else
  printf '\n  \033[2m  (no changes detected)\033[0m\n'
fi

DONE_LOGIC

      _mode_gen_done_logic

      cat << 'DONE_END'
printf '\n  \033[2m[AI 프로세스 종료됨]\033[0m\n'
# keep pane alive to prevent tmux session termination
while true; do sleep 3600; done
DONE_END
    } > "$script"
    chmod +x "$script"
    _battle_scripts+=("$script")
  done
}

# ── generate launch banner ──
_battle_gen_banner() {
  local mode_label="$_mode_label"
  local mode_icon="$_mode_icon"
  local mode_color="${(P)_mode_color_name}"

  if $_is_restart; then
    printf "\n  ${mode_color}${bold}${mode_icon} ${mode_label}${reset} ${dim}모드로 재시작합니다...${reset}\n\n"
    sleep 0.5
  else
    printf "\n"
    printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${red}${bold}${blink}⚔️${reset}  ${red}${bold}Y O L O   B A T T L E${reset} ${red}${bold}${blink}⚔️${reset}        ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${mode_color}${bold}${mode_icon} ${mode_label}${reset}%-$((21 - ${#mode_label}))s${purple}${bold}║${reset}\n" ""
    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    for ((j=1; j<=$cnt; j++)); do
      local extra=$(_mode_banner_extra "$j")
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
}

# ── generate help panel script ──
_battle_gen_help_panel() {
  help_script="$tmpdir/help_panel.sh"
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
    echo "cnt=$cnt"
    echo -n "_yolo_opts=( "
    for v in "${_yolo_opts[@]}"; do printf "'%s' " "$v"; done
    echo ")"
    echo -n "_yolo_icons=( "
    for v in "${_yolo_icons[@]}"; do printf "'%s' " "$v"; done
    echo ")"
    echo -n "_seq_order=( "
    for v in "${_seq_order[@]}"; do printf "'%s' " "$v"; done
    echo ")"
    echo -n "_roles=( "
    for v in "${_roles[@]}"; do printf "'%s' " "$v"; done
    echo ")"
    echo ""
    echo 'clear'
    echo 'printf "\n"'
    echo 'printf "  ${prp}${bld}┌───────────────────────────────────────────────────┐${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${cyn}${bld}📋  명령어${rst}                                        ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}├───────────────────────────────────────────────────┤${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/status${rst}  상태 확인    ${ylw}/diff${rst}     변경사항     ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/save${rst}    결과 저장    ${ylw}/ctx${rst}      컨텍스트     ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/focus N${rst} pane 포커스  ${ylw}/prompt X${rst} 프롬프트     ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/cat F${rst}   파일 비교    ${ylw}/grep P${rst}   파일 검색    ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/mode X${rst} 모드변경${dm}(p/s/c)${rst} ${ylw}/history${rst} 기록   ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/help${rst}    도움말       ${ylw}/quit${rst}     세션 종료    ${prp}${bld}│${rst}\n"'

    echo 'printf "  ${prp}${bld}├───────────────────────────────────────────────────┤${rst}\n"'
    _mode_help_commands

    echo 'printf "  ${prp}${bld}├───────────────────────────────────────────────────┤${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${cyn}${bld}⌨️  단축키${rst}                                       ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}├───────────────────────────────────────────────────┤${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}Ctrl+B →${rst} pane이동  ${ylw}Ctrl+B z${rst} 풀스크린    ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}│${rst}  ${ylw}Ctrl+B S${rst} 동기화    ${ylw}Ctrl+B d${rst} 나가기      ${prp}${bld}│${rst}\n"'
    echo 'printf "  ${prp}${bld}└───────────────────────────────────────────────────┘${rst}\n"'

    echo '_mode_help_info "$cnt" "${_yolo_opts[@]}" "${_yolo_icons[@]}" "${_seq_order[@]}" "${_roles[@]}"'

    echo ''
    echo '# keep alive'
    echo 'while true; do sleep 3600; done'
  } > "$help_script"
  chmod +x "$help_script"
}

# ── generate command center script ──
_battle_gen_cmd_center() {
  cmd_script="$tmpdir/cmd_center.sh"
  {
    echo '#!/bin/zsh'
    echo "session=\"$session\""
    echo "tmpdir=\"$tmpdir\""
    echo "cnt=$cnt"
    echo "mode=\"$mode\""
    echo "savedir=\"$savedir\""
    echo "workdir=\"$workdir\""
    echo "YOLO_DIR=\"${YOLO_DIR:-$HOME/.yolo}\""
    echo "has_help_pane=false"
    echo "source \"\${YOLO_DIR}/modes/\${mode}.zsh\""

    echo "_cmd_tools=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_yolo_opts[$j]}\""; done
    echo ")"
    echo "_cmd_icons=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_yolo_icons[$j]}\""; done
    echo ")"
    echo "_cmd_roles=("
    for ((j=1; j<=$cnt; j++)); do echo "  \"${_roles[$j]:-}\""; done
    echo ")"
    echo "_cmd_seq_order=("
    for ((j=1; j<=${#_seq_order[@]}; j++)); do echo "  ${_seq_order[$j]}"; done
    echo ")"

    cat << 'CMD_BODY'

# Ensure ZLE is loaded for vared and proper multibyte handling
zmodload zsh/zle 2>/dev/null

rst=$'\033[0m'; reset=$rst
bld=$'\033[1m'; bold=$bld
dm=$'\033[2m'; dim=$dm
red=$'\033[38;5;196m'
ylw=$'\033[38;5;220m'; yellow=$ylw
grn=$'\033[38;5;82m'; green=$grn
cyn=$'\033[38;5;51m'; cyan=$cyn
prp=$'\033[38;5;141m'; purple=$prp
wht=$'\033[38;5;255m'; white=$wht
org=$'\033[38;5;208m'; orange=$org

# wait for pane index file
while [ ! -f "$tmpdir/ai_panes.txt" ]; do sleep 0.1; done
ai_panes=( $(cat "$tmpdir/ai_panes.txt") )

# source modular lib files
source "${YOLO_DIR}/lib/cmd_helpers.zsh"
source "${YOLO_DIR}/lib/cmd_commands.zsh"
source "${YOLO_DIR}/lib/cmd_watchers.zsh"

clear

if [[ "$has_help_pane" == "true" ]]; then
  printf "\n"
  printf "  ${prp}${bld}⌨️  COMMAND CENTER${rst}"
  printf "  ${(P)_mode_color_name:-$white}${bld}${_mode_icon}${rst} ${dm}${_mode_label}${rst}"
  printf "\n  ${dm}텍스트 입력 → AI에 전송 │ /help 도움말${rst}\n\n"
else
  printf "\n"
  printf "  ${prp}${bld}┌──────────────────────────────────────┐${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${ylw}${bld}⌨️  C O M M A N D   C E N T E R${rst}    ${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}├──────────────────────────────────────┤${rst}\n"

  _mode_cmd_header

  printf "  ${prp}${bld}├──────────────────────────────────────┤${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${ylw}/status${rst} 상태   ${ylw}/diff${rst}   변경사항  ${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${ylw}/save${rst}   저장   ${ylw}/ctx${rst}    컨텍스트  ${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${ylw}/focus N${rst} 포커스 ${ylw}/prompt X${rst} 프롬프트${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${ylw}/mode X${rst} 모드   ${ylw}/help${rst}   도움말   ${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${ylw}/quit${rst}   종료   ${ylw}C-B d${rst}  나가기   ${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}└──────────────────────────────────────┘${rst}\n"

  _mode_cmd_info "$_cmd_tools[@]" "$_cmd_seq_order[@]" "$_cmd_icons[@]"

  printf "\n"
fi

# source input loop (history, key bindings, main loop)
source "${YOLO_DIR}/lib/cmd_input.zsh"
CMD_BODY
  } > "$cmd_script"
  chmod +x "$cmd_script"
}

# ── generate status bar monitor script ──
_battle_gen_monitor() {
  monitor="$tmpdir/monitor.sh"
  {
    echo '#!/bin/zsh'
    echo "session=\"$session\""
    echo "tmpdir=\"$tmpdir\""
    echo "mode=\"$mode\""
    echo "workdir=\"$workdir\""
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

  mode_info=""
  if [[ "$mode" == "sequential" ]]; then
    cur_round=$(cat "$tmpdir/round.txt" 2>/dev/null)
    cur_turn=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
    [ -z "$cur_round" ] && cur_round=1
    [ -z "$cur_turn" ] && cur_turn=0
    mode_info="${sep}#[fg=colour141,bold]R${cur_round}:T${cur_turn}#[default]"
  elif [[ "$mode" == "collaborative" ]]; then
    role_parts=""
    for ((k=1; k<=${#tool_names[@]}; k++)); do
      rfile="$tmpdir/role_${tool_names[$k]}.txt"
      if [ -f "$rfile" ]; then
        rname=$(cat "$rfile" 2>/dev/null)
        [ -n "$rname" ] && role_parts+="${tool_icons[$k]}${rname} "
      fi
    done
    [ -n "$role_parts" ] && mode_info="${sep}#[fg=colour141]${role_parts}#[default]"
  elif [[ "$mode" == "parallel" ]]; then
    if [ -f "$tmpdir/context_winner.md" ]; then
      mode_info="${sep}#[fg=colour82,bold]PICKED ✔#[default]"
    fi
  fi

  if $all_done; then
    tmux set-option -t "$session" status-right \
      " ${right} ${mode_info} ${sep}#[fg=colour82,bold]ALL DONE ✦#[default] " 2>/dev/null
    break
  fi

  tmux set-option -t "$session" status-right " ${right} ${mode_info} " 2>/dev/null

  sleep 1
done
MONITOR_BODY
  } > "$monitor"
  chmod +x "$monitor"
}
