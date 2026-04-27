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
  cat > "$tmpdir/context.md" << 'CTXEOF'
# Sequential Mode Context (릴레이)

## 규칙
- 1턴에 1개 작업만 수행하세요. 작업 완료 후 결과를 아래에 기록하세요.
- 이 파일(context.md)에만 작업 결과를 기록하세요. 터미널 로그를 복사하지 마세요.
- 이전 AI의 작업 내용을 확인하고 이어서 작업하세요.

## 작업 기록
CTXEOF
  : > "$tmpdir/log.md"
}

# ── default prompt (no user prompt given) ──
_mode_default_prompt() {
  echo "순차(릴레이) 모드입니다. 공유 컨텍스트 파일에서 이전 AI의 작업 내용을 확인하고, 사용자의 지시에 따라 작업을 이어가세요. 작업 결과와 다음 AI에게 전달할 내용을 공유 컨텍스트 파일(context.md)에 기록하세요. 사용자 지시가 없으면 대기하세요."
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

_seq_round=0
while true; do  # ── sequential multi-round loop ──

echo "waiting" > "$statusfile"
if [ "$_seq_round" -eq 0 ]; then
  printf '  \033[2m📋 순차 모드 - 턴 #%s (공유 컨텍스트: %s/context.md)\033[0m\n' "$my_turn" "$tmpdir"
fi
printf '  \033[2m⏳ 턴 대기중 (#%s)...\033[0m\n' "$my_turn"
while true; do
  turn=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  [ "$turn" = "$my_turn" ] && break
  sleep 0.1
done
_seq_round=$(( _seq_round + 1 ))
# 첫 활성화 플래그 (round 2+에서 _do_next가 pane으로 직접 전송하기 위해)
touch "$tmpdir/started_${toolname}.txt"
printf '\a' # Terminal Bell (Visual sound)
printf '  \033[38;5;141m\033[1m\033[5m⚡\033[0m \033[38;5;213m\033[1mROUND %s: YOUR TURN!\033[0m \033[38;5;141m\033[1m\033[5m⚡\033[0m\n\n' "$_seq_round"

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
  echo 'prompt="[공유 컨텍스트: '"$tmpdir"'/context.md - 이전 AI 작업 내용이 누적됩니다] 순차모드 규칙: 1턴에 1개 작업만 수행. 작업 결과를 context.md의 \"작업 기록\" 섹션 끝에 추가 기록하세요. ${prompt}"'
}

# ── done logic additions ──
_mode_gen_done_logic() {
  cat << 'EOF'
# save diff for next AI's context (sequential: chain to next AI)
if [ -n "$my_turn" ] && [ -n "$_diff" ]; then
  echo "$_diff" > "$tmpdir/diff_turn_${my_turn}.txt"
fi

# capture pane output to shared context.md before advancing
if [ -n "$my_turn" ]; then
  _round=$(cat "$tmpdir/round.txt" 2>/dev/null || echo "1")
  local log_flag="$tmpdir/logged_R${_round}_T${my_turn}.txt"

  # 📍 Improvement: Unify logging with /next. Only log if not already captured.
  if [ ! -f "$log_flag" ]; then
    # Increase capture efficiency (last 50 lines) and avoid duplicates
    _pane_out=$(tmux capture-pane -p -S -50 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 50)
    
    # More robust changed files detection
    _changed_files=$(git diff HEAD~1..HEAD --name-only 2>/dev/null)
    
    {
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "📍 ROUND ${_round} | TURN ${my_turn} | AGENT: ${toolname} (AUTO DONE)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      if [ -n "$_changed_files" ]; then
        echo "📂 Modified Files:"
        echo "$_changed_files" | sed 's/^/- /'
        echo ""
      fi
      echo "💬 Last Output:"
      echo '```'
      # 📍 Strip ANSI colors for cleaner context relay
      echo "$_pane_out" | perl -pe 's/\x1b\[[0-9;]*[mGKH]//g' 2>/dev/null || echo "$_pane_out"
      echo '```'
      if [ -n "$_diff_stat" ]; then
        echo "📊 Diff Summary:"
        echo '```'
        echo "$_diff_stat"
        echo '```'
      fi
      echo ""
    } >> "$tmpdir/log.md"
    touch "$log_flag"

    # 📍 Improvement: Truncate log.md if it gets too long
    if [ $(wc -l < "$tmpdir/log.md") -gt 10000 ]; then
      echo "  \033[2m(log.md truncated due to length)\033[0m"
      tail -5000 "$tmpdir/log.md" > "$tmpdir/log.md.tmp" && mv "$tmpdir/log.md.tmp" "$tmpdir/log.md"
    fi
  fi
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

done  # ── end sequential multi-round loop ──
EOF
}

# ── help panel commands ──
_mode_help_commands() {
  echo 'printf "  ${prp}${bld}║${rst}  ${cyn}${bld}➡️  순차 모드${rst}                                    ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}${bld}/next${rst}    다음 AI${cyn}★${rst}      ${ylw}/skip${rst}     건너뛰기       ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/auto${rst}    자동 전환     ${ylw}/order N${rst} 순서 변경        ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${dm}/next 지시  /next 3  /auto stop  1→2→3→1..${rst}       ${prp}${bld}║${rst}\n"'
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
  printf "  ${prp}${bld}║${rst}  ${cyn}${bld}➡️  SEQUENTIAL${rst} ${dm}순차 모드${rst}          ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${dm}1개 컨텍스트 릴레이 /next 순환${rst}     ${prp}${bld}║${rst}\n"
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
  printf "\n  ${cyn}${bld}순차 모드 명령어:${rst}\n"
  printf "  ${ylw}${bld}/next${rst}          다음 AI로 턴 전환 (컨텍스트 저장+relay 전송)\n"
  printf "  ${dm}  /next${rst}          ${dm}— 다음 턴으로 전환${rst}\n"
  printf "  ${dm}  /next 버그 수정${rst} ${dm}— 다음 AI에게 '버그 수정' 지시 전달${rst}\n"
  printf "  ${dm}  /next 3${rst}        ${dm}— 3턴 연속 넘기기 (한 바퀴 순환 등)${rst}\n"
  printf "  ${ylw}/skip${rst}           현재 AI 건너뛰기 (결과 무시, 다음 AI 활성화)\n"
  printf "  ${ylw}/auto${rst} ${dm}[N]${rst}       context 변경 감지 → N초 안정화 후 자동 /next\n"
  printf "  ${dm}  /auto${rst}          ${dm}— 기본 10초 안정화${rst}\n"
  printf "  ${dm}  /auto 5${rst}        ${dm}— 5초 안정화 후 전환${rst}\n"
  printf "  ${dm}  /auto stop${rst}     ${dm}— 자동 전환 중지${rst}\n"
  printf "  ${ylw}/order N..${rst}      순서 변경 ${dm}(예: /order 2 1 3)${rst}\n"
  printf "  ${dm}  1→2→3→1→... 무한 라운드로빈, /quit으로 종료${rst}\n"
}
