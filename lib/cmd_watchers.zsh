#!/bin/zsh
# ════════════════════════════════════════
# cmd_watchers.zsh — Background watchers
# Sourced at runtime by cmd_center.sh
# ════════════════════════════════════════

# ── AUTO-NEXT ──
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

      if [[ "$cur_mtime" != "$last_mtime" ]]; then
        ctx_changed=true
        last_mtime="$cur_mtime"
      fi

      local cur_pane_hash=""
      if [[ "$mode" == "sequential" ]]; then
        local cur=$(cat "$tmpdir/seq_turn.txt" 2>/dev/null)
        if [ -n "$cur" ]; then
          local cur_tool_idx=${_cmd_seq_order[$cur]}
          if [ -n "$cur_tool_idx" ]; then
            cur_pane_hash=$(_pane_hash "${ai_panes[$cur_tool_idx]}" 30)
          fi
        fi
      fi

      if [ -n "$cur_pane_hash" ] && [[ "$cur_pane_hash" != "$last_pane_hash" ]]; then
        last_pane_hash="$cur_pane_hash"
        last_pane_change_ts=$(date +%s)
      fi

      if $ctx_changed; then
        local now=$(date +%s)
        local pane_stable_secs=$(( now - last_pane_change_ts ))
        local remaining=$(( settle - pane_stable_secs ))

        if (( remaining > 0 )); then
          printf "\033[s\033[2;1H\033[2K  ${dm}⏳ context 변경 감지 — pane 안정화 대기 ${remaining}s ...${rst}\033[u"
        else
          printf "\033[s\033[2;1H\033[2K\033[u"
          local final_mtime=$(_auto_get_mtime)
          if [[ "$final_mtime" == "$last_mtime" ]]; then
            printf "\n  ${cyn}${bld}🔄 context+pane 안정화 → /next 자동 실행${rst}\n"
            _do_next
            last_mtime=$(_auto_get_mtime)
            ctx_changed=false
            last_pane_hash=""
            last_pane_change_ts=$(date +%s)
          else
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

# ── PRIORITY WATCHER (협동 모드 우선순위 캐스케이드) ──
_priority_watcher_pid=""

_priority_watcher_stop() {
  if [ -n "$_priority_watcher_pid" ] && kill -0 "$_priority_watcher_pid" 2>/dev/null; then
    kill "$_priority_watcher_pid" 2>/dev/null
    wait "$_priority_watcher_pid" 2>/dev/null
  fi
  _priority_watcher_pid=""
}

# AI 목록을 우선순위로 정렬하여 인덱스 배열 반환
_get_priority_sorted_indices() {
  local -a pairs=()
  for ((pi=1; pi<=${#_cmd_tools[@]}; pi++)); do
    local p=$(_mode_role_priority "${_cmd_roles[$pi]}")
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

  local sorted_indices=($(_get_priority_sorted_indices))
  local total=${#sorted_indices[@]}

  local first_idx=${sorted_indices[1]}
  local first_pane="${ai_panes[$first_idx]}"
  local first_tool="${_cmd_tools[$first_idx]}"
  local first_pri=$(_mode_role_priority "${_cmd_roles[$first_idx]}")
  _send_to_pane "${first_pane}" "${first_tool}" "$user_cmd"
  printf "  ${grn}${bld}▶ P${first_pri} ${_cmd_icons[$first_idx]} ${first_tool}${rst} ${dm}← 커맨드 전송${rst}\n"

  if [ "$total" -le 1 ]; then
    return
  fi

  : > "$tmpdir/priority_queue.txt"
  for ((qi=2; qi<=total; qi++)); do
    echo "${sorted_indices[$qi]}" >> "$tmpdir/priority_queue.txt"
  done
  printf '%s' "$user_cmd" > "$tmpdir/priority_user_cmd.txt"

  (
    local watch_idx=$first_idx
    local watch_pane=$first_pane
    local watch_tool=$first_tool
    local last_pane_hash=""
    local last_pane_change_ts=$(date +%s)

    while true; do
      sleep 2

      local cur_pane_hash=$(_pane_hash "${watch_pane}" 30)

      if [ -n "$cur_pane_hash" ] && [[ "$cur_pane_hash" != "$last_pane_hash" ]]; then
        last_pane_hash="$cur_pane_hash"
        last_pane_change_ts=$(date +%s)
      fi

      local now=$(date +%s)
      local pane_stable_secs=$(( now - last_pane_change_ts ))

      if (( pane_stable_secs >= settle )); then
        local next_qi=$(head -1 "$tmpdir/priority_queue.txt" 2>/dev/null)

        if [ -z "$next_qi" ]; then
          local orig_cmd=$(cat "$tmpdir/priority_user_cmd.txt" 2>/dev/null)
          printf "\n  ${grn}${bld}✔ 커맨드 완료${rst} ${dm}— 모든 우선순위 AI 작업 완료${rst}\n"
          printf "  ${dm}  \"%.40s...\"${rst}\n" "$orig_cmd"
          printf '\a'
          break
        fi

        tail -n +2 "$tmpdir/priority_queue.txt" > "$tmpdir/priority_queue.tmp" 2>/dev/null
        mv "$tmpdir/priority_queue.tmp" "$tmpdir/priority_queue.txt" 2>/dev/null

        local next_pane="${ai_panes[$next_qi]}"
        local next_tool="${_cmd_tools[$next_qi]}"
        local next_pri=$(_mode_role_priority "${_cmd_roles[$next_qi]}")
        local orig_cmd=$(cat "$tmpdir/priority_user_cmd.txt" 2>/dev/null)
        local relay_msg="${orig_cmd}. shared.md 확인하고 역할에 맞게 작업을 수행하세요. 추천 및 제안사항이 있는 경우 shared.md에 남기세요."

        _send_to_pane "${next_pane}" "${next_tool}" "$relay_msg"
        printf "\n  ${grn}${bld}▶ P${next_pri} ${_cmd_icons[$next_qi]} ${next_tool}${rst} ${dm}← 캐스케이드 활성화 (${watch_tool} 안정화 ${settle}s)${rst}\n"

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

# ── PARALLEL COMPLETION WATCHER ──
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
        local cur_hash=$(_pane_hash "${ai_panes[$wi]}" 30)

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
        printf '\a'
        break
      fi
    done
  ) &
  _parallel_watcher_pid=$!
}
