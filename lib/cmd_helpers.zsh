#!/bin/zsh
# ════════════════════════════════════════
# cmd_helpers.zsh — Shared helper functions
# Sourced at runtime by cmd_center.sh
# ════════════════════════════════════════

# ── capture pane output (deduplicated helper) ──
_capture_pane() {
  local pane="$1" lines="${2:-30}"
  tmux capture-pane -t "$pane" -p -S -$lines 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n $lines
}

# ── compute pane hash for stability detection ──
_pane_hash() {
  local pane="$1" lines="${2:-30}"
  local pout=$(_capture_pane "$pane" "$lines")
  [ -n "$pout" ] && printf '%s' "$pout" | shasum -a 256 | awk '{print $1}'
}

# ── read status file ──
_read_status() {
  cat "$tmpdir/status_$1" 2>/dev/null
}

# ── status board display ──
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
    local st=$(_read_status "$sname")
    case "$st" in
      done:*)  printf "  ${purple}${bold}┃${rst} ${grn}${bld}✔ ${sicon} %-12s${rst} ${dm}${st#done:}${rst}   ${purple}${bold}┃${rst}\n" "$sname" ;;
      running) printf "  ${purple}${bold}┃${rst} ${ylw}${bld}⣾ ${sicon} %-12s${rst} ${ylw}ING..${rst}  ${purple}${bold}┃${rst}\n" "$sname" ;;
      waiting) printf "  ${purple}${bold}┃${rst} ${dm}⏳ ${sicon} %-12s WAIT${rst}   ${purple}${bold}┃${rst}\n" "$sname" ;;
      *)       printf "  ${purple}${bold}┃${rst} ${dm}·  ${sicon} %-12s --${rst}     ${purple}${bold}┃${rst}\n" "$sname" ;;
    esac
  done
  printf "  ${purple}${bold}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${rst}\n"
  printf "\n"
}

# ── send text to AI pane ──
_send_to_pane() {
  local pane="$1"
  local tool="$2"
  local text="$3"
  tmux send-keys -t "${pane}" -l "$text" 2>/dev/null
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

# ── show diff summary ──
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
