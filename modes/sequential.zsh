#!/bin/zsh
# Mode Skill: Sequential (순차)
# 1개 컨텍스트 릴레이, /next로 라운드로빈 무한순환

# ── metadata ──
_mode_label="SEQUENTIAL (순차)"
_mode_icon="➡️"
_mode_color_name="cyan"
_mode_needs_order=true
_mode_input_routing="current_only"  # send to current turn AI only

# ── context setup ──
_mode_setup_context() {
  local tmpdir="$1" cnt="$2"
  echo "# Sequential Mode Context (릴레이)" > "$tmpdir/context.md"
  echo "" >> "$tmpdir/context.md"
}

# ── roles (none for sequential) ──
_mode_setup_roles() { : }
_mode_roles=()
_mode_role_prompts=()

# ── wait logic (heredoc injected into run script) ──
_mode_gen_wait_logic() {
  cat << 'EOF'
# ── sequential mode: wait for turn ──
my_turn=""
while IFS=: read -r tidx tnum; do
  [ "$tidx" = "$toolidx" ] && my_turn="$tnum"
done < "$tmpdir/seq_order_map.txt"
[ -z "$my_turn" ] && my_turn="$toolidx"

echo "waiting" > "$statusfile"
printf '  \033[2m📋 순차 모드 - 턴 #%s (공유 컨텍스트: %s/context.md)\033[0m\n' "$my_turn" "$tmpdir"
printf '  \033[2m⏳ 턴 대기중 (#%s)...\033[0m\n' "$my_turn"
while true; do
  turn=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
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
EOF
}

# ── prompt injection ──
_mode_prompt_inject() {
  local tmpdir="$1"
  echo 'prompt="[공유 컨텍스트: '"$tmpdir"'/context.md - 이전 AI 작업 내용이 누적됩니다] ${prompt}"'
}

# ── done logic additions ──
_mode_gen_done_logic() {
  cat << 'EOF'
# save diff for next AI's context (sequential: chain to next AI)
if [ -n "$my_turn" ] && [ -n "$_diff" ]; then
  echo "$_diff" > "$tmpdir/diff_turn_${my_turn}.txt"
fi

# sequential mode: auto-advance to next turn
if [ -n "$my_turn" ]; then
  cnt=$(wc -l < "$tmpdir/seq_order_map.txt" 2>/dev/null)
  [ -z "$cnt" ] && cnt=0
  next_turn=$(( my_turn + 1 ))
  if [ "$cnt" -gt 0 ] && [ "$next_turn" -gt "$cnt" ]; then
    next_turn=1
    round=$(cat "$tmpdir/round.txt" 2>/dev/null)
    [ -z "$round" ] && round=1
    round=$(( round + 1 ))
    echo "$round" > "$tmpdir/round.txt"
    printf '\n  \033[38;5;220m\033[1m🔄 라운드 %s 시작\033[0m\n' "$round"
  fi
  echo "$next_turn" > "$tmpdir/seq_turn.txt"
  printf '\n  \033[38;5;220m\033[1m▶ 다음 턴 (#%s) 자동 시작\033[0m\n' "$next_turn"
fi
EOF
}

# ── help panel commands ──
_mode_help_commands() {
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}${bld}/next X${rst}   라운드로빈${cyn}★${rst}    ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/skip${rst}     건너뛰기         ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/order N${rst}  순서 변경       ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${dm}  1→2→3→1→... 무한순환${rst}   ${prp}${bld}║${rst}\n"'
}

# ── help panel info section ──
_mode_help_info() {
  local cnt="$1"
  shift
  local -a tools=("$@")
  shift $cnt
  local -a icons=("$@")
  local -a seq_order
  # seq_order is passed after icons
  shift $cnt
  seq_order=("$@")
  echo 'printf "\n  ${cyn}${bld}📋 실행 순서:${rst}\n"'
  for ((j=1; j<=${#seq_order[@]}; j++)); do
    local oi=${seq_order[$j]}
    echo "printf '   ${j}) ${icons[$oi]} ${tools[$oi]}\n'"
  done
}

# ── cmd center mode header ──
_mode_cmd_header() {
  printf '  ${prp}${bld}║${rst}  ${cyn}${bld}➡️  SEQUENTIAL${rst} ${dm}순차 모드${rst}          ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}  ${dm}1개 컨텍스트 릴레이 /next 순환${rst}     ${prp}${bld}║${rst}\n'
}

# ── cmd center mode commands ──
_mode_cmd_commands() {
  printf '  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n'
  printf '  ${prp}${bld}║${rst}  ${cyn}순차 모드:${rst}                          ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}${bld}/next X${rst}    라운드로빈 ${cyn}★${rst}        ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/skip${rst}      건너뛰기              ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/order N..${rst} 순서 변경 ${dm}(예:2 1 3)${rst}${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${dm}  1→2→3→1→... 무한 라운드로빈${rst}  ${prp}${bld}║${rst}\n'
}

# ── cmd center mode info ──
_mode_cmd_info() {
  # receives: _cmd_tools array, _cmd_seq_order array, _cmd_icons array
  printf "\n  ${cyn}${bld}📋 실행 순서:${rst}\n"
  for ((r=1; r<=${#_cmd_seq_order[@]}; r++)); do
    local oi=${_cmd_seq_order[$r]}
    printf "   ${dm}#${r}${rst} ${_cmd_icons[$oi]} ${_cmd_tools[$oi]}\n"
  done
  printf "\n  ${ylw}${bld}▶ 모든 AI 동시 시작. /next로 1→2→3→1→... 무한 순환${rst}\n"
}

# ── banner extra info ──
_mode_banner_extra() {
  local j="$1"
  echo " [#$j]"
}

# ── cmd center context view ──
_mode_do_ctx() {
  local tmpdir="$1"
  printf "  ${cyn}${bld}📋 공유 컨텍스트 (context.md):${rst}\n"
  local ctx_file="$tmpdir/context.md"
  if [ -f "$ctx_file" ] && [ -s "$ctx_file" ]; then
    local ctx_lines=$(wc -l < "$ctx_file" | tr -d ' ')
    tail -30 "$ctx_file" | while IFS= read -r cl; do
      printf "    ${dm}%s${rst}\n" "$cl"
    done
    [ "$ctx_lines" -gt 30 ] && printf "    ${dm}... (총 ${ctx_lines}줄, 마지막 30줄 표시)${rst}\n"
  else
    printf "    ${dm}(비어 있음)${rst}\n"
  fi
}

# ── help command text ──
_mode_help_text() {
  printf "\n  ${cyn}${bld}순차 모드:${rst}\n"
  printf "  ${ylw}/next X${rst} 라운드로빈 다음 AI (컨텍스트 저장+자동전송)\n"
  printf "  ${ylw}/skip${rst}   건너뛰기  ${ylw}/order N..${rst} 순서변경\n"
  printf "  ${dm}  1→2→3→1→... 무한 라운드로빈, /quit으로 종료${rst}\n"
}
