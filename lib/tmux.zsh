#!/bin/zsh
# lib/tmux.zsh — Tmux session creation, styling, and cleanup

# ── Portable in-place sed (BSD vs GNU) ──
_battle_sed_inplace() {
  local pattern="$1" file="$2"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$pattern" "$file"
  else
    sed -i "$pattern" "$file"
  fi
}

# ── Create tmux session with pane layout ──
# Sets: _ai_pane_ids, _cmd_pane_id
_battle_setup_tmux() {
  tmux kill-session -t "$session" 2>/dev/null
  _ai_pane_ids=()

  if [ $cnt -eq 2 ]; then
    # 2x2 grid layout
    _battle_sed_inplace 's/has_help_pane=false/has_help_pane=true/' "$cmd_script"
    tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
    _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
    _ai_pane_ids[2]=$(tmux split-window -h -t "${_ai_pane_ids[1]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[2]}")
    _cmd_pane_id=$(tmux split-window -v -t "${_ai_pane_ids[1]}" -l 50% -P -F '#{pane_id}' "zsh ${cmd_script}")
    local _help_pane_id=$(tmux split-window -v -t "${_ai_pane_ids[2]}" -l 50% -P -F '#{pane_id}' "zsh ${help_script}")
    echo "${_ai_pane_ids[1]} ${_ai_pane_ids[2]}" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${_ai_pane_ids[1]}" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${_ai_pane_ids[2]}" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND"
    tmux select-pane -t "${_help_pane_id}" -T "📋 GUIDE"
  elif [ $cnt -eq 3 ]; then
    if [[ "$_layout_choice" == "top3" ]]; then
      _battle_sed_inplace 's/has_help_pane=false/has_help_pane=true/' "$cmd_script"
      tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
      _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      _cmd_pane_id=$(tmux split-window -v -t "${_ai_pane_ids[1]}" -l 30% -P -F '#{pane_id}' "zsh ${cmd_script}")
      _ai_pane_ids[2]=$(tmux split-window -h -t "${_ai_pane_ids[1]}" -l 67% -P -F '#{pane_id}' "zsh ${_battle_scripts[2]}")
      _ai_pane_ids[3]=$(tmux split-window -h -t "${_ai_pane_ids[2]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[3]}")
      local _help_pane_id=$(tmux split-window -h -t "${_cmd_pane_id}" -l 45% -P -F '#{pane_id}' "zsh ${help_script}")
      tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND"
      tmux select-pane -t "${_help_pane_id}" -T "📋 GUIDE"
    else
      tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
      _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
      _ai_pane_ids[2]=$(tmux split-window -h -t "${_ai_pane_ids[1]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[2]}")
      _ai_pane_ids[3]=$(tmux split-window -v -t "${_ai_pane_ids[1]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[3]}")
      _cmd_pane_id=$(tmux split-window -v -t "${_ai_pane_ids[2]}" -l 50% -P -F '#{pane_id}' "zsh ${cmd_script}")
    fi
    echo "${_ai_pane_ids[1]} ${_ai_pane_ids[2]} ${_ai_pane_ids[3]}" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${_ai_pane_ids[1]}" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${_ai_pane_ids[2]}" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${_ai_pane_ids[3]}" -T "${_yolo_icons[3]} ${(U)_yolo_opts[3]}"
    if [[ "$_layout_choice" != "top3" ]]; then
      tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND CENTER"
    fi
  elif [ $cnt -eq 4 ]; then
    # 2x2 AI grid on left + stacked CMD/HELP on right (33% width)
    _battle_sed_inplace 's/has_help_pane=false/has_help_pane=true/' "$cmd_script"
    tmux new-session -d -s "$session" "zsh ${_battle_scripts[1]}"
    _ai_pane_ids[1]=$(tmux display-message -t "${session}" -p '#{pane_id}')
    _cmd_pane_id=$(tmux split-window -h -t "${_ai_pane_ids[1]}" -l 33% -P -F '#{pane_id}' "zsh ${cmd_script}")
    local _help_pane_id=$(tmux split-window -v -t "${_cmd_pane_id}" -l 50% -P -F '#{pane_id}' "zsh ${help_script}")
    _ai_pane_ids[2]=$(tmux split-window -h -t "${_ai_pane_ids[1]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[2]}")
    _ai_pane_ids[3]=$(tmux split-window -v -t "${_ai_pane_ids[1]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[3]}")
    _ai_pane_ids[4]=$(tmux split-window -v -t "${_ai_pane_ids[2]}" -l 50% -P -F '#{pane_id}' "zsh ${_battle_scripts[4]}")
    echo "${_ai_pane_ids[1]} ${_ai_pane_ids[2]} ${_ai_pane_ids[3]} ${_ai_pane_ids[4]}" > "$tmpdir/ai_panes.txt"
    tmux select-pane -t "${_ai_pane_ids[1]}" -T "${_yolo_icons[1]} ${(U)_yolo_opts[1]}"
    tmux select-pane -t "${_ai_pane_ids[2]}" -T "${_yolo_icons[2]} ${(U)_yolo_opts[2]}"
    tmux select-pane -t "${_ai_pane_ids[3]}" -T "${_yolo_icons[3]} ${(U)_yolo_opts[3]}"
    tmux select-pane -t "${_ai_pane_ids[4]}" -T "${_yolo_icons[4]} ${(U)_yolo_opts[4]}"
    tmux select-pane -t "${_cmd_pane_id}" -T "⌨️  COMMAND"
    tmux select-pane -t "${_help_pane_id}" -T "📋 GUIDE"
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
}

# ── Configure tmux session options ──
_battle_setup_tmux_options() {
  # mouse support
  tmux set-option -t "$session" mouse on 2>/dev/null

  # layout protection
  tmux set-option -t "$session" aggressive-resize on 2>/dev/null
  tmux set-option -t "$session" allow-passthrough off 2>/dev/null
  tmux set-option -t "$session" remain-on-exit on 2>/dev/null
  for _pid in "${_ai_pane_ids[@]}" "$_cmd_pane_id"; do
    tmux set-option -p -t "$_pid" remain-on-exit on 2>/dev/null
  done
  tmux select-layout -t "${session}:0" -E 2>/dev/null

  # pane border styling
  tmux set-option -t "$session" pane-border-status top 2>/dev/null
  tmux set-option -t "$session" pane-border-style "fg=colour240" 2>/dev/null
  tmux set-option -t "$session" pane-active-border-style "fg=colour141" 2>/dev/null
  tmux set-option -t "$session" pane-border-format \
    " #{?pane_active,#[fg=colour220]⚡,#[fg=colour240]·} #[fg=colour255,bold]#{pane_title} " 2>/dev/null

  # status bar
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

  # keybindings
  tmux bind-key -T prefix S set-window-option synchronize-panes \; \
    display-message "#{?synchronize-panes,🔗 Sync ON - typing goes to ALL panes,🔓 Sync OFF}" 2>/dev/null
}

# ── Cleanup co-op worktrees ──
_battle_cleanup_worktrees() {
  for _wt in "$tmpdir"/work_*(N); do
    if [ -d "$_wt" ]; then
      git -C "$workdir" worktree remove "$_wt" 2>/dev/null
      [ -L "$_wt" ] && rm -f "$_wt"
    fi
  done
}
