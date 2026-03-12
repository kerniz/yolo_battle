#!/bin/zsh
# ════════════════════════════════════════
# workspace.zsh — Workspace and worktree management
# Sourced by battle.zsh (parent context)
# ════════════════════════════════════════

# ── prepare workspace (tmpdir, git baseline) ──
_battle_setup_workspace() {
  tmpdir=$(mktemp -d /tmp/yolo-battle-XXXXXX)
  savedir="$HOME/yolo-results/$(date +%Y%m%d-%H%M%S)"
  workdir="$(pwd)"
  _coop_use_worktree=true

  if [[ "$mode" == "collaborative" ]]; then
    if ! git -C "$workdir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      _coop_use_worktree=false
      printf "${yellow}${bold}  ⚠ Git repo not detected. Co-op will run in a shared workdir (no worktree isolation).${reset}\n"
    fi
  fi

  printf '%s' "$mode" > "$tmpdir/mode.txt"
  printf '%s' "$workdir" > "$tmpdir/workdir.txt"
  echo "0" > "$tmpdir/seq_turn.txt"

  git -C "$workdir" diff HEAD --stat > "$tmpdir/git_baseline.txt" 2>/dev/null
  git -C "$workdir" rev-parse HEAD > "$tmpdir/git_head.txt" 2>/dev/null

  echo "1" > "$tmpdir/round.txt"
  git -C "$workdir" rev-parse HEAD > "$tmpdir/git_head_track.txt" 2>/dev/null
}

# ── reset mode-dependent state (for restart loop) ──
_battle_reset_state() {
  printf '%s' "$mode" > "$tmpdir/mode.txt"
  echo "0" > "$tmpdir/seq_turn.txt"
  rm -f "$tmpdir/seq_order_map.txt" "$tmpdir"/run_*.sh(N) "$tmpdir/cmd_center.sh" "$tmpdir/monitor.sh" "$tmpdir/ai_panes.txt"
  rm -f "$tmpdir"/status_*(N) "$tmpdir"/diff_*(N)
  for _wt in "$tmpdir"/work_*(N); do
    if [ -d "$_wt" ]; then
      git -C "$workdir" worktree remove "$_wt" 2>/dev/null
      [ -L "$_wt" ] && rm -f "$_wt"
    fi
  done
}

# ── cleanup co-op worktrees ──
_battle_cleanup_worktrees() {
  for _wt in "$tmpdir"/work_*(N); do
    if [ -d "$_wt" ]; then
      git -C "$workdir" worktree remove "$_wt" 2>/dev/null
      [ -L "$_wt" ] && rm -f "$_wt"
    fi
  done
}
