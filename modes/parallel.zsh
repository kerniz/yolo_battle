#!/bin/zsh
# Mode Skill: Parallel (동시)
# 각 AI 독립 컨텍스트, 서로 열람 가능, 사용자가 최종 선택

# ── metadata ──
_mode_label="PARALLEL (동시)"
_mode_icon="⚡"
_mode_color_name="yellow"
_mode_needs_order=false
_mode_input_routing="broadcast"  # send to all AIs

# ── context setup ──
_mode_setup_context() {
  local tmpdir="$1" cnt="$2"
  shift 2
  local -a tools=("$@")
  for ((j=1; j<=$cnt; j++)); do
    echo "# ${tools[$j]} Context" > "$tmpdir/context_${tools[$j]}.md"
    echo "" >> "$tmpdir/context_${tools[$j]}.md"
  done
}

# ── default prompt (no user prompt given) ──
_mode_default_prompt() {
  echo "동시(병렬) 모드입니다. 각자 독립적으로 작업하며, 작업 결과를 반드시 자신의 컨텍스트 파일(context_{자신의이름}.md)에 기록하세요. 다른 AI의 컨텍스트(context_*.md)도 열람 가능합니다. 사용자 지시가 없으면 대기하세요."
}

# ── roles (none for parallel) ──
_mode_setup_roles() { : }
_mode_roles=()
_mode_role_prompts=()

# ── wait logic (heredoc injected into run script) ──
_mode_gen_wait_logic() {
  cat << 'EOF'
# ── parallel mode: no waiting ──
printf '  \033[2m📋 동시 모드 - 내 컨텍스트: %s/context_%s.md\033[0m\n' "$tmpdir" "$toolname"
printf '  \033[2m   다른 AI 컨텍스트도 열람 가능 (context_*.md)\033[0m\n'
EOF
}

# ── prompt injection ──
_mode_prompt_inject() {
  local tmpdir="$1"
  echo 'prompt="[작업 결과를 반드시 '"$tmpdir"'/context_${toolname}.md 에 기록하세요. 다른 AI 컨텍스트: '"$tmpdir"'/context_*.md 열람 가능. context.md는 사용하지 마세요.] ${prompt}"'
}

# ── done logic additions (heredoc injected into run script) ──
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
  echo 'printf "  ${prp}${bld}│${rst}  ${cyn}${bld}⚡ 동시 모드${rst}                                     ${prp}${bld}│${rst}\n"'
  echo 'printf "  ${prp}${bld}│${rst}  ${ylw}${bld}/pick N${rst}  직접 채택${cyn}★${rst}   ${ylw}/compare${rst} 결과 비교    ${prp}${bld}│${rst}\n"'
  echo 'printf "  ${prp}${bld}│${rst}  ${ylw}/compare N${rst} AI선택    ${ylw}/merge N${rst} AI가 종합    ${prp}${bld}│${rst}\n"'
}

# ── help panel info section ──
_mode_help_info() {
  local cnt="$1"
  shift
  local -a tools=("${(@)@[1,cnt]}")
  shift $cnt
  local -a icons=("${(@)@[1,cnt]}")

  echo 'printf "\n  ${ylw}${bld}📋 컨텍스트:${rst}\n"'
  for ((j=1; j<=$cnt; j++)); do
    echo "printf '   ${icons[$j]} ${tools[$j]}: context_${tools[$j]}.md\n'"
  done
  echo "printf '  ${dm}/pick N 으로 최종 채택${rst}\n'"
}

# ── cmd center mode header ──
_mode_cmd_header() {
  printf "  ${prp}${bld}│${rst}  ${ylw}${bld}⚡ PARALLEL${rst} ${dm}동시 모드${rst}             ${prp}${bld}│${rst}\n"
  printf "  ${prp}${bld}│${rst}  ${dm}각자 독립 작업 → /pick N 채택${rst}      ${prp}${bld}│${rst}\n"
}


# ── cmd center mode info ──
_mode_cmd_info() {
  printf "\n  ${ylw}${bld}📋 컨텍스트:${rst}\n"
  for ((r=1; r<=${#_cmd_tools[@]}; r++)); do
    printf "   context_${_cmd_tools[$r]}.md\n"
  done
  printf "\n  ${ylw}${bld}▶ 모든 AI 동시 작업 → 완료 감지 → /pick·/compare·/merge${rst}\n"
}

# ── banner extra info ──
_mode_banner_extra() {
  local j="$1"
  echo ""  # no extra info for parallel
}

# ── cmd center context view ──
_mode_do_ctx() {
  local tmpdir="$1" cnt="$2"
  shift 2
  local -a tools=("${(@)@[1,cnt]}")
  shift $cnt
  local -a icons=("${(@)@[1,cnt]}")

  for ((ci=1; ci<=cnt; ci++)); do
    local cname="${tools[$ci]}"
    local cicon="${icons[$ci]}"
    local cfile="$tmpdir/context_${cname}.md"
    printf "  ${cyn}${bld}${cicon} ${cname} 컨텍스트:${rst}\n"
    if [ -f "$cfile" ] && [ -s "$cfile" ]; then
      local cl=$(wc -l < "$cfile" | tr -d ' ')
      tail -15 "$cfile" | while IFS= read -r line; do
        printf "    ${dm}%s${rst}\n" "$line"
      done
      [ "$cl" -gt 15 ] && printf "    ${dm}... (총 ${cl}줄)${rst}\n"
    else
      printf "    ${dm}(비어 있음)${rst}\n"
    fi
    printf "\n"
  done
}

# ── help command text ──
_mode_help_text() {
  printf "\n  ${cyn}${bld}동시 모드:${rst}\n"
  printf "  ${ylw}/pick N${rst}     사용자가 N번 AI 결과 직접 채택\n"
  printf "  ${ylw}/compare${rst}    결과 비교 테이블 표시\n"
  printf "  ${ylw}/compare N${rst}  N번 AI가 다른 결과 비교 후 최적 선택\n"
  printf "  ${ylw}/merge N${rst}    N번 AI가 모든 결과 종합하여 최종본 작성\n"
  printf "  ${dm}  모든 AI 완료 시 자동 안내 │ 각 AI 독립 컨텍스트${rst}\n"
}
