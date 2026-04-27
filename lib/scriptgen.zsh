#!/bin/zsh
# lib/scriptgen.zsh — Script generation for AI run scripts, help panel, command center, and monitor

# ── Generate per-AI run scripts ──
# Sets: _battle_scripts array
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
        # Cleanup existing worktree from previous sessions
        local _old_wt
        _old_wt=$(git -C "$workdir" worktree list --porcelain 2>/dev/null | grep -B1 "branch.*battle-coop-${tname}$" | head -1 | sed 's/^worktree //')
        if [ -n "$_old_wt" ] && [ "$_old_wt" != "$toolworkdir" ]; then
          git -C "$workdir" worktree remove --force "$_old_wt" 2>/dev/null
        fi
        git -C "$workdir" worktree prune 2>/dev/null

        # 머지 안 된 브랜치는 보호, 머지된 브랜치만 삭제
        if git -C "$workdir" rev-parse --verify "battle-coop-${tname}" >/dev/null 2>&1; then
          if git -C "$workdir" merge-base --is-ancestor "battle-coop-${tname}" HEAD 2>/dev/null; then
            # 이미 머지됨 → 삭제 후 새로 생성
            git -C "$workdir" branch -D "battle-coop-${tname}" 2>/dev/null
          else
            # 머지 안 됨 → 경고, 기존 브랜치에서 worktree 생성
            printf "${yellow}  ⚠ ${tname}: 이전 미머지 브랜치 발견 → 이어서 작업${reset}\n"
            if git -C "$workdir" worktree add -f -q "$toolworkdir" "battle-coop-${tname}" 2>/dev/null; then
              _wt_ok=true
            fi
          fi
        fi

        if ! $_wt_ok; then
          if git -C "$workdir" worktree add -f -q "$toolworkdir" -b "battle-coop-${tname}" HEAD 2>/dev/null; then
            _wt_ok=true
          else
            printf "${yellow}  ⚠ worktree failed for ${tname}, using shared dir${reset}\n"
          fi
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
        opencode) cat << 'B'
printf '\n  \033[38;5;141m\033[1m  ╔═══════════════════════════════╗\033[0m\n'
printf '  \033[38;5;141m\033[1m  ║  🦾  O P E N C O D E         ║\033[0m\n'
printf '  \033[38;5;141m\033[1m  ╚═══════════════════════════════╝\033[0m\n\n'
B
        ;;
      esac

      # inject role variable if mode has roles
      if [ ${#_roles[@]} -gt 0 ]; then
        echo "collab_role=\"${_roles[$j]:-Developer}\""
        echo "collab_dev_tool=\"${_yolo_opts[1]}\""
      fi

      # mode-specific wait/info logic (from mode skill)
      _mode_gen_wait_logic

      # determine prompt based on mode
      echo 'prompt=$(cat "$tmpdir/prompt.txt")'
      echo ""

      # mode-specific context path injection into prompt (from mode skill)
      _mode_prompt_inject "$tmpdir"
      echo ""

      # set role prompt if mode has roles
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
    claude)   claude --dangerously-skip-permissions "$prompt" ;;
    gemini)   gemini --yolo "$prompt" ;;
    codex)    codex --sandbox danger-full-access --ask-for-approval never "$prompt" ;;
    opencode)
      # TUI는 종료 시그널이 없으므로 send-keys로 prompt 주입.
      # /auto는 cmd_center에서 opencode 포함 시 자동 비활성화되므로 수동 /next로 진행.
      ( sleep "${OPENCODE_PROMPT_DELAY:-4}"
        if [ -n "$TMUX_PANE" ]; then
          tmux send-keys -t "$TMUX_PANE" -l "$prompt" 2>/dev/null
          sleep 0.5
          tmux send-keys -t "$TMUX_PANE" Enter 2>/dev/null
        fi
      ) &
      OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true opencode
      ;;
  esac
else
  case "$toolname" in
    claude)   claude --dangerously-skip-permissions ;;
    gemini)   gemini --yolo ;;
    codex)    codex --sandbox danger-full-access --ask-for-approval never ;;
    opencode) OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true opencode ;;
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

      # mode-specific done logic (from mode skill)
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

# ── Generate help panel script ──
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
    echo 'clear'
    echo 'printf "\n"'
    echo 'printf "  ${prp}${bld}╔═══════════════════════════════════════════════════╗${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${cyn}${bld}📋 명령어${rst}                                        ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠═══════════════════════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/status${rst}  상태 확인    ${ylw}/diff${rst}     변경사항         ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/save${rst}    결과 저장    ${ylw}/ctx${rst}      컨텍스트         ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/focus N${rst} pane 포커스  ${ylw}/prompt X${rst} 프롬프트         ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/cat F${rst}   파일 비교    ${ylw}/grep P${rst}   파일 검색        ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/mode X${rst} 모드변경${dm}(p/s/c)${rst} ${ylw}/history${rst} 기록            ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/help${rst}    도움말       ${ylw}/quit${rst}     세션 종료        ${prp}${bld}║${rst}\n"'

    # mode-specific help commands (from mode skill)
    echo 'printf "  ${prp}${bld}╠═══════════════════════════════════════════════════╣${rst}\n"'
    _mode_help_commands

    echo 'printf "  ${prp}${bld}╠═══════════════════════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${cyn}${bld}⌨️  단축키${rst}                                       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠═══════════════════════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B →${rst} pane이동  ${ylw}Ctrl+B z${rst} 풀스크린             ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B S${rst} 동기화    ${ylw}Ctrl+B d${rst} 나가기               ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╚═══════════════════════════════════════════════════╝${rst}\n"'

    # mode-specific info section (from mode skill)
    _mode_help_info "$cnt" "${_yolo_opts[@]}" "${_yolo_icons[@]}" "${_seq_order[@]}" "${_roles[@]}"

    echo ''
    echo '# keep alive'
    echo 'while true; do sleep 3600; done'
  } > "$help_script"
  chmod +x "$help_script"
}

# ── Generate command center script ──
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

    # source the command center runtime instead of inlining
    echo ""
    echo "source \"\${YOLO_DIR}/lib/cmd_center.zsh\""
  } > "$cmd_script"
  chmod +x "$cmd_script"
}

# ── Generate status bar monitor script ──
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

  # mode-specific status info
  mode_info=""
  if [[ "$mode" == "sequential" ]]; then
    cur_round=$(cat "$tmpdir/round.txt" 2>/dev/null)
    cur_turn=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
    [ -z "$cur_round" ] && cur_round=1
    [ -z "$cur_turn" ] && cur_turn=0
    mode_info="${sep}#[fg=colour141,bold]R${cur_round}:T${cur_turn}#[default]"
  elif [[ "$mode" == "collaborative" ]]; then
    # show roles in status bar
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
    # check if winner picked
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
