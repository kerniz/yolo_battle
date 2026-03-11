#!/bin/zsh
# yolo battle - multi-agent battle mode
# Usage: yolo battle [-p|-s|-c] "prompt"
#   -p  parallel  (동시)   : 각 AI 독립 컨텍스트, 서로 열람 가능, 사용자가 최종 선택
#   -s  sequential(순차)   : 1개 컨텍스트 릴레이, /next로 라운드로빈 무한순환
#   -c  collaborative(협동): 역할분리 + 3개 작업컨텍스트 + 1개 공유보드, worktree 격리

_yolo_battle() {
  # Receive context from parent yolo function via these globals:
  #   _yolo_opts, _yolo_icons, tcolors (arrays)
  #   reset, bold, dim, red, orange, yellow, green, cyan, blue, purple, pink, white (colors)

  # ── parse mode flag ──
  local mode=""
  local -a _seq_order  # custom order for sequential mode
  case "$1" in
    -p|--parallel)      mode="parallel"; shift ;;
    -s|--sequential)    mode="sequential"; shift ;;
    -c|--collaborative) mode="collaborative"; shift ;;
  esac

  # ── interactive mode selection if no flag given ──
  if [ -z "$mode" ] && [ -t 0 ]; then
    local -a _mode_names=("sequential" "parallel" "collaborative")
    local -a _mode_labels=("순차 (Sequential)" "동시 (Parallel)" "협동 (Collaborative)")
    local -a _mode_icons=("🔄" "⚡" "🤝")
    local -a _mode_descs=(
      "1개 컨텍스트 릴레이, 라운드로빈"
      "각 AI 독립 실행, 최종 선택"
      "역할분리 + worktree 격리"
    )
    local -a _mode_colors=("$cyan" "$yellow" "$green")
    local mi=0
    local mkey
    local cursor_up=$'\033[A'
    local cursor_down=$'\033[B'
    local bg_sel=$'\033[48;5;236m'

    printf "\033[?25l"
    trap 'printf "\033[?25h"' INT

    printf "\n"
    printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${yellow}${bold}⚔️  B A T T L E   M O D E ⚔️${reset}        ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${dim}Select battle strategy${reset}              ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"

    for ((mj=1; mj<=3; mj++)); do
      if [ $((mj-1)) -eq "$mi" ]; then
        printf "  ${purple}${bold}║${reset} ${bg_sel} ${_mode_colors[$mj]}${bold} ▸ ${_mode_icons[$mj]}  %-28s${reset}${bg_sel} ${reset}${purple}${bold}║${reset}\n" "${_mode_labels[$mj]}"
        printf "  ${purple}${bold}║${reset} ${bg_sel}      ${dim}%-30s${reset}${bg_sel} ${reset}${purple}${bold}║${reset}\n" "${_mode_descs[$mj]}"
      else
        printf "  ${purple}${bold}║${reset}   ${dim}   ${_mode_icons[$mj]}  %-28s${reset}   ${purple}${bold}║${reset}\n" "${_mode_labels[$mj]}"
        printf "  ${purple}${bold}║${reset}      ${dim}%-30s${reset}   ${purple}${bold}║${reset}\n" "${_mode_descs[$mj]}"
      fi
    done

    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${dim}↑↓ navigate${reset}  ${dim}⏎ select${reset}             ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}╚══════════════════════════════════════╝${reset}\n"

    while true; do
      read -rs -k1 mkey
      if [[ "$mkey" == $'\033' ]]; then
        read -rs -k2 mkey
        mkey=$'\033'"$mkey"
      fi

      case "$mkey" in
        "$cursor_up")
          mi=$(( (mi - 1 + 3) % 3 ))
          ;;
        "$cursor_down")
          mi=$(( (mi + 1) % 3 ))
          ;;
        $'\n')
          break
          ;;
        *)
          continue
          ;;
      esac

      # redraw: move up past 3 items (6 lines) + 3 footer lines = 9 lines
      printf "\033[9A"
      for ((mj=1; mj<=3; mj++)); do
        if [ $((mj-1)) -eq "$mi" ]; then
          printf "\r  ${purple}${bold}║${reset} ${bg_sel} ${_mode_colors[$mj]}${bold} ▸ ${_mode_icons[$mj]}  %-28s${reset}${bg_sel} ${reset}${purple}${bold}║${reset}\n" "${_mode_labels[$mj]}"
          printf "\r  ${purple}${bold}║${reset} ${bg_sel}      ${dim}%-30s${reset}${bg_sel} ${reset}${purple}${bold}║${reset}\n" "${_mode_descs[$mj]}"
        else
          printf "\r  ${purple}${bold}║${reset}   ${dim}   ${_mode_icons[$mj]}  %-28s${reset}   ${purple}${bold}║${reset}\n" "${_mode_labels[$mj]}"
          printf "\r  ${purple}${bold}║${reset}      ${dim}%-30s${reset}   ${purple}${bold}║${reset}\n" "${_mode_descs[$mj]}"
        fi
      done
      printf "\033[3B"
    done

    mode="${_mode_names[$((mi+1))]}"

    # clear selection UI and show chosen mode
    printf "\033[13A\033[J"
    local _sel_color="${_mode_colors[$((mi+1))]}"
    local _sel_icon="${_mode_icons[$((mi+1))]}"
    local _sel_label="${_mode_labels[$((mi+1))]}"
    printf "\n"
    printf "  ${_sel_color}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    printf "  ${_sel_color}${bold}  ${_sel_icon}  ${white}B A T T L E${reset} ${dim}→${reset} ${_sel_color}${bold}${_sel_label}${reset}\n"
    printf "  ${_sel_color}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}\n"
    printf "\n"

    printf "\033[?25h"
    trap - INT
  elif [ -z "$mode" ]; then
    mode="collaborative"
  fi

  local prompt="$*"

  command -v tmux >/dev/null 2>&1 || {
    printf "${red}${bold} ✖  tmux is required for battle mode${reset}\n"
    return 1
  }

  # ── interactive agent selection ──
  local cnt=${#_yolo_opts[@]}
  if [ $cnt -ge 2 ] && [ -t 0 ]; then
    local -a _agent_selected
    for ((j=1; j<=$cnt; j++)); do _agent_selected+=("1"); done
    local ai=0
    local akey
    local cursor_up=$'\033[A'
    local cursor_down=$'\033[B'
    local bg_sel=$'\033[48;5;236m'

    printf "\033[?25l"
    trap 'printf "\033[?25h"' INT

    local _agent_header_lines=5
    local _agent_footer_lines=1

    printf "\n"
    printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${cyan}${bold}🎯  참가 AI 선택${reset}                    ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}║${reset}  ${dim}Space: 토글  ⏎: 확인${reset}                ${purple}${bold}║${reset}\n"
    printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
    for ((aj=1; aj<=$cnt; aj++)); do
      local chk="${green}✔${reset}"
      if [ $((aj-1)) -eq "$ai" ]; then
        printf "  ${purple}${bold}║${reset} ${bg_sel} ${tcolors[$aj]}${bold} ▸ [${chk}${bg_sel}${tcolors[$aj]}${bold}] ${_yolo_icons[$aj]}  %-18s${reset}${bg_sel}  ${reset}${purple}${bold}║${reset}\n" "${(U)_yolo_opts[$aj]}"
      else
        printf "  ${purple}${bold}║${reset}     ${dim}[${chk}${dim}] ${_yolo_icons[$aj]}  %-18s${reset}    ${purple}${bold}║${reset}\n" "${_yolo_opts[$aj]}"
      fi
    done
    printf "  ${purple}${bold}╚══════════════════════════════════════╝${reset}\n"

    while true; do
      read -rs -k1 akey
      if [[ "$akey" == $'\033' ]]; then
        read -rs -k2 akey
        akey=$'\033'"$akey"
      fi

      case "$akey" in
        "$cursor_up")
          ai=$(( (ai - 1 + cnt) % cnt ))
          ;;
        "$cursor_down")
          ai=$(( (ai + 1) % cnt ))
          ;;
        " ")
          local idx=$((ai+1))
          if [ "${_agent_selected[$idx]}" = "1" ]; then
            _agent_selected[$idx]="0"
          else
            _agent_selected[$idx]="1"
          fi
          ;;
        $'\n')
          local _sel_cnt=0
          for ((aj=1; aj<=$cnt; aj++)); do
            [ "${_agent_selected[$aj]}" = "1" ] && _sel_cnt=$((_sel_cnt+1))
          done
          if [ $_sel_cnt -lt 2 ]; then
            printf "\033[$(($cnt + $_agent_footer_lines))A"
            for ((aj=1; aj<=$cnt; aj++)); do
              local chk=" "
              [ "${_agent_selected[$aj]}" = "1" ] && chk="${green}✔${reset}"
              if [ $((aj-1)) -eq "$ai" ]; then
                printf "\r  ${purple}${bold}║${reset} ${bg_sel} ${tcolors[$aj]}${bold} ▸ [${chk}${bg_sel}${tcolors[$aj]}${bold}] ${_yolo_icons[$aj]}  %-18s${reset}${bg_sel}  ${reset}${purple}${bold}║${reset}\n" "${(U)_yolo_opts[$aj]}"
              else
                printf "\r  ${purple}${bold}║${reset}     ${dim}[${chk}${dim}] ${_yolo_icons[$aj]}  %-18s${reset}    ${purple}${bold}║${reset}\n" "${_yolo_opts[$aj]}"
              fi
            done
            printf "\r  ${purple}${bold}╚══════════════════════════════════════╝${reset}\n"
            printf "  ${red}${bold}  ⚠  최소 2개 이상 선택하세요${reset}\033[K"
            sleep 1
            printf "\r\033[K\033[1A\033[K"
            printf "\r  ${purple}${bold}╚══════════════════════════════════════╝${reset}"
            printf "\033[$(($cnt + $_agent_footer_lines))A"
            continue
          fi
          break
          ;;
        *)
          continue
          ;;
      esac

      # redraw items + footer
      printf "\033[$(($cnt + $_agent_footer_lines))A"
      for ((aj=1; aj<=$cnt; aj++)); do
        local chk=" "
        [ "${_agent_selected[$aj]}" = "1" ] && chk="${green}✔${reset}"
        if [ $((aj-1)) -eq "$ai" ]; then
          printf "\r  ${purple}${bold}║${reset} ${bg_sel} ${tcolors[$aj]}${bold} ▸ [${chk}${bg_sel}${tcolors[$aj]}${bold}] ${_yolo_icons[$aj]}  %-18s${reset}${bg_sel}  ${reset}${purple}${bold}║${reset}\n" "${(U)_yolo_opts[$aj]}"
        else
          printf "\r  ${purple}${bold}║${reset}     ${dim}[${chk}${dim}] ${_yolo_icons[$aj]}  %-18s${reset}    ${purple}${bold}║${reset}\n" "${_yolo_opts[$aj]}"
        fi
      done
      printf "\033[${_agent_footer_lines}B"
    done

    # clear agent selection UI
    local _total_agent_lines=$((_agent_header_lines + cnt + _agent_footer_lines))
    printf "\033[${_total_agent_lines}A\033[J"

    # filter arrays to only selected agents
    local -a _new_opts _new_icons _new_colors
    for ((aj=1; aj<=$cnt; aj++)); do
      if [ "${_agent_selected[$aj]}" = "1" ]; then
        _new_opts+=("${_yolo_opts[$aj]}")
        _new_icons+=("${_yolo_icons[$aj]}")
        _new_colors+=("${tcolors[$aj]}")
      fi
    done
    _yolo_opts=("${_new_opts[@]}")
    _yolo_icons=("${_new_icons[@]}")
    tcolors=("${_new_colors[@]}")
    cnt=${#_yolo_opts[@]}

    # show selected agents
    printf "\n"
    printf "  ${cyan}${bold}🎯 참가 AI:${reset} "
    for ((aj=1; aj<=$cnt; aj++)); do
      [ $aj -gt 1 ] && printf " ${dim}|${reset} "
      printf "${_new_colors[$aj]}${_new_icons[$aj]} ${_new_opts[$aj]}${reset}"
    done
    printf "\n\n"

    printf "\033[?25h"
    trap - INT
  fi

  if [ $cnt -lt 2 ]; then
    printf "${red}${bold} ✖  Need at least 2 CLIs for battle${reset}\n"
    return 1
  fi

  # ── prepare workspace ──
  local tmpdir
  tmpdir=$(mktemp -d /tmp/yolo-battle-XXXXXX)
  local savedir="$HOME/yolo-results/$(date +%Y%m%d-%H%M%S)"
  local workdir="$(pwd)"

  # set default guideline when no prompt given
  if [ -z "$prompt" ]; then
    prompt="사용자의 지시를 대기하세요. 스스로 판단해서 코드를 수정하거나 파일을 변경하지 마세요. 공유 컨텍스트 파일에 사용자 지시가 있으면 그것을 따르고, 아무것도 없으면 사용자가 구체적인 작업을 요청할 때까지 대기하세요."
  fi
  printf '%s' "$prompt" > "$tmpdir/prompt.txt"
  printf '%s' "$mode" > "$tmpdir/mode.txt"
  printf '%s' "$workdir" > "$tmpdir/workdir.txt"
  echo "0" > "$tmpdir/seq_turn.txt"

  # save initial git state for diff tracking
  git -C "$workdir" diff HEAD --stat > "$tmpdir/git_baseline.txt" 2>/dev/null
  git -C "$workdir" rev-parse HEAD > "$tmpdir/git_head.txt" 2>/dev/null

  # ── context files per mode ──
  echo "1" > "$tmpdir/round.txt"
  git -C "$workdir" rev-parse HEAD > "$tmpdir/git_head_track.txt" 2>/dev/null

  local _is_restart=false
  while true; do
  # ── re-source mode skill file (critical for mode switch) ──
  local _mode_file="${YOLO_DIR}/modes/${mode}.zsh"
  if [ -f "$_mode_file" ]; then
    source "$_mode_file"
  else
    printf "${red}${bold} ✖  Mode skill file not found: ${_mode_file}${reset}\n"
    return 1
  fi

  # ── setup context files for current mode ──
  _mode_setup_context "$tmpdir" "$cnt" "${_yolo_opts[@]}"

  # ── reset mode-dependent state for restart ──
  printf '%s' "$mode" > "$tmpdir/mode.txt"
  echo "0" > "$tmpdir/seq_turn.txt"
  rm -f "$tmpdir/seq_order_map.txt" "$tmpdir"/run_*.sh(N) "$tmpdir/cmd_center.sh" "$tmpdir/monitor.sh" "$tmpdir/ai_panes.txt"
  rm -f "$tmpdir"/status_*(N) "$tmpdir"/diff_*(N)
  # cleanup previous worktrees on restart
  for _wt in "$tmpdir"/work_*(N); do
    [ -d "$_wt" ] && git -C "$workdir" worktree remove "$_wt" 2>/dev/null
  done
  for _br in $(git -C "$workdir" branch --list "battle-coop-*" 2>/dev/null); do
    git -C "$workdir" branch -D "$_br" 2>/dev/null
  done

  # ── role definitions (from mode skill) ──
  local -a _roles _role_prompts
  _roles=("${_mode_roles[@]}")

  # ── collaborative mode: interactive role selection ──
  if [[ "$mode" == "collaborative" ]] && [ -t 0 ] && ! $_is_restart && [ ${#_mode_available_roles[@]} -gt 0 ]; then
    local -a _avail_roles=("${_mode_available_roles[@]}")
    local -a _avail_descs=("${_mode_available_role_descs[@]}")
    local -a _avail_icons=("${_mode_available_role_icons[@]}")
    local _avail_cnt=${#_avail_roles[@]}

    # per-AI role assignment
    _roles=()
    for ((_ai_idx=1; _ai_idx<=$cnt; _ai_idx++)); do
      local _ri=0
      local _rkey
      local cursor_up=$'\033[A'
      local cursor_down=$'\033[B'
      local bg_sel=$'\033[48;5;236m'

      # set default cursor to a sensible position
      case $_ai_idx in
        1) _ri=0 ;;  # Core
        2) _ri=1 ;;  # Tests
        3) _ri=2 ;;  # Config
        *) _ri=$(( (_ai_idx - 1) % _avail_cnt )) ;;
      esac

      printf "\033[?25l"
      trap 'printf "\033[?25h"' INT

      local _rh_lines=5  # header lines
      local _rf_lines=1  # footer line

      printf "\n"
      printf "  ${purple}${bold}╔══════════════════════════════════════╗${reset}\n"
      printf "  ${purple}${bold}║${reset}  ${tcolors[$_ai_idx]}${bold}${_yolo_icons[$_ai_idx]}  ${(U)_yolo_opts[$_ai_idx]}${reset} ${dim}역할 선택${reset}            ${purple}${bold}║${reset}\n"
      printf "  ${purple}${bold}║${reset}  ${dim}↑↓ 이동  ⏎ 선택${reset}                   ${purple}${bold}║${reset}\n"
      printf "  ${purple}${bold}╠══════════════════════════════════════╣${reset}\n"
      for ((rj=1; rj<=$_avail_cnt; rj++)); do
        if [ $((rj-1)) -eq "$_ri" ]; then
          printf "  ${purple}${bold}║${reset} ${bg_sel} ${green}${bold} ▸ ${_avail_icons[$rj]} %-10s${reset}${bg_sel}${dim}%-16s${reset}${bg_sel} ${reset}${purple}${bold}║${reset}\n" "${_avail_roles[$rj]}" "${_avail_descs[$rj]}"
        else
          printf "  ${purple}${bold}║${reset}     ${dim}${_avail_icons[$rj]} %-10s%-16s${reset}   ${purple}${bold}║${reset}\n" "${_avail_roles[$rj]}" "${_avail_descs[$rj]}"
        fi
      done
      printf "  ${purple}${bold}╚══════════════════════════════════════╝${reset}\n"

      while true; do
        read -rs -k1 _rkey
        if [[ "$_rkey" == $'\033' ]]; then
          read -rs -k2 _rkey
          _rkey=$'\033'"$_rkey"
        fi

        case "$_rkey" in
          "$cursor_up")
            _ri=$(( (_ri - 1 + _avail_cnt) % _avail_cnt ))
            ;;
          "$cursor_down")
            _ri=$(( (_ri + 1) % _avail_cnt ))
            ;;
          $'\n')
            break
            ;;
          *)
            continue
            ;;
        esac

        # redraw items + footer
        printf "\033[$(($_avail_cnt + $_rf_lines))A"
        for ((rj=1; rj<=$_avail_cnt; rj++)); do
          if [ $((rj-1)) -eq "$_ri" ]; then
            printf "\r  ${purple}${bold}║${reset} ${bg_sel} ${green}${bold} ▸ ${_avail_icons[$rj]} %-10s${reset}${bg_sel}${dim}%-16s${reset}${bg_sel} ${reset}${purple}${bold}║${reset}\n" "${_avail_roles[$rj]}" "${_avail_descs[$rj]}"
          else
            printf "\r  ${purple}${bold}║${reset}     ${dim}${_avail_icons[$rj]} %-10s%-16s${reset}   ${purple}${bold}║${reset}\n" "${_avail_roles[$rj]}" "${_avail_descs[$rj]}"
          fi
        done
        printf "\033[${_rf_lines}B"
      done

      _roles+=("${_avail_roles[$((_ri+1))]}")

      # clear role selection UI
      local _total_role_lines=$((_rh_lines + _avail_cnt + _rf_lines))
      printf "\033[${_total_role_lines}A\033[J"

      printf "\033[?25h"
      trap - INT
    done

    # show assigned roles
    printf "\n"
    printf "  ${green}${bold}🤝 역할 배정:${reset}\n"
    for ((j=1; j<=$cnt; j++)); do
      printf "   ${tcolors[$j]}${_yolo_icons[$j]} ${_yolo_opts[$j]}${reset} → ${yellow}${bold}${_roles[$j]}${reset}\n"
    done
    printf "\n"

    _mode_roles=("${_roles[@]}")
  fi

  if [ -n "$prompt" ]; then
    _mode_setup_roles "$tmpdir" "$prompt"
    _role_prompts=("${_mode_role_prompts[@]}")
  fi

  # ── sequential mode: order selection ──
  _seq_order=()
  if $_mode_needs_order && [ -t 0 ] && ! $_is_restart; then
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
      # Cleanup existing branch if any to avoid conflicts (Technical Relay from Claude)
      git -C "$workdir" branch -D "battle-coop-${tname}" 2>/dev/null
      git -C "$workdir" worktree prune 2>/dev/null
      
      git -C "$workdir" worktree add -f -q "$toolworkdir" -b "battle-coop-${tname}" HEAD 2>/dev/null || {
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

      # mark as done + capture diff + auto-commit (AI process exited)
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

  # ── mode labels (from mode skill) ──
  local mode_label="$_mode_label"
  local mode_icon="$_mode_icon"
  local mode_color="${(P)_mode_color_name}"

  # ── launch banner ──
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
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/ctx${rst}      컨텍스트 확인     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/prompt X${rst} 프롬프트 변경     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/focus N${rst}  N번 pane 포커스   ${prp}${bld}║${rst}\n"'

    # mode-specific help commands (from mode skill)
    _mode_help_commands

    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/mode X${rst}   모드 변경 ${dm}(p/s/c)${rst}${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/help${rst}     도움말            ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/cat FILE${rst}  파일 내용 비교     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/grep PAT${rst}   파일 내용 검색     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/history${rst}   명령어 기록       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/quit${rst}     세션 종료         ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${cyn}단축키${rst}                       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╠════════════════════════════════╣${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → 방향키${rst} pane 이동   ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → z${rst}     풀스크린     ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → S${rst}     동기화       ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}║${rst}  ${ylw}Ctrl+B → d${rst}     세션 나가기   ${prp}${bld}║${rst}\n"'
    echo 'printf "  ${prp}${bld}╚════════════════════════════════╝${rst}\n"'

    # mode-specific info section (from mode skill)
    _mode_help_info "$cnt" "${_yolo_opts[@]}" "${_yolo_icons[@]}" "${_seq_order[@]}" "${_roles[@]}"

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
  printf "  ${prp}${bld}║${rst}  ${cyn}공통 명령어:${rst}                        ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/status${rst}    각 AI 상태 확인        ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/diff${rst}      각 AI 변경사항 확인   ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/save${rst}      결과 저장              ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/ctx${rst}       컨텍스트 확인          ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/prompt X${rst}  프롬프트 변경          ${prp}${bld}║${rst}\n"
  printf "  ${prp}${bld}║${rst}   ${ylw}/focus N${rst}   N번 pane 포커스        ${prp}${bld}║${rst}\n"

  _mode_cmd_commands

  printf "  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n"
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
  case "$tool" in
    gemini)
      tmux send-keys -t "${pane}" Enter Enter Enter 2>/dev/null
      ;;
    codex)
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
      } >> "$tmpdir/context.md"
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

  # build auto-type message with context path
  local ctx_msg=""
  if [ -n "$new_prompt" ]; then
    ctx_msg="반드시 ${tmpdir}/context.md 를 열어 최신 입력을 확인한 뒤 즉시 응답하세요(추가 질문 금지). 새 작업: ${new_prompt}"
  else
    local orig_prompt=$(cat "$tmpdir/prompt.txt" 2>/dev/null)
    ctx_msg="반드시 ${tmpdir}/context.md 를 열어 최신 입력을 확인한 뒤 즉시 응답하세요(추가 질문 금지). 이어서 작업: ${orig_prompt}"
  fi

  # auto-type into next AI pane via send-keys
  _send_to_pane "${next_pane}" "${next_tool}" "$ctx_msg"
  printf "  ${dm}→ ${_cmd_icons[$next_tool_idx]} ${next_tool}에 자동 전송됨${rst}\n"
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
  printf "  ${ylw}⏭ 건너뜀${rst}\n"
  printf "  ${cyn}${bld}▶ R${round}:T${next} ${_cmd_icons[$next_tool_idx]} ${_cmd_tools[$next_tool_idx]} 활성화${rst}\n"
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
  if [[ "$mode" != "parallel" ]]; then
    printf "  ${red}동시 모드에서만 사용 가능합니다${rst}\n"
    return
  fi
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

    # show last 5 lines of pane output
    local pane="${ai_panes[$ci]}"
    local pout=$(tmux capture-pane -t "${pane}" -p -S -10 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -3)
    if [ -n "$pout" ]; then
      echo "$pout" | while IFS= read -r pl; do
        printf "    ${dm}│ %.60s${rst}\n" "$pl"
      done
    fi
  done

  printf "\n  ${ylw}${bld}/pick N${rst} ${dm}으로 채택하세요 (1~${#_cmd_tools[@]})${rst}\n\n"
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
  local settle="${1:-3}"
  _auto_stop 2>/dev/null
  (
    local last_mtime=$(_auto_get_mtime)
    [ -z "$last_mtime" ] && last_mtime="0"

    while true; do
      sleep 2
      local cur_mtime=$(_auto_get_mtime)
      [ -z "$cur_mtime" ] && cur_mtime="0"
      if [[ "$cur_mtime" != "$last_mtime" ]]; then
        # context 변경 감지, settle 대기 후 확정
        sleep "$settle"
        local settled_mtime=$(_auto_get_mtime)
        if [[ "$settled_mtime" == "$cur_mtime" ]]; then
          printf "\n  ${cyn}${bld}🔄 context 변경 감지 → /next 자동 실행${rst}\n"
          _do_next
          last_mtime=$(_auto_get_mtime)  # _do_next가 context를 수정할 수 있으므로 갱신
        else
          last_mtime="$settled_mtime"
        fi
      fi
    done
  ) &
  _auto_pid=$!
  printf "  ${grn}${bld}✔ /auto 시작${rst} ${dm}(context 변경 감지 모드, settle=${settle}s)${rst}\n"
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
# INPUT LOOP
# ════════════════════════════════════════
while true; do
  input=""
  if vared -p "  %{${prp}${bld}%}▸%{${rst}%} " -c input 2>/dev/null; then
    printf '\033[J'
  else
    printf "  ${prp}${bld}▸${rst} "
    read -r input || break
  fi

  if [[ -n "$input" ]]; then
    _cmd_history+=("$input")
    _cmd_hist_idx=0
  fi

  case "$input" in
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
      _do_next $next_prompt
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
        _auto_start 3
      else
        printf "  ${dm}사용법: /auto [settle초] | /auto stop${rst}\n"
      fi
      ;;
    /pick\ *)
      local pick_num="${input#/pick }"
      _do_pick "$pick_num"
      ;;
    /compare)
      _do_compare
      ;;
    /board)
      _do_board
      ;;
    /merge)
      _do_merge
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
  tmux kill-session -t "$session" 2>/dev/null
  local -a _ai_pane_ids
  local _cmd_pane_id

  if [ $cnt -eq 2 ]; then
    # 2x2 grid layout:
    # ┌──────┬──────┐
    # │ AI 1 │ AI 2 │
    # ├──────┼──────┤
    # │ CMD  │GUIDE │
    # └──────┴──────┘
    sed -i '' 's/has_help_pane=false/has_help_pane=true/' "$cmd_script"
    tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
    _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
    tmux split-window -h -t "${_ai_pane_ids[1]}" -p 50 "zsh ${_battle_scripts[2]}"
    _ai_pane_ids[2]=$(tmux display-message -t "${session}" -p '#{pane_id}')
    tmux split-window -v -t "${_ai_pane_ids[1]}" -p 50 "zsh ${cmd_script}"
    _cmd_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
    tmux split-window -v -t "${_ai_pane_ids[2]}" -p 50 "zsh ${help_script}"
    local _help_pane_id=$(tmux display-message -t "${session}" -p '#{pane_id}')
    echo "${_ai_pane_ids[1]} ${_ai_pane_ids[2]}" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${_ai_pane_ids[1]}" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${_ai_pane_ids[2]}" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND"
    tmux select-pane -t "${_help_pane_id}" -T "📋 GUIDE"
  elif [ $cnt -ge 3 ]; then
    if [[ "$_layout_choice" == "top3" ]]; then
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
  tmux set-option -t "$session" aggressive-resize on 2>/dev/null
  tmux set-option -t "$session" allow-passthrough off 2>/dev/null
  tmux set-option -t "$session" remain-on-exit on 2>/dev/null
  for _pid in "${_ai_pane_ids[@]}" "$_cmd_pane_id"; do
    tmux set-option -p -t "$_pid" remain-on-exit on 2>/dev/null
  done
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

  # launch monitor
  zsh "$monitor" &
  local monitor_pid=$!

  # focus on command center
  tmux select-pane -t "${_cmd_pane_id}"

  tmux attach -t "$session"

  # cleanup
  kill $monitor_pid 2>/dev/null

  # cleanup co-op worktrees (if not already merged)
  for _wt in "$tmpdir"/work_*(N); do
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
