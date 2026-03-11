#!/bin/zsh
# Mode Skill: Collaborative (협동)
# 역할분리 + 3개 작업컨텍스트 + 1개 공유보드, worktree 격리

# ── metadata ──
_mode_label="CO-OP (협동)"
_mode_icon="🤝"
_mode_color_name="green"
_mode_needs_order=false
_mode_input_routing="broadcast"  # send to all AIs

# ── context setup ──
_mode_setup_context() {
  local tmpdir="$1" cnt="$2"
  shift 2
  local -a tools=("$@")
  for ((j=1; j<=$cnt; j++)); do
    echo "# ${tools[$j]} Work Context" > "$tmpdir/context_${tools[$j]}.md"
    echo "" >> "$tmpdir/context_${tools[$j]}.md"
  done
  echo "# Shared Board (공유 보드)" > "$tmpdir/shared.md"
  echo "" >> "$tmpdir/shared.md"
  echo "각 AI가 현재 작업 내용을 여기에 기록합니다." >> "$tmpdir/shared.md"
  echo "" >> "$tmpdir/shared.md"
}

# ── roles ──
_mode_roles=("Core" "Tests" "Config")

_mode_setup_roles() {
  local tmpdir="$1" prompt="$2"
  _mode_role_prompts=(
    "You are the core developer. Focus ONLY on main implementation/source code. Do NOT create or modify test files, config files, or documentation. After completing work, write a summary of what you did to the shared board: ${tmpdir}/shared.md (append, don't overwrite). Task: ${prompt}"
    "You are the test engineer. Write tests and test utilities ONLY. Do NOT modify any implementation/source code. Only create/edit files in test directories or files with test/spec in their name. After completing work, write a summary of what you did to the shared board: ${tmpdir}/shared.md (append, don't overwrite). Check the shared board to see what other AIs are doing to avoid duplication. Task: ${prompt}"
    "You are the DevOps/config engineer. Handle ONLY build config, documentation, CI/CD, and infrastructure files. Do NOT modify implementation code or test files. After completing work, write a summary of what you did to the shared board: ${tmpdir}/shared.md (append, don't overwrite). Check the shared board to see what other AIs are doing to avoid duplication. Task: ${prompt}"
  )
}

# ── wait logic (heredoc injected into run script) ──
_mode_gen_wait_logic() {
  cat << 'EOF'
# ── collaborative mode: all roles run simultaneously ──
printf '  \033[2m📋 협동 모드 - 내 컨텍스트: %s/context_%s.md\033[0m\n' "$tmpdir" "$toolname"
printf '  \033[2m   공유 보드: %s/shared.md (작업 내용 기록 + 확인)\033[0m\n' "$tmpdir"
EOF
}

# ── prompt injection ──
_mode_prompt_inject() {
  local tmpdir="$1"
  echo 'prompt="[내 작업 컨텍스트: '"$tmpdir"'/context_${toolname}.md | 공유 보드: '"$tmpdir"'/shared.md - 작업 내용을 기록하고 다른 AI 작업을 확인하세요] ${prompt}"'
}

# ── done logic additions ──
_mode_gen_done_logic() {
  cat << 'EOF'
# save final output to own context file
{
  echo ""
  echo "## Final Output (process exited)"
  echo "### Changes"
  echo '```'
  [ -n "$_diff_stat" ] && echo "$_diff_stat" || echo "(none)"
  echo '```'
} >> "$tmpdir/context_${toolname}.md"
EOF
}

# ── help panel commands ──
_mode_help_commands() {
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}${bld}/merge${rst}   브랜치 머지 ${cyn}★${rst}  ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/board${rst}    공유보드 확인    ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/swap N M${rst} 역할 교체       ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/role N X${rst} 역할 변경       ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/roles${rst}    역할 확인        ${prp}${bld}║${rst}\n"'
}

# ── help panel info section ──
_mode_help_info() {
  local cnt="$1"
  shift
  local -a tools=("$@")
  shift $cnt
  local -a icons=("$@")
  shift $cnt
  local -a roles=("$@")
  echo 'printf "\n  ${grn}${bld}📋 역할 배정:${rst}\n"'
  for ((j=1; j<=$cnt; j++)); do
    echo "printf '   ${icons[$j]} ${tools[$j]}: ${roles[$j]:-Dev}\n'"
  done
}

# ── cmd center mode header ──
_mode_cmd_header() {
  printf '  ${prp}${bld}║${rst}  ${grn}${bld}🤝 CO-OP${rst} ${dm}협동 모드${rst}                ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}  ${dm}역할분리 + 공유보드 + worktree${rst}     ${prp}${bld}║${rst}\n'
}

# ── cmd center mode commands ──
_mode_cmd_commands() {
  printf '  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n'
  printf '  ${prp}${bld}║${rst}  ${cyn}협동 모드:${rst}                          ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}${bld}/merge${rst}    브랜치 머지 ${cyn}★${rst}        ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/board${rst}     공유보드 확인          ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/swap N M${rst}  N↔M 역할 교체        ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/role N X${rst}  N번 AI 역할 변경     ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/roles${rst}     현재 역할 확인        ${prp}${bld}║${rst}\n'
}

# ── cmd center mode info ──
_mode_cmd_info() {
  printf "\n  ${grn}${bld}📋 역할 배정:${rst}\n"
  for ((r=1; r<=${#_cmd_tools[@]}; r++)); do
    printf "   ${_cmd_icons[$r]} ${_cmd_tools[$r]}: ${ylw}${_cmd_roles[$r]}${rst}\n"
  done
}

# ── banner extra info ──
_mode_banner_extra() {
  local j="$1"
  echo " (${_mode_roles[$j]:-Dev})"
}

# ── cmd center context view ──
_mode_do_ctx() {
  local tmpdir="$1" cnt="$2"
  shift 2
  local -a tools=("${(@)@[1,cnt]}")
  shift $cnt
  local -a icons=("${(@)@[1,cnt]}")

  printf "  ${grn}${bld}📋 공유 보드 (shared.md):${rst}\n"
  local sfile="$tmpdir/shared.md"
  if [ -f "$sfile" ] && [ -s "$sfile" ]; then
    tail -20 "$sfile" | while IFS= read -r sl; do
      printf "    ${dm}%s${rst}\n" "$sl"
    done
  else
    printf "    ${dm}(비어 있음)${rst}\n"
  fi
  printf "\n"
  for ((ci=1; ci<=cnt; ci++)); do
    local cname="${tools[$ci]}"
    local cicon="${icons[$ci]}"
    local cfile="$tmpdir/context_${cname}.md"
    printf "  ${cyn}${bld}${cicon} ${cname} 작업 컨텍스트:${rst}\n"
    if [ -f "$cfile" ] && [ -s "$cfile" ]; then
      local cl=$(wc -l < "$cfile" | tr -d ' ')
      tail -10 "$cfile" | while IFS= read -r line; do
        printf "    ${dm}%s${rst}\n" "$line"
      done
      [ "$cl" -gt 10 ] && printf "    ${dm}... (총 ${cl}줄)${rst}\n"
    else
      printf "    ${dm}(비어 있음)${rst}\n"
    fi
    printf "\n"
  done
}

# ── help command text ──
_mode_help_text() {
  printf "\n  ${cyn}${bld}협동 모드:${rst}\n"
  printf "  ${ylw}/merge${rst}  브랜치 머지  ${ylw}/board${rst}  공유보드 확인\n"
  printf "  ${ylw}/swap N M${rst} 역할교체  ${ylw}/role N X${rst} 역할변경  ${ylw}/roles${rst} 확인\n"
  printf "  ${dm}  역할분리 + 공유보드 + worktree 격리${rst}\n"
}
