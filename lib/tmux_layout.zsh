#!/bin/zsh
# ════════════════════════════════════════
# tmux_layout.zsh — tmux session creation and styling
# Sourced by battle.zsh (parent context)
# ════════════════════════════════════════

# ── create tmux session with panes ──
_battle_setup_tmux() {
  tmux kill-session -t "$session" 2>/dev/null
  _ai_pane_ids=()

  if [ $cnt -eq 2 ]; then
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
}

# ── configure tmux options (mouse, borders, status bar, keybindings) ──
_battle_setup_tmux_options() {
  tmux set-option -t "$session" mouse on 2>/dev/null
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
