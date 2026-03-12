#!/bin/zsh
# lib/ui.zsh — Interactive TUI selection components
# Used by battle.zsh for mode/agent/role/order/layout selection

# ── Mode Selection UI ──
# Sets: mode variable in caller
_battle_select_mode() {
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
}

# ── Agent Selection UI ──
# Modifies: _yolo_opts, _yolo_icons, tcolors, cnt in caller
_battle_select_agents() {
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
}

# ── Role Selection UI (collaborative mode) ──
# Modifies: _roles, _mode_roles in caller
_battle_select_roles() {
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
      1) _ri=0 ;;  # Lead Dev
      2) _ri=1 ;;  # Reviewer
      3) _ri=2 ;;  # Test/Ops
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

  # persist role names for status bar monitor
  for ((j=1; j<=$cnt; j++)); do
    printf '%s' "${_roles[$j]}" > "$tmpdir/role_${_yolo_opts[$j]}.txt"
  done
}

# ── Sequential Order Selection UI ──
# Sets: _seq_order in caller
_battle_select_order() {
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
}

# ── Layout Selection UI (3+ tools) ──
# Sets: _layout_choice in caller
_battle_select_layout() {
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
}

# ── Launch Banner ──
_battle_show_banner() {
  local mode_label="$1" mode_icon="$2" mode_color="$3"
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
