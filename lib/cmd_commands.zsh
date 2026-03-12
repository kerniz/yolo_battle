#!/bin/zsh
# ════════════════════════════════════════
# cmd_commands.zsh — All slash command handlers
# Sourced at runtime by cmd_center.sh
# ════════════════════════════════════════

# ── /save ──
_do_save() {
  mkdir -p "$savedir"
  for ((si=0; si<${#ai_panes[@]}; si++)); do
    local pidx="${ai_panes[$((si+1))]}"
    local tname="${_cmd_tools[$((si+1))]}"
    tmux capture-pane -t "${pidx}" -p -S -500 > "$savedir/${tname}.txt" 2>/dev/null
  done
  cp "$tmpdir/prompt.txt" "$savedir/prompt.txt" 2>/dev/null
  cp "$tmpdir/mode.txt" "$savedir/mode.txt" 2>/dev/null
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

# ── /ctx ──
_do_ctx() {
  _mode_do_ctx "$tmpdir" "$cnt" "${_cmd_tools[@]}" "${_cmd_icons[@]}"
}

# ── /next (순차 모드) ──
_do_next() {
  if [[ "$mode" != "sequential" ]]; then
    printf "  ${red}순차 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
  local new_prompt="$*"
  local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
  local round=$(cat "$tmpdir/round.txt" 2>/dev/null || echo "1")

  # Capture current turn's output before advancing
  if [ "$cur" -ge 1 ]; then
    local cur_tool_idx=${_cmd_seq_order[$cur]}
    local cur_pane="${ai_panes[$cur_tool_idx]}"
    local cur_tool="${_cmd_tools[$cur_tool_idx]}"
    local log_flag="$tmpdir/logged_R${round}_T${cur}.txt"

    if [ ! -f "$log_flag" ]; then
      printf "  ${dm}→ %s의 결과 캡처 중...${rst}\n" "$cur_tool"
      local pane_out=$(_capture_pane "${cur_pane}" 50)
      local changed_files=$(git diff HEAD~1..HEAD --name-only 2>/dev/null)
      {
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📍 ROUND ${round} | TURN ${cur} | AGENT: ${cur_tool} (MANUAL NEXT)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        [ -n "$changed_files" ] && echo "📂 Modified Files:" && echo "$changed_files" | sed 's/^/- /' && echo ""
        echo "💬 Last Output:"
        echo '```'
        echo "$pane_out" | perl -pe 's/\x1b\[[0-9;]*[mGKH]//g' 2>/dev/null || echo "$pane_out"
        echo '```'
        echo ""
      } >> "$tmpdir/log.md"
      touch "$log_flag"
    fi
  fi

  # calculate next turn (round-robin)
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

  printf '%s' "$ctx_msg" > "$tmpdir/prompt.txt"

  if [ -f "$tmpdir/started_${next_tool}.txt" ]; then
    printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool} pane에 relay 전송${rst}\n"
    _send_to_pane "${next_pane}" "${next_tool}" "$ctx_msg"
  else
    printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool} 프롬프트 갱신됨${rst}\n"
  fi
}

# ── /skip (순차 모드) ──
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

# ── /pick N (동시 모드) ──
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
  local picked_pane="${ai_panes[$pick_num]}"
  tmux capture-pane -t "${picked_pane}" -p -S -500 > "$tmpdir/picked_output.txt" 2>/dev/null
  cp "$tmpdir/context_${picked_tool}.md" "$tmpdir/context_winner.md" 2>/dev/null
  if [ -f "$tmpdir/diff_${picked_tool}.txt" ]; then
    cp "$tmpdir/diff_${picked_tool}.txt" "$tmpdir/diff_winner.txt" 2>/dev/null
  fi

  printf "\n  ${grn}${bld}✔ ${picked_icon} ${picked_tool} 채택됨!${rst}\n"
  printf "  ${dm}  결과 저장: ${tmpdir}/picked_output.txt${rst}\n"
  printf "  ${dm}  컨텍스트: ${tmpdir}/context_winner.md${rst}\n"

  local dfile="$tmpdir/diff_${picked_tool}.txt"
  if [ -f "$dfile" ] && [ -s "$dfile" ]; then
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

# ── /compare (동시 모드) ──
_do_compare() {
  local compare_ai="$1"

  if [[ "$mode" != "parallel" ]]; then
    printf "  ${red}동시 모드에서만 사용 가능합니다${rst}\n"
    return
  fi

  # /compare N — N번 AI가 다른 AI 결과를 비교
  if [ -n "$compare_ai" ] && [[ "$compare_ai" =~ ^[0-9]+$ ]]; then
    if [ "$compare_ai" -lt 1 ] || [ "$compare_ai" -gt ${#_cmd_tools[@]} ]; then
      printf "  ${red}사용법: /compare N (1~${#_cmd_tools[@]})${rst}\n"
      return
    fi
    local cai_tool="${_cmd_tools[$compare_ai]}"
    local cai_icon="${_cmd_icons[$compare_ai]}"
    local cai_pane="${ai_panes[$compare_ai]}"

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

  # /compare (인자 없음) — 비교 테이블 표시
  printf "\n  ${cyn}${bld}📊 AI 결과 비교${rst}\n"
  printf "  ${dm}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${rst}\n"

  for ((ci=1; ci<=${#_cmd_tools[@]}; ci++)); do
    local cname="${_cmd_tools[$ci]}"
    local cicon="${_cmd_icons[$ci]}"
    local cfile="$tmpdir/context_${cname}.md"
    local dfile="$tmpdir/diff_${cname}.txt"
    local st=$(_read_status "$cname")

    printf "\n  ${cyn}${bld}${cicon} ${cname}${rst}"
    case "$st" in
      done:*) printf " ${grn}(완료 ${st#done:})${rst}" ;;
      running) printf " ${ylw}(작업중)${rst}" ;;
      *) printf " ${dm}(--)${rst}" ;;
    esac
    printf "\n"

    if [ -f "$cfile" ] && [ -s "$cfile" ]; then
      local cl=$(wc -l < "$cfile" | tr -d ' ')
      printf "    ${dm}컨텍스트: ${cl}줄${rst}\n"
    fi
    if [ -f "$dfile" ] && [ -s "$dfile" ]; then
      local dl=$(wc -l < "$dfile" | tr -d ' ')
      local adds=$(grep -c '^+' "$dfile" 2>/dev/null)
      local dels=$(grep -c '^-' "$dfile" 2>/dev/null)
      printf "    ${grn}+${adds}${rst} ${red}-${dels}${rst} ${dm}(diff ${dl}줄)${rst}\n"
    else
      printf "    ${dm}(변경 없음)${rst}\n"
    fi

    local pout=$(_capture_pane "${ai_panes[$ci]}" 10)
    if [ -n "$pout" ]; then
      echo "$pout" | tail -3 | while IFS= read -r pl; do
        printf "    ${dm}│ %.60s${rst}\n" "$pl"
      done
    fi
  done

  printf "\n  ${ylw}${bld}/pick N${rst} 직접 채택  ${ylw}${bld}/compare N${rst} AI가 선택  ${ylw}${bld}/merge N${rst} AI가 종합\n\n"
}

# ── /board (협동 모드) ──
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

# ── /clear ──
_do_clear() {
  printf "\033[H\033[2J"
  _show_status
}

# ── /dash ──
_do_dashboard() {
  printf "\033[H\033[2J"
  printf "  ${prp}${bld}┏━━━━━━━━━━━━━━━━━ BATTLE DASHBOARD ━━━━━━━━━━━━━━━━━┓${rst}\n"

  printf "  ${prp}${bld}┃${rst} ${grn}${bld}📊 AI Status${rst}                                       ${prp}${bld}┃${rst}\n"
  for ((pi=1; pi<=${#_cmd_tools[@]}; pi++)); do
    local pname="${_cmd_tools[$pi]}"
    local picon="${_cmd_icons[$pi]}"
    local pstatus=$(_read_status "$pname")
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

# ── /swap N M (협동 모드) ──
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

# ── /order (순차 모드) ──
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

# ── /mode X ──
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

# ── /merge ──
_do_merge() {
  local merge_ai="$1"

  # 동시 모드: /merge N → N번 AI가 모든 결과 종합
  if [[ "$mode" == "parallel" ]]; then
    if [ -z "$merge_ai" ] || ! [[ "$merge_ai" =~ ^[0-9]+$ ]] || [ "$merge_ai" -lt 1 ] || [ "$merge_ai" -gt ${#_cmd_tools[@]} ]; then
      printf "  ${red}사용법: /merge N (1~${#_cmd_tools[@]}) — N번 AI가 모든 결과 종합${rst}\n"
      return
    fi
    local mai_tool="${_cmd_tools[$merge_ai]}"
    local mai_icon="${_cmd_icons[$merge_ai]}"
    local mai_pane="${ai_panes[$merge_ai]}"

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

  # 협동 모드: git branch merge
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
