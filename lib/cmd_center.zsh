
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

clear

if [[ "$has_help_pane" == "true" ]]; then
  # compact header when help panel is separate
  printf "\n"
  printf "  ${prp}${bld}⌨️  COMMAND CENTER${rst}"
  printf "  ${(P)_mode_color_name:-$white}${bld}${_mode_icon}${rst} ${dm}${_mode_label}${rst}"
  printf "\n  ${dm}텍스트 입력 → AI에 전송 │ /help 도움말${rst}\n\n"
else
  printf "\n"
  printf "  ${prp}${bld}╔══════════════════════════════════════╗${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${ylw}${bld}⌨️  C O M M A N D   C E N T E R${rst}    ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"

  _mode_cmd_header

  printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${ylw}/status${rst} 상태   ${ylw}/diff${rst}   변경사항  ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${ylw}/save${rst}   저장   ${ylw}/ctx${rst}    컨텍스트  ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${ylw}/focus N${rst} 포커스 ${ylw}/prompt X${rst} 프롬프트${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${ylw}/mode X${rst} 모드   ${ylw}/help${rst}   도움말   ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}  ${ylw}/quit${rst}   종료   ${ylw}C-B d${rst}  나가기   ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}╚══════════════════════════════════════╝${rst}\n"

  _mode_cmd_info "$_cmd_tools[@]" "$_cmd_seq_order[@]" "$_cmd_icons[@]"

  printf "\n"
fi

# ════════════════════════════════════════
# FUNCTIONS
# ════════════════════════════════════════

_show_status() {
  printf "\n"
  local round=$(cat "$tmpdir/round.txt" 2>/dev/null)
  local cur_turn=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  printf "  ${purple}${bold}┏━━━━━━━━ STATUS BOARD ━━━━━━━┓${rst}\n"
  if $_mode_needs_order; then
    printf "  ${purple}${bold}┃${rst} ${(P)_mode_color_name:-$white}${bld}${_mode_icon}${rst} ${dm}${_mode_label}${rst}  ${cyn}${bld}R${round}:T${cur_turn}${rst}%-$((16 - ${#_mode_label}))s ${purple}${bold}┃${rst}\n" ""
  else
    printf "  ${purple}${bold}┃${rst} ${(P)_mode_color_name:-$white}${bld}${_mode_icon}${rst} ${dm}${_mode_label}${rst}%-$((24 - ${#_mode_label}))s ${purple}${bold}┃${rst}\n" ""
  fi
  printf "  ${purple}${bold}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${rst}\n"
  for ((si=1; si<=${#_cmd_tools[@]}; si++)); do
    local sname="${_cmd_tools[$si]}"
    local sicon="${_cmd_icons[$si]}"
    local sfile="$tmpdir/status_${sname}"
    if [ -f "$sfile" ]; then
      local st=$(cat "$sfile" 2>/dev/null)
      case "$st" in
        done:*)  printf "  ${purple}${bold}┃${rst} ${grn}${bld}✔ ${sicon} %-12s${rst} ${dm}${st#done:}${rst}   ${purple}${bold}┃${rst}\n" "$sname" ;;
        running) printf "  ${purple}${bold}┃${rst} ${ylw}${bld}⣾ ${sicon} %-12s${rst} ${ylw}ING..${rst}  ${purple}${bold}┃${rst}\n" "$sname" ;;
        waiting) printf "  ${purple}${bold}┃${rst} ${dm}⏳ ${sicon} %-12s WAIT${rst}   ${purple}${bold}┃${rst}\n" "$sname" ;;
        *)       printf "  ${purple}${bold}┃${rst} ${dm}·  ${sicon} %-12s --${rst}     ${purple}${bold}┃${rst}\n" "$sname" ;;
      esac
    else
      printf "  ${purple}${bold}┃${rst} ${dm}·  ${sicon} %-12s --${rst}     ${purple}${bold}┃${rst}\n" "$sname"
    fi
  done
  printf "  ${purple}${bold}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${rst}\n"
  printf "\n"
}

_send_to_pane() {
  local pane="$1"
  local tool="$2"
  local text="$3"
  # Use -l for literal string (better for multibyte)
  tmux send-keys -t "${pane}" -l "$text" 2>/dev/null
  # Wait for input buffer to flush before pressing Enter
  sleep 0.3
  case "$tool" in
    gemini)
      tmux send-keys -t "${pane}" Enter 2>/dev/null
      sleep 0.8
      tmux send-keys -t "${pane}" Enter 2>/dev/null
      sleep 0.8
      tmux send-keys -t "${pane}" Enter 2>/dev/null
      ;;
    codex)
      tmux send-keys -t "${pane}" Enter 2>/dev/null
      sleep 0.8
      tmux send-keys -t "${pane}" Enter 2>/dev/null
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
  for ((si=0; si<${#ai_panes[@]}; si++)); do
    local pidx="${ai_panes[$((si+1))]}"
    local tname="${_cmd_tools[$((si+1))]}"
    tmux capture-pane -t "${pidx}" -p -S -500 > "$savedir/${tname}.txt" 2>/dev/null
  done
  cp "$tmpdir/prompt.txt" "$savedir/prompt.txt" 2>/dev/null
  cp "$tmpdir/mode.txt" "$savedir/mode.txt" 2>/dev/null
  # save context files
  cp "$tmpdir"/context*.md(N) "$savedir/" 2>/dev/null
  cp "$tmpdir"/log.md "$savedir/" 2>/dev/null
  cp "$tmpdir"/shared.md "$savedir/" 2>/dev/null
  printf "  ${grn}${bld}✔ 저장됨:${rst} ${dm}${savedir}${rst}\n"
  printf "  ${dm}  파일: prompt.txt"
  for ((si=1; si<=${#_cmd_tools[@]}; si++)); do
    printf ", ${_cmd_tools[$si]}.txt"
  done
  printf ", context*.md${rst}\n\n"
}

# ════════════════════════════════════════
# /ctx - 컨텍스트 확인
# ════════════════════════════════════════
_do_ctx() {
  _mode_do_ctx "$tmpdir" "$cnt" "${_cmd_tools[@]}" "${_cmd_icons[@]}"
}

# ════════════════════════════════════════
# /next - 순차 모드 라운드로빈
# ════════════════════════════════════════
_do_next() {
  if [[ "$mode" != "sequential" ]]; then
    printf "  ${red}순차 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local new_prompt="$*"
  local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  local round=$(cat "$tmpdir/round.txt" 2>/dev/null || echo "1")

  # 📍 Improvement: Capture current turn's output before advancing
  if [ "$cur" -ge 1 ]; then
    local cur_tool_idx=${_cmd_seq_order[$cur]}
    local cur_pane="${ai_panes[$cur_tool_idx]}"
    local cur_tool="${_cmd_tools[$cur_tool_idx]}"
    local log_flag="$tmpdir/logged_R${round}_T${cur}.txt"
    
    if [ ! -f "$log_flag" ]; then
      printf "  ${dm}→ %s의 결과 캡처 중...${rst}\n" "$cur_tool"
      local pane_out=$(tmux capture-pane -t "${cur_pane}" -p -S -50 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 50)
      local changed_files=$(git diff HEAD~1..HEAD --name-only 2>/dev/null)
      {
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📍 ROUND ${round} | TURN ${cur} | AGENT: ${cur_tool} (MANUAL NEXT)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        [ -n "$changed_files" ] && echo "📂 Modified Files:" && echo "$changed_files" | sed 's/^/- /' && echo ""
        echo "💬 Last Output:"
        echo '```'
        # 📍 Strip ANSI colors for cleaner context relay
        echo "$pane_out" | perl -pe 's/\x1b\[[0-9;]*[mGKH]//g' 2>/dev/null || echo "$pane_out"
        echo '```'
        echo ""
      } >> "$tmpdir/log.md"
      touch "$log_flag"
    fi
  fi

  # calculate next turn (round-robin: wraps around)
  local next=$(( cur + 1 ))
  local cnt=${#_cmd_seq_order[@]}

  if [ $next -gt $cnt ]; then
    next=1
    round=$(( round + 1 ))
    echo "$round" > "$tmpdir/round.txt"
    printf "  ${ylw}${bld}🔄 라운드 ${round} 시작${rst}\n"
  fi

  echo "$next" > "$tmpdir/seq_turn.txt"

  local next_tool_idx=${_cmd_seq_order[$next]}
  local next_pane="${ai_panes[$next_tool_idx]}"
  local next_tool="${_cmd_tools[$next_tool_idx]}"

  printf "  ${cyn}${bld}▶ R${round}:T${next} ${_cmd_icons[$next_tool_idx]} ${next_tool} 활성화${rst}\n"

  # build relay message with context path
  local ctx_msg=""
  if [ -n "$new_prompt" ]; then
    _last_user_cmd="$new_prompt"
    printf '%s' "$new_prompt" > "$tmpdir/user_cmd.txt"
    ctx_msg="반드시 ${tmpdir}/context.md 를 열어 최신 입력을 확인한 뒤 즉시 응답하세요(추가 질문 금지). 1턴 1작업 규칙을 지키고, 결과를 context.md에 기록하세요. 새 작업: ${new_prompt}"
  else
    local last_cmd="$_last_user_cmd"
    if [ -z "$last_cmd" ]; then
      last_cmd=$(cat "$tmpdir/user_cmd.txt" 2>/dev/null)
    fi
    ctx_msg="반드시 ${tmpdir}/context.md 를 열어 최신 입력을 확인한 뒤 즉시 응답하세요(추가 질문 금지). 1턴 1작업 규칙을 지키고, 결과를 context.md에 기록하세요. 이어서 작업: ${last_cmd}"
  fi

  # update prompt.txt BEFORE advancing turn so run script picks up relay message
  printf '%s' "$ctx_msg" > "$tmpdir/prompt.txt"

  # 이미 실행 중인 AI에게는 pane으로 직접 relay 메시지 전송 (round 2+)
  if [ -f "$tmpdir/started_${next_tool}.txt" ]; then
    printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool} pane에 relay 전송${rst}\n"
    _send_to_pane "${next_pane}" "${next_tool}" "$ctx_msg"
  else
    printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool} 프롬프트 갱신됨${rst}\n"
  fi
}

# ════════════════════════════════════════
# /skip - 순차 모드 건너뛰기 (라운드로빈)
# ════════════════════════════════════════
_do_skip() {
  if [[ "$mode" != "sequential" ]]; then
    printf "  ${red}순차 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  local next=$(( cur + 1 ))
  local cnt=${#_cmd_seq_order[@]}
  local round=$(cat "$tmpdir/round.txt" 2>/dev/null)
  [ -z "$round" ] && round=1
  if [ $next -gt $cnt ]; then
    next=1
    round=$(( round + 1 ))
    echo "$round" > "$tmpdir/round.txt"
  fi
  echo "$next" > "$tmpdir/seq_turn.txt"
  local next_tool_idx=${_cmd_seq_order[$next]}
  local next_pane="${ai_panes[$next_tool_idx]}"
  local next_tool="${_cmd_tools[$next_tool_idx]}"
  printf "  ${ylw}⏭ 건너뜀${rst}\n"
  printf "  ${cyn}${bld}▶ R${round}:T${next} ${_cmd_icons[$next_tool_idx]} ${next_tool} 활성화${rst}\n"

  # relay 메시지 전송 (다음 AI 활성화)
  local last_cmd="$_last_user_cmd"
  if [ -z "$last_cmd" ]; then
    last_cmd=$(cat "$tmpdir/user_cmd.txt" 2>/dev/null)
  fi
  local ctx_msg="반드시 ${tmpdir}/context.md 를 열어 최신 입력을 확인한 뒤 즉시 응답하세요(추가 질문 금지). 1턴 1작업 규칙을 지키고, 결과를 context.md에 기록하세요. 이어서 작업: ${last_cmd}"
  printf '%s' "$ctx_msg" > "$tmpdir/prompt.txt"

  if [ -f "$tmpdir/started_${next_tool}.txt" ]; then
    printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool} pane에 relay 전송${rst}\n"
    _send_to_pane "${next_pane}" "${next_tool}" "$ctx_msg"
  else
    printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool} 프롬프트 갱신됨${rst}\n"
  fi
}

# ════════════════════════════════════════
# /pick N - 동시 모드 결과 채택
# ════════════════════════════════════════
_do_pick() {
  if [[ "$mode" != "parallel" ]]; then
    printf "  ${red}동시 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local pick_num="$1"
  if [[ ! "$pick_num" =~ ^[0-9]+$ ]] || [ "$pick_num" -lt 1 ] || [ "$pick_num" -gt ${#_cmd_tools[@]} ]; then
    printf "  ${red}사용법: /pick N (1~${#_cmd_tools[@]})${rst}\n"
    return
  fi
  local picked_tool="${_cmd_tools[$pick_num]}"
  local picked_icon="${_cmd_icons[$pick_num]}"

  # save picked AI's pane output
  local picked_pane="${ai_panes[$pick_num]}"
  tmux capture-pane -t "${picked_pane}" -p -S -500 > "$tmpdir/picked_output.txt" 2>/dev/null

  # copy picked AI's context as winner
  cp "$tmpdir/context_${picked_tool}.md" "$tmpdir/context_winner.md" 2>/dev/null

  # copy picked AI's diff if exists
  if [ -f "$tmpdir/diff_${picked_tool}.txt" ]; then
    cp "$tmpdir/diff_${picked_tool}.txt" "$tmpdir/diff_winner.txt" 2>/dev/null
  fi

  printf "\n  ${grn}${bld}✔ ${picked_icon} ${picked_tool} 채택됨!${rst}\n"
  printf "  ${dm}  결과 저장: ${tmpdir}/picked_output.txt${rst}\n"
  printf "  ${dm}  컨텍스트: ${tmpdir}/context_winner.md${rst}\n"

  # show diff summary if available
  local dfile="$tmpdir/diff_${picked_tool}.txt"
  if [ -f "$dfile" ] && [ -s "$dfile" ]; then
    local dstat=$(git -C "$workdir" diff --stat 2>/dev/null)
    printf "  ${cyn}${bld}📊 채택된 변경사항:${rst}\n"
    head -10 "$dfile" | while IFS= read -r dl; do
      case "$dl" in
        +*) printf "    ${grn}%s${rst}\n" "$dl" ;;
        -*) printf "    ${red}%s${rst}\n" "$dl" ;;
        *)  printf "    ${dm}%s${rst}\n" "$dl" ;;
      esac
    done
  fi
  printf "\n"
}

# ════════════════════════════════════════
# /compare - 동시 모드 결과 비교
# ════════════════════════════════════════
_do_compare() {
  local compare_ai="$1"

  if [[ "$mode" != "parallel" ]]; then
    printf "  ${red}동시 모드에서만 사용 가능합니다${rst}\n"
    return
  fi

  # /compare N — N번 AI가 다른 AI 결과를 비교해서 하나 선택
  if [ -n "$compare_ai" ] && [[ "$compare_ai" =~ ^[0-9]+$ ]]; then
    if [ "$compare_ai" -lt 1 ] || [ "$compare_ai" -gt ${#_cmd_tools[@]} ]; then
      printf "  ${red}사용법: /compare N (1~${#_cmd_tools[@]})${rst}\n"
      return
    fi
    local cai_tool="${_cmd_tools[$compare_ai]}"
    local cai_icon="${_cmd_icons[$compare_ai]}"
    local cai_pane="${ai_panes[$compare_ai]}"

    # 다른 AI들의 컨텍스트/diff 정보 수집
    local others_info=""
    for ((ci=1; ci<=${#_cmd_tools[@]}; ci++)); do
      [ "$ci" -eq "$compare_ai" ] && continue
      local oname="${_cmd_tools[$ci]}"
      local ofile="$tmpdir/context_${oname}.md"
      local odfile="$tmpdir/diff_${oname}.txt"
      others_info="${others_info}[${oname}: context=${ofile}"
      [ -f "$odfile" ] && others_info="${others_info}, diff=${odfile}"
      others_info="${others_info}] "
    done

    local compare_msg="다른 AI들의 작업 결과를 비교 분석하세요. ${others_info} 각 AI의 context 파일과 diff를 읽고, 가장 좋은 결과물을 하나 선택하세요. 선택 이유와 함께 어떤 AI의 결과가 최적인지 shared.md에 기록하세요."

    _send_to_pane "${cai_pane}" "${cai_tool}" "$compare_msg"
    printf "  ${cyn}${bld}📊 ${cai_icon} ${cai_tool}에게 비교 분석 요청${rst}\n"
    printf "  ${dm}→ 다른 AI 결과를 비교하여 최적 선택 후 shared.md에 기록${rst}\n"
    return
  fi

  # /compare (인자 없음) — 기존 비교 테이블 표시
  printf "\n  ${cyn}${bld}📊 AI 결과 비교${rst}\n"
  printf "  ${dm}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${rst}\n"

  for ((ci=1; ci<=${#_cmd_tools[@]}; ci++)); do
    local cname="${_cmd_tools[$ci]}"
    local cicon="${_cmd_icons[$ci]}"
    local cfile="$tmpdir/context_${cname}.md"
    local dfile="$tmpdir/diff_${cname}.txt"
    local sfile="$tmpdir/status_${cname}"
    local st=$(cat "$sfile" 2>/dev/null)

    printf "\n  ${cyn}${bld}${cicon} ${cname}${rst}"
    case "$st" in
      done:*) printf " ${grn}(완료 ${st#done:})${rst}" ;;
      running) printf " ${ylw}(작업중)${rst}" ;;
      *) printf " ${dm}(--)${rst}" ;;
    esac
    printf "\n"

    # show context summary
    if [ -f "$cfile" ] && [ -s "$cfile" ]; then
      local cl=$(wc -l < "$cfile" | tr -d ' ')
      printf "    ${dm}컨텍스트: ${cl}줄${rst}\n"
    fi

    # show diff summary
    if [ -f "$dfile" ] && [ -s "$dfile" ]; then
      local dl=$(wc -l < "$dfile" | tr -d ' ')
      local adds=$(grep -c '^+' "$dfile" 2>/dev/null)
      local dels=$(grep -c '^-' "$dfile" 2>/dev/null)
      printf "    ${grn}+${adds}${rst} ${red}-${dels}${rst} ${dm}(diff ${dl}줄)${rst}\n"
    else
      printf "    ${dm}(변경 없음)${rst}\n"
    fi

    # show last lines of pane output
    local pane="${ai_panes[$ci]}"
    local pout=$(tmux capture-pane -t "${pane}" -p -S -10 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -3)
    if [ -n "$pout" ]; then
      echo "$pout" | while IFS= read -r pl; do
        printf "    ${dm}│ %.60s${rst}\n" "$pl"
      done
    fi
  done

  printf "\n  ${ylw}${bld}/pick N${rst} 직접 채택  ${ylw}${bld}/compare N${rst} AI가 선택  ${ylw}${bld}/merge N${rst} AI가 종합\n\n"
}

# ════════════════════════════════════════
# /board - 협동 모드 공유보드 확인
# ════════════════════════════════════════
_do_board() {
  if [[ "$mode" != "collaborative" ]]; then
    printf "  ${red}협동 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  printf "\n  ${grn}${bld}📋 공유 보드 (shared.md):${rst}\n"
  printf "  ${dm}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${rst}\n"
  local sfile="$tmpdir/shared.md"
  if [ -f "$sfile" ] && [ -s "$sfile" ]; then
    cat "$sfile" | while IFS= read -r sl; do
      printf "  ${dm}%s${rst}\n" "$sl"
    done
  else
    printf "  ${dm}(비어 있음 - AI가 작업 내용을 기록하면 여기에 표시됩니다)${rst}\n"
  fi
  printf "\n"
}

# ════════════════════════════════════════
# /clear - 화면 지우기
# ════════════════════════════════════════
_do_clear() {
  printf "\033[H\033[2J"
  _show_status
}

# ════════════════════════════════════════
# /dash - 전체화면 대시보드
# ════════════════════════════════════════
_do_dashboard() {
  printf "\033[H\033[2J"
  printf "  ${prp}${bld}┏━━━━━━━━━━━━━━━━━ BATTLE DASHBOARD ━━━━━━━━━━━━━━━━━┓${rst}\n"

  # 1. AI 상태
  printf "  ${prp}${bld}┃${rst} ${grn}${bld}📊 AI Status${rst}                                       ${prp}${bld}┃${rst}\n"
  for ((pi=1; pi<=${#_cmd_tools[@]}; pi++)); do
    local pname="${_cmd_tools[$pi]}"
    local picon="${_cmd_icons[$pi]}"
    local pstatus=$(cat "$tmpdir/status_${pname}" 2>/dev/null)
    local prole=""
    [[ "$mode" == "collaborative" ]] && prole=" (${_cmd_roles[$pi]:-})"
    local scolor="${dm}" stxt="--"
    case "$pstatus" in
      done:*)  scolor="${grn}"; stxt="✔ ${pstatus#done:}" ;;
      running) scolor="${ylw}"; stxt="⣾ 작업중" ;;
      waiting) scolor="${dm}";  stxt="⏳ 대기" ;;
    esac
    printf "  ${prp}${bld}┃${rst}   ${picon} %-10s${ylw}%-14s${rst} ${scolor}%-16s${rst}  ${prp}${bld}┃${rst}\n" "$pname" "$prole" "$stxt"
  done

  printf "  ${prp}${bld}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫${rst}\n"

  # 2. 최근 활동 (shared.md)
  printf "  ${prp}${bld}┃${rst} ${ylw}${bld}📝 Recent Activity${rst}                                 ${prp}${bld}┃${rst}\n"
  local sfile="$tmpdir/shared.md"
  if [ -f "$sfile" ] && [ -s "$sfile" ]; then
    grep -v "^#" "$sfile" | grep -v "^---" | sed '/^[[:space:]]*$/d' | tail -5 | while IFS= read -r sl; do
      printf "  ${prp}${bld}┃${rst}  ${dm}%-49s${rst}${prp}${bld}┃${rst}\n" "${sl:0:49}"
    done
  else
    printf "  ${prp}${bld}┃${rst} ${dm}    (No recent activity)${rst}                          ${prp}${bld}┃${rst}\n"
  fi

  printf "  ${prp}${bld}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${rst}\n"
  printf "\n  ${dm}아무 키를 누르면 돌아갑니다...${rst}"
  read -rs -k1
  printf "\033[H\033[2J"
  _show_status
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
  local merge_ai="$1"

  # ── 동시 모드: /merge N → N번 AI가 모든 결과 종합 ──
  if [[ "$mode" == "parallel" ]]; then
    if [ -z "$merge_ai" ] || ! [[ "$merge_ai" =~ ^[0-9]+$ ]] || [ "$merge_ai" -lt 1 ] || [ "$merge_ai" -gt ${#_cmd_tools[@]} ]; then
      printf "  ${red}사용법: /merge N (1~${#_cmd_tools[@]}) — N번 AI가 모든 결과 종합${rst}\n"
      return
    fi
    local mai_tool="${_cmd_tools[$merge_ai]}"
    local mai_icon="${_cmd_icons[$merge_ai]}"
    local mai_pane="${ai_panes[$merge_ai]}"

    # 다른 AI들의 컨텍스트/diff 정보 수집
    local others_info=""
    for ((mi=1; mi<=${#_cmd_tools[@]}; mi++)); do
      [ "$mi" -eq "$merge_ai" ] && continue
      local oname="${_cmd_tools[$mi]}"
      local ofile="$tmpdir/context_${oname}.md"
      local odfile="$tmpdir/diff_${oname}.txt"
      others_info="${others_info}[${oname}: context=${ofile}"
      [ -f "$odfile" ] && others_info="${others_info}, diff=${odfile}"
      others_info="${others_info}] "
    done

    local merge_msg="다른 AI들의 작업 결과를 모두 분석하고 종합하세요. ${others_info} 각 AI의 context 파일과 diff를 읽고, 모든 AI의 좋은 부분을 합쳐서 최종 결과물을 만드세요. 종합 결과와 각 AI에서 가져온 부분을 shared.md에 기록하세요."

    _send_to_pane "${mai_pane}" "${mai_tool}" "$merge_msg"
    printf "  ${grn}${bld}🔀 ${mai_icon} ${mai_tool}에게 종합 요청${rst}\n"
    printf "  ${dm}→ 모든 AI 결과를 분석하여 최종본 작성 후 shared.md에 기록${rst}\n"
    return
  fi

  # ── 협동 모드: git branch merge ──
  if [[ "$mode" != "collaborative" ]]; then
    printf "  ${red}동시/co-op 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  cd "$workdir"
  local merged=0 conflicts=0
  printf "\n  ${cyn}${bld}🔀 Co-op 브랜치 머지 시작${rst}\n"
  for ((mi=1; mi<=${#_cmd_tools[@]}; mi++)); do
    local branch="battle-coop-${_cmd_tools[$mi]}"
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
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
bindkey '^?' backward-delete-char 2>/dev/null
bindkey '^H' backward-delete-char 2>/dev/null
bindkey '\b' backward-delete-char 2>/dev/null

# ensure correct terminal width for vared line wrapping
COLUMNS=$(tmux display-message -p '#{pane_width}' 2>/dev/null || tput cols 2>/dev/null || echo 80)
trap 'COLUMNS=$(tmux display-message -p "#{pane_width}" 2>/dev/null || tput cols 2>/dev/null || echo 80)' WINCH

# ── command history + arrow key widgets ──
typeset -a _cmd_history
_last_user_cmd="$prompt"
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

# ════════════════════════════════════════
# AUTO-NEXT
# ════════════════════════════════════════
_auto_pid=""

_auto_get_mtime() {
  stat -f %m "$tmpdir"/context*.md 2>/dev/null | sort -rn | head -1
}

_auto_start() {
  local settle="${1:-10}"
  _auto_stop 2>/dev/null
  (
    local last_mtime=$(_auto_get_mtime)
    [ -z "$last_mtime" ] && last_mtime="0"
    local ctx_changed=false
    local last_pane_hash=""
    local last_pane_change_ts=$(date +%s)

    while true; do
      sleep 2
      local cur_mtime=$(_auto_get_mtime)
      [ -z "$cur_mtime" ] && cur_mtime="0"

      # ── context 변경 감지 ──
      if [[ "$cur_mtime" != "$last_mtime" ]]; then
        ctx_changed=true
        last_mtime="$cur_mtime"
      fi

      # ── pane 변경 감지 (현재 턴 AI의 pane hash) ──
      local cur_pane_hash=""
      if [[ "$mode" == "sequential" ]]; then
        local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
        if [ -n "$cur" ]; then
          local cur_tool_idx=${_cmd_seq_order[$cur]}
          if [ -n "$cur_tool_idx" ]; then
            local cur_pane="${ai_panes[$cur_tool_idx]}"
            local pane_out=$(tmux capture-pane -t "${cur_pane}" -p -S -30 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 30)
            if [ -n "$pane_out" ]; then
              cur_pane_hash=$(printf '%s' "$pane_out" | shasum -a 256 | awk '{print $1}')
            fi
          fi
        fi
      fi

      # pane 변경 시 타임스탬프 갱신
      if [ -n "$cur_pane_hash" ] && [[ "$cur_pane_hash" != "$last_pane_hash" ]]; then
        last_pane_hash="$cur_pane_hash"
        last_pane_change_ts=$(date +%s)
      fi

      # ── AND 조건: context 변경됨 + pane이 settle초간 안정 ──
      if $ctx_changed; then
        local now=$(date +%s)
        local pane_stable_secs=$(( now - last_pane_change_ts ))
        local remaining=$(( settle - pane_stable_secs ))

        if (( remaining > 0 )); then
          printf "\033[s\033[2;1H\033[2K  ${dm}⏳ context 변경 감지 — pane 안정화 대기 ${remaining}s ...${rst}\033[u"
        else
          # settle 완료 — 최종 확인
          printf "\033[s\033[2;1H\033[2K\033[u"
          local final_mtime=$(_auto_get_mtime)
          if [[ "$final_mtime" == "$last_mtime" ]]; then
            # context도 pane도 안정화됨 → /next 실행
            printf "\n  ${cyn}${bld}🔄 context+pane 안정화 → /next 자동 실행${rst}\n"
            _do_next
            last_mtime=$(_auto_get_mtime)
            ctx_changed=false
            last_pane_hash=""
            last_pane_change_ts=$(date +%s)
          else
            # context가 다시 변경됨 — 리셋
            last_mtime="$final_mtime"
          fi
        fi
      fi
    done
  ) &
  _auto_pid=$!
  printf "  ${grn}${bld}✔ /auto 시작${rst} ${dm}(context+pane AND 감지, settle=${settle}s)${rst}\n"
}

_auto_stop() {
  if [ -n "$_auto_pid" ] && kill -0 "$_auto_pid" 2>/dev/null; then
    kill "$_auto_pid" 2>/dev/null
    wait "$_auto_pid" 2>/dev/null
    printf "  ${ylw}⏹ /auto 중지됨${rst}\n"
  fi
  _auto_pid=""
}

# ════════════════════════════════════════
# PRIORITY WATCHER (협동 모드 우선순위 캐스케이드)
# ════════════════════════════════════════
_priority_watcher_pid=""

_priority_watcher_stop() {
  if [ -n "$_priority_watcher_pid" ] && kill -0 "$_priority_watcher_pid" 2>/dev/null; then
    kill "$_priority_watcher_pid" 2>/dev/null
    wait "$_priority_watcher_pid" 2>/dev/null
  fi
  _priority_watcher_pid=""
}

# 역할 → 우선순위 (collaborative.zsh의 _mode_role_priority 재사용)
_get_role_priority() {
  local role="$1"
  case "$role" in
    "Lead Dev"|Core|Frontend|Backend|DB|API|Debug|Migration) echo 1 ;;
    Reviewer|Review|Security|Refactor|Perf|Architect)        echo 2 ;;
    "Test/Ops"|Tests|Config|Docs|A11y|i18n)                  echo 3 ;;
    *)                                                        echo 1 ;;
  esac
}

# AI 목록을 우선순위로 정렬하여 인덱스 배열 반환
_get_priority_sorted_indices() {
  local -a pairs=()
  for ((pi=1; pi<=${#_cmd_tools[@]}; pi++)); do
    local p=$(_get_role_priority "${_cmd_roles[$pi]}")
    pairs+=("${p}:${pi}")
  done
  echo "${(j: :)${(@o)pairs}}" | tr ' ' '\n' | while IFS=: read -r _p _i; do
    printf "%s " "$_i"
  done
}

# 우선순위 캐스케이드 워처 시작
_priority_watcher_start() {
  local user_cmd="$1"
  local settle=10
  _priority_watcher_stop
  rm -f "$tmpdir/needs_review.txt"

  # 우선순위 정렬된 인덱스 목록
  local sorted_indices=($(_get_priority_sorted_indices))
  local total=${#sorted_indices[@]}

  # 1순위에만 원래 커맨드 전송
  local first_idx=${sorted_indices[1]}
  local first_pane="${ai_panes[$first_idx]}"
  local first_tool="${_cmd_tools[$first_idx]}"
  local first_pri=$(_get_role_priority "${_cmd_roles[$first_idx]}")
  _send_to_pane "${first_pane}" "${first_tool}" "$user_cmd"
  printf "  ${grn}${bld}▶ P${first_pri} ${_cmd_icons[$first_idx]} ${first_tool}${rst} ${dm}← 커맨드 전송${rst}\n"

  if [ "$total" -le 1 ]; then
    return
  fi

  # 나머지를 큐 파일에 기록
  : > "$tmpdir/priority_queue.txt"
  for ((qi=2; qi<=total; qi++)); do
    echo "${sorted_indices[$qi]}" >> "$tmpdir/priority_queue.txt"
  done
  printf '%s' "$user_cmd" > "$tmpdir/priority_user_cmd.txt"

  # 백그라운드 워처: pane 안정화 감지 → 다음 순위 활성화
  (
    local watch_idx=$first_idx
    local watch_pane=$first_pane
    local watch_tool=$first_tool
    local last_pane_hash=""
    local last_pane_change_ts=$(date +%s)

    while true; do
      sleep 2

      # pane hash 계산
      local cur_pane_hash=""
      local pane_out=$(tmux capture-pane -t "${watch_pane}" -p -S -30 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 30)
      if [ -n "$pane_out" ]; then
        cur_pane_hash=$(printf '%s' "$pane_out" | shasum -a 256 | awk '{print $1}')
      fi

      # pane 변경 시 타임스탬프 갱신
      if [ -n "$cur_pane_hash" ] && [[ "$cur_pane_hash" != "$last_pane_hash" ]]; then
        last_pane_hash="$cur_pane_hash"
        last_pane_change_ts=$(date +%s)
      fi

      # settle 체크
      local now=$(date +%s)
      local pane_stable_secs=$(( now - last_pane_change_ts ))

      if (( pane_stable_secs >= settle )); then
        # 큐에서 다음 AI 꺼내기
        local next_qi=$(head -1 "$tmpdir/priority_queue.txt" 2>/dev/null)

        if [ -z "$next_qi" ]; then
          local orig_cmd=$(cat "$tmpdir/priority_user_cmd.txt" 2>/dev/null)
          printf "\n  ${grn}${bld}✔ 캐스케이드 완료${rst} ${dm}— 우선순위 큐 소진${rst}\n"
          printf "  ${dm}  \"%.40s...\"${rst}\n" "$orig_cmd"

          # 종합 검토: 플래그 등록 → 모든 AI pane 안정화 대기 → 1순위에게 요약 요청
          printf '%s' "$$" > "$tmpdir/needs_review.txt"
          printf "  ${dm}⏳ 전체 AI 안정화 대기 중...${rst}\n"
          local -a all_hashes all_stable_ts
          local all_now=$(date +%s)
          for ((ai=1; ai<=${#ai_panes[@]}; ai++)); do
            all_hashes[$ai]=""
            all_stable_ts[$ai]=$all_now
          done

          local all_settled=false
          while true; do
            sleep 2
            # 새 커맨드로 인해 워처가 교체되었으면 종료
            if [ ! -f "$tmpdir/needs_review.txt" ]; then break; fi
            local rv_owner=$(cat "$tmpdir/needs_review.txt" 2>/dev/null)
            if [[ "$rv_owner" != "$$" ]]; then break; fi

            local everyone_stable=true
            all_now=$(date +%s)
            for ((ai=1; ai<=${#ai_panes[@]}; ai++)); do
              local ah=""
              local ah_out=$(tmux capture-pane -t "${ai_panes[$ai]}" -p -S -30 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 30)
              [ -n "$ah_out" ] && ah=$(printf '%s' "$ah_out" | shasum -a 256 | awk '{print $1}')
              if [ -n "$ah" ] && [[ "$ah" != "${all_hashes[$ai]}" ]]; then
                all_hashes[$ai]="$ah"
                all_stable_ts[$ai]=$all_now
              fi
              local ae=$(( all_now - ${all_stable_ts[$ai]} ))
              if (( ae < settle )); then
                everyone_stable=false
              fi
            done

            if $everyone_stable; then
              all_settled=true
              break
            fi
          done

          if $all_settled; then
            # 최종 확인: 아직 이 워처가 유효한지 (새 커맨드 없었는지)
            local rv_owner=$(cat "$tmpdir/needs_review.txt" 2>/dev/null)
            if [[ "$rv_owner" == "$$" ]]; then
              rm -f "$tmpdir/needs_review.txt"
              local review_msg="[종합 검토 단계] 모든 AI의 작업이 완료되었습니다. 다음을 수행하세요:
1. shared.md와 각 AI의 context 파일을 확인하여 전체 작업 결과를 요약
2. 다른 AI의 브랜치를 git diff로 비교하여 유용한 변경사항을 식별
3. 유용한 코드(보안패치, 테스트, 신규모듈 등)는 cherry-pick 또는 수동으로 흡수
4. 중복 구현이나 불필요한 변경은 버리고 사유를 기록
5. 최종 결과를 shared.md에 정리 (흡수한 항목, 버린 항목, 종합 요약)
참고: git log --all --oneline 으로 다른 브랜치 확인 가능"
              _send_to_pane "${first_pane}" "${first_tool}" "$review_msg"
              printf "\n  ${cyn}${bld}📋 종합 검토${rst} ${dm}— P${first_pri} ${_cmd_icons[$first_idx]} ${first_tool}에게 요약 요청${rst}\n"

              # 1순위 AI 안정화 대기
              last_pane_hash=""
              last_pane_change_ts=$(date +%s)
              while true; do
                sleep 2
                local cur_pane_hash=""
                local pane_out=$(tmux capture-pane -t "${first_pane}" -p -S -30 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 30)
                [ -n "$pane_out" ] && cur_pane_hash=$(printf '%s' "$pane_out" | shasum -a 256 | awk '{print $1}')
                if [ -n "$cur_pane_hash" ] && [[ "$cur_pane_hash" != "$last_pane_hash" ]]; then
                  last_pane_hash="$cur_pane_hash"
                  last_pane_change_ts=$(date +%s)
                fi
                local now=$(date +%s)
                local pane_stable_secs=$(( now - last_pane_change_ts ))
                if (( pane_stable_secs >= settle )); then
                  break
                fi
              done
              printf "\n  ${grn}${bld}✔ 종합 검토 완료${rst}\n"
            fi
          fi

          printf '\a'
          break
        fi

        # 큐에서 첫 줄 제거
        tail -n +2 "$tmpdir/priority_queue.txt" > "$tmpdir/priority_queue.tmp" 2>/dev/null
        mv "$tmpdir/priority_queue.tmp" "$tmpdir/priority_queue.txt" 2>/dev/null

        local next_pane="${ai_panes[$next_qi]}"
        local next_tool="${_cmd_tools[$next_qi]}"
        local next_pri=$(_get_role_priority "${_cmd_roles[$next_qi]}")
        local orig_cmd=$(cat "$tmpdir/priority_user_cmd.txt" 2>/dev/null)
        local relay_msg="${orig_cmd}. shared.md 확인하고 역할에 맞게 작업을 수행하세요. 추천 및 제안사항이 있는 경우 shared.md에 남기세요."

        _send_to_pane "${next_pane}" "${next_tool}" "$relay_msg"
        printf "\n  ${grn}${bld}▶ P${next_pri} ${_cmd_icons[$next_qi]} ${next_tool}${rst} ${dm}← 캐스케이드 활성화 (${watch_tool} 안정화 ${settle}s)${rst}\n"

        # 다음 감시 대상으로 전환
        watch_idx=$next_qi
        watch_pane=$next_pane
        watch_tool=$next_tool
        last_pane_hash=""
        last_pane_change_ts=$(date +%s)
      fi
    done
  ) &
  _priority_watcher_pid=$!
  printf "  ${dm}→ 우선순위 캐스케이드 워처 시작 (settle=${settle}s)${rst}\n"
}

# ════════════════════════════════════════
# PARALLEL COMPLETION WATCHER (동시 모드 전체 완료 감지)
# ════════════════════════════════════════
_parallel_watcher_pid=""

_parallel_watcher_stop() {
  if [ -n "$_parallel_watcher_pid" ] && kill -0 "$_parallel_watcher_pid" 2>/dev/null; then
    kill "$_parallel_watcher_pid" 2>/dev/null
    wait "$_parallel_watcher_pid" 2>/dev/null
  fi
  _parallel_watcher_pid=""
}

_parallel_watcher_start() {
  local settle=10
  _parallel_watcher_stop

  (
    local -a last_hashes
    local -a stable_since
    local now=$(date +%s)
    for ((wi=1; wi<=${#ai_panes[@]}; wi++)); do
      last_hashes[$wi]=""
      stable_since[$wi]=$now
    done

    while true; do
      sleep 2
      local all_stable=true
      now=$(date +%s)

      for ((wi=1; wi<=${#ai_panes[@]}; wi++)); do
        local pout=$(tmux capture-pane -t "${ai_panes[$wi]}" -p -S -30 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 30)
        local cur_hash=""
        [ -n "$pout" ] && cur_hash=$(printf '%s' "$pout" | shasum -a 256 | awk '{print $1}')

        if [ -n "$cur_hash" ] && [[ "$cur_hash" != "${last_hashes[$wi]}" ]]; then
          last_hashes[$wi]="$cur_hash"
          stable_since[$wi]=$now
        fi

        local elapsed=$(( now - ${stable_since[$wi]} ))
        if (( elapsed < settle )); then
          all_stable=false
        fi
      done

      if $all_stable; then
        printf "\n  ${grn}${bld}✔ 모든 AI 작업 완료${rst}\n"
        printf "  ${ylw}${bld}  /pick N${rst}     ${dm}— N번 AI 결과 직접 채택${rst}\n"
        printf "  ${ylw}${bld}  /compare N${rst}  ${dm}— N번 AI가 비교 후 최적 선택${rst}\n"
        printf "  ${ylw}${bld}  /merge N${rst}    ${dm}— N번 AI가 모든 결과 종합${rst}\n"
        printf '\a'  # Terminal Bell
        break
      fi
    done
  ) &
  _parallel_watcher_pid=$!
}

# ════════════════════════════════════════
# AUTO-NEXT: auto-start in sequential mode
# ════════════════════════════════════════
if [[ "$mode" == "sequential" ]]; then
  _auto_start 10
  printf "  ${cyn}${bld}🔄 /auto 자동 활성화 (순차모드, settle=10s)${rst}\n"
fi

# ════════════════════════════════════════
# INPUT LOOP
# ════════════════════════════════════════
while true; do
  input=""
  # tmux pane 실제 너비로 COLUMNS 갱신 (줄바꿈 정확도 향상)
  local _pw=$(tmux display-message -p '#{pane_width}' 2>/dev/null)
  [ -n "$_pw" ] && COLUMNS="$_pw" || COLUMNS=$(tput cols 2>/dev/null || echo 80)
  if vared -p "  %{${prp}${bld}%}▸%{${rst}%} " -c input 2>/dev/null; then
    printf '\033[J'
  else
    printf "  ${prp}${bld}▸${rst} "
    read -r input || break
  fi

  if [[ -n "$input" ]]; then
    _cmd_history+=("$input")
    # 슬래시 명령어가 아닌 경우에만 last_user_cmd 갱신
    if [[ "$input" != /* ]]; then
      _last_user_cmd="$input"
      printf '%s' "$input" > "$tmpdir/user_cmd.txt"
    fi
    _cmd_hist_idx=0
  fi

  case "$input" in
    /clear)
      _do_clear
      ;;
    /dash|/dashboard)
      _do_dashboard
      ;;
    /quit)
      _auto_stop
      printf "  ${red}세션을 종료합니다...${rst}\n"
      tmux kill-session -t "$session" 2>/dev/null
      break
      ;;
    /status)
      _show_status
      ;;
    /history)
      printf "\n  ${prp}${bld}📋 명령어 기록:${rst}\n"
      for ((hi=1; hi<=${#_cmd_history[@]}; hi++)); do
        printf "    ${dm}%d)${rst} %s\n" "$hi" "${_cmd_history[$hi]}"
      done
      printf "\n"
      ;;
    /cat\ *)
      local filename="${input#/cat }"
      if [ -z "$filename" ]; then
        printf "  ${red}사용법: /cat FILE${rst}\n"
      else
        printf "\n  ${cyn}${bld}📄 파일 내용: ${filename}${rst}\n"
        if [[ "$mode" == "collaborative" ]]; then
          for ((ci=1; ci<=${#_cmd_tools[@]}; ci++)); do
            local cname="${_cmd_tools[$ci]}"
            local cicon="${_cmd_icons[$ci]}"
            local cfile="$tmpdir/work_${cname}/${filename}"
            printf "  ${cyn}${bld}${cicon} ${cname}${rst}\n"
            if [ -f "$cfile" ]; then
              head -30 "$cfile" | while IFS= read -r line; do
                printf "    ${dm}%s${rst}\n" "$line"
              done
              local total_l=$(wc -l < "$cfile" | tr -d ' ')
              [ "$total_l" -gt 30 ] && printf "    ${dm}... (총 ${total_l}줄)${rst}\n"
            else
              printf "    ${dm}(파일 없음)${rst}\n"
            fi
            printf "\n"
          done
        else
          local cfile="${workdir}/${filename}"
          if [ -f "$cfile" ]; then
            head -50 "$cfile" | while IFS= read -r line; do
              printf "    ${dm}%s${rst}\n" "$line"
            done
            local total_l=$(wc -l < "$cfile" | tr -d ' ')
            [ "$total_l" -gt 50 ] && printf "    ${dm}... (총 ${total_l}줄)${rst}\n"
          else
            printf "    ${red}(파일 없음: ${cfile})${rst}\n"
          fi
          printf "\n"
        fi
      fi
      ;;
    /grep\ *)
      local pattern="${input#/grep }"
      printf "\n  ${cyn}${bld}🔍 검색: ${pattern}${rst}\n"
      if [[ "$mode" == "collaborative" ]]; then
        for ((ci=1; ci<=${#_cmd_tools[@]}; ci++)); do
          local cname="${_cmd_tools[$ci]}"
          local cicon="${_cmd_icons[$ci]}"
          local cworkdir="$tmpdir/work_${cname}"
          printf "  ${cyn}${bld}${cicon} ${cname}${rst}\n"
          grep -rnI --color=always "$pattern" "$cworkdir" 2>/dev/null | head -10 | while IFS= read -r line; do
            printf "    ${dm}%s${rst}\n" "${line#$cworkdir/}"
          done
          printf "\n"
        done
      else
        grep -rnI --color=always "$pattern" "$workdir" 2>/dev/null | head -20 | while IFS= read -r line; do
          printf "  ${dm}%s${rst}\n" "${line#$workdir/}"
        done
        printf "\n"
      fi
      ;;
    /save)
      _do_save
      ;;
    /diff)
      _show_diffs
      ;;
    /ctx)
      _do_ctx
      ;;
    /next|/next\ *)
      local next_prompt="${input#/next}"
      next_prompt="${next_prompt# }"
      # 숫자만 입력된 경우 N번 반복 실행
      if [[ "$next_prompt" =~ ^[0-9]+$ ]] && [ "$next_prompt" -gt 1 ]; then
        local repeat_count="$next_prompt"
        printf "  ${cyn}${bld}🔁 /next ${repeat_count}회 반복 실행${rst}\n"
        for ((ri=1; ri<=repeat_count; ri++)); do
          printf "  ${dm}── 반복 ${ri}/${repeat_count} ──${rst}\n"
          _do_next
          [ "$ri" -lt "$repeat_count" ] && sleep 1
        done
      else
        _do_next $next_prompt
      fi
      ;;
    /skip)
      _do_skip
      ;;
    /auto|/auto\ *)
      local auto_args="${input#/auto}"
      auto_args="${auto_args# }"
      if [[ "$auto_args" == "stop" ]]; then
        _auto_stop
      elif [[ "$auto_args" =~ ^[0-9]+$ ]]; then
        _auto_start "$auto_args"
      elif [[ -z "$auto_args" ]]; then
        _auto_start 10
      else
        printf "  ${dm}사용법: /auto [settle초] | /auto stop${rst}\n"
      fi
      ;;
    /pick\ *)
      local pick_num="${input#/pick }"
      _do_pick "$pick_num"
      ;;
    /compare|/compare\ *)
      local compare_arg="${input#/compare}"
      compare_arg="${compare_arg# }"
      _do_compare "$compare_arg"
      ;;
    /board)
      _do_board
      ;;
    /merge|/merge\ *)
      local merge_arg="${input#/merge}"
      merge_arg="${merge_arg# }"
      _do_merge "$merge_arg"
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
      printf "\n  ${cyn}${bld}공통:${rst}\n"
      printf "  ${ylw}/status${rst}  상태  ${ylw}/diff${rst}  변경사항  ${ylw}/save${rst}  저장\n"
      printf "  ${ylw}/ctx${rst}    컨텍스트 확인  ${ylw}/prompt X${rst} 프롬프트 변경\n"
      printf "  ${ylw}/auto${rst}   context 변경 감지→자동 /next  ${ylw}/auto stop${rst} 중지\n"
      printf "  ${ylw}/focus N${rst} 포커스  ${ylw}/mode X${rst} 모드변경 ${dm}(p/s/c)${rst}\n"
      printf "  ${ylw}/clear${rst}  화면 지우기  ${ylw}/dash${rst}  대시보드\n"
      printf "  ${ylw}/quit${rst}   종료\n"
      
      _mode_help_text

      printf "  ${dm}↑/↓ 화살표: 이전 입력${rst}\n\n"
      ;;
    /*)
      printf "  ${red}알 수 없는 명령어: ${input}${rst}  ${dm}/help 참고${rst}\n"
      ;;
    "")
      ;;
    *)
      if [[ "$mode" == "sequential" ]]; then
        # send only to current active AI
        local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
        if [ $cur -ge 1 ] && [ $cur -le ${#_cmd_seq_order[@]} ]; then
          local cur_tool_idx=${_cmd_seq_order[$cur]}
          local target_pane="${ai_panes[$cur_tool_idx]}"
          _send_to_pane "${target_pane}" "${_cmd_tools[$cur_tool_idx]}" "$input"
          printf "  ${dm}→ ${_cmd_icons[$cur_tool_idx]} ${_cmd_tools[$cur_tool_idx]}에 전송됨${rst}\n"
        else
          printf "  ${red}현재 활성 AI가 없습니다${rst}\n"
        fi
      elif [[ "$_mode_input_routing" == "priority" ]]; then
        # collaborative priority: 1순위만 먼저, 나머지 캐스케이드
        _priority_watcher_stop
        _priority_watcher_start "$input"
      else
        # parallel: broadcast to all
        _parallel_watcher_stop
        for ((pi=1; pi<=${#ai_panes[@]}; pi++)); do
          _send_to_pane "${ai_panes[$pi]}" "${_cmd_tools[$pi]}" "$input"
        done
        printf "  ${dm}→ ${#ai_panes[@]}개 AI에 전송됨${rst}\n"
        _parallel_watcher_start
      fi
      ;;
  esac
done
