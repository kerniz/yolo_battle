#!/bin/zsh
# ════════════════════════════════════════
# cmd_input.zsh — Input loop, history, key bindings
# Sourced at runtime by cmd_center.sh
# ════════════════════════════════════════

# ── sequential mode init ──
if [[ "$mode" == "sequential" ]]; then
  echo "1" > "$tmpdir/seq_turn.txt"
fi

# ── multibyte input support ──
setopt multibyte 2>/dev/null
stty erase '^?' 2>/dev/null
bindkey '^?' backward-delete-char 2>/dev/null
bindkey '^H' backward-delete-char 2>/dev/null
bindkey '\b' backward-delete-char 2>/dev/null

COLUMNS=$(tmux display-message -p '#{pane_width}' 2>/dev/null || tput cols 2>/dev/null || echo 80)
trap 'COLUMNS=$(tmux display-message -p "#{pane_width}" 2>/dev/null || tput cols 2>/dev/null || echo 80)' WINCH

# ── command history ──
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

bindkey '^[[A' _cmd_hist_up
bindkey '^[OA' _cmd_hist_up
bindkey '^[[B' _cmd_hist_down
bindkey '^[OB' _cmd_hist_down
bindkey '^U'   _cmd_kill_line

# ── auto-start for sequential mode ──
if [[ "$mode" == "sequential" ]]; then
  _auto_start 10
  printf "  ${cyn}${bld}🔄 /auto 자동 활성화 (순차모드, settle=10s)${rst}\n"
fi

# ════════════════════════════════════════
# MAIN INPUT LOOP
# ════════════════════════════════════════
while true; do
  input=""
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
        _priority_watcher_stop
        _priority_watcher_start "$input"
      else
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
