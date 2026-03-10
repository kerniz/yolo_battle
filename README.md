# ⚔️ YOLO Battle

Multi-agent AI battle system for your terminal. Run Claude, Gemini, and Codex simultaneously with no guardrails.

```
┌──────────────────┬──────────────────┐
│  🤖 CLAUDE       │  ✨ GEMINI       │
│                  │                  │
│  Working...      │  Working...      │
│                  │                  │
├──────────────────┼──────────────────┤
│  🧠 CODEX        │  ⌨️ COMMAND      │
│                  │  CENTER          │
│  Working...      │  ▸ _             │
└──────────────────┴──────────────────┘
⚔️ BATTLE ⠋ 12s  🤖 claude ⣾ │ ✨ gemini ⣾ │ 🧠 codex ⣾
```

## Requirements

- **zsh** (default on macOS)
- **tmux** (`brew install tmux`)
- At least **2** of the following AI CLIs:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — `npm install -g @anthropic-ai/claude-code`
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli) — `npm install -g @anthropic-ai/claude-code`
  - [Codex CLI](https://github.com/openai/codex) — `npm install -g @openai/codex`

## Install

```bash
git clone git@github.com:kerniz/yolo_battle.git
cd yolo_battle
./install.sh
source ~/.zshrc
```

Or manually:

```bash
mkdir -p ~/.yolo
cp yolo.zsh battle.zsh ~/.yolo/
echo 'source "${HOME}/.yolo/yolo.zsh"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

### Single Tool

```bash
yolo              # interactive picker (↑↓ + Enter)
yolo claude       # direct launch
yolo gemini
yolo codex
```

### Battle Mode

```bash
yolo battle "build a REST API"          # parallel (default)
yolo battle -p "build a REST API"       # parallel (explicit)
yolo battle -s "build a REST API"       # sequential
yolo battle -c "build a REST API"       # collaborative
```

## Battle Modes

### ⚡ Parallel (`-p`, default)

All AIs receive the same prompt and work simultaneously. Compare their approaches side-by-side.

### ➡️ Sequential (`-s`)

One AI at a time. Choose execution order, then advance with `/next`.

```
  ➡️  순차 모드 - 실행 순서
   1) 🤖  claude
   2) ✨  gemini
   3) 🧠  codex
  순서 입력 (예: 2 1 3) [기본: 1 2 3]: 3 1 2

  ✔ 실행 순서: 🧠 codex → 🤖 claude → ✨ gemini
```

### 🤝 Collaborative (`-c`)

Role-based pipeline where each AI has a specific job:

| AI | Role | Task |
|---|---|---|
| 🤖 Claude | Developer | Write production code |
| ✨ Gemini | Reviewer | Code review & improvements |
| 🧠 Codex | Tester | Write comprehensive tests |

## Command Center

The 4th pane is your control center. Type to broadcast to all AIs (or current AI in sequential mode).

| Command | Description |
|---|---|
| `(any text)` | Send to AI pane(s) |
| `/status` | Check each AI's status |
| `/save` | Save all outputs to `~/yolo-results/` |
| `/prompt X` | Change prompt |
| `/next` | Start next AI (sequential only) |
| `/skip` | Skip current AI (sequential only) |
| `/focus N` | Focus on pane N |
| `/mode X` | Show mode switch instructions |
| `/quit` | Kill session |

## Tmux Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+B → arrow` | Navigate panes |
| `Ctrl+B → z` | Fullscreen toggle |
| `Ctrl+B → S` | Sync typing to all panes |
| `Ctrl+B → d` | Detach (session keeps running) |

Reattach with `tmux attach -t yolo-battle`.

## Status Bar

The bottom status bar shows real-time status for each AI:

- `⠋` spinning = working
- `⏳` = waiting (sequential mode)
- `✔ 12s` = done with elapsed time
- `ALL DONE ✦` = all complete

## Uninstall

```bash
rm -rf ~/.yolo
# Remove the source line from ~/.zshrc
```

## License

MIT
