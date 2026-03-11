#!/bin/bash
# yolo_battle installer
set -e

YOLO_DIR="${HOME}/.yolo"
YELLOW='\033[38;5;220m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
PURPLE='\033[38;5;141m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

printf "\n"
printf "  ${PURPLE}${BOLD}╔══════════════════════════════════════╗${RESET}\n"
printf "  ${PURPLE}${BOLD}║${RESET}  ${YELLOW}${BOLD}⚡ Y O L O   B A T T L E${RESET}            ${PURPLE}${BOLD}║${RESET}\n"
printf "  ${PURPLE}${BOLD}║${RESET}  ${DIM}Multi-agent AI battle system${RESET}        ${PURPLE}${BOLD}║${RESET}\n"
printf "  ${PURPLE}${BOLD}╚══════════════════════════════════════╝${RESET}\n"
printf "\n"

# check zsh
if ! command -v zsh >/dev/null 2>&1; then
  printf "  ${RED}${BOLD}✖  zsh is required${RESET}\n"
  exit 1
fi

# check tmux
if ! command -v tmux >/dev/null 2>&1; then
  printf "  ${YELLOW}${BOLD}⚠  tmux not found${RESET} ${DIM}(required for battle mode)${RESET}\n"
  printf "  ${DIM}  brew install tmux  ${RESET}${DIM}# macOS${RESET}\n"
  printf "  ${DIM}  apt install tmux   ${RESET}${DIM}# Ubuntu/Debian${RESET}\n\n"
fi

# check AI CLIs
printf "  ${DIM}Checking AI CLIs...${RESET}\n"
found=0
for cli in claude gemini codex; do
  if command -v "$cli" >/dev/null 2>&1; then
    printf "  ${GREEN}${BOLD}✔${RESET} ${cli}\n"
    found=$((found + 1))
  else
    printf "  ${DIM}·  ${cli} (not installed)${RESET}\n"
  fi
done
printf "\n"

if [ $found -eq 0 ]; then
  printf "  ${RED}${BOLD}✖  No AI CLI found. Install at least one:${RESET}\n"
  printf "  ${DIM}  npm install -g @anthropic-ai/claude-code  ${RESET}${DIM}# Claude${RESET}\n"
  printf "  ${DIM}  npm install -g @google/gemini-cli         ${RESET}${DIM}# Gemini${RESET}\n"
  printf "  ${DIM}  npm install -g @openai/codex              ${RESET}${DIM}# Codex${RESET}\n\n"
  exit 1
fi

# install files
printf "  ${DIM}Installing to ${YOLO_DIR}...${RESET}\n"
mkdir -p "$YOLO_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/yolo.zsh" "$YOLO_DIR/yolo.zsh"
cp "$SCRIPT_DIR/battle.zsh" "$YOLO_DIR/battle.zsh"
mkdir -p "$YOLO_DIR/modes"
cp "$SCRIPT_DIR/modes/"*.zsh "$YOLO_DIR/modes/" 2>/dev/null
chmod +x "$YOLO_DIR/yolo.zsh" "$YOLO_DIR/battle.zsh"

printf "  ${GREEN}${BOLD}✔${RESET} Files installed\n\n"

# add to shell config
ZSHRC="${HOME}/.zshrc"
SOURCE_LINE='# yolo battle'
SOURCE_CMD="source \"\${HOME}/.yolo/yolo.zsh\""

if grep -q "yolo/yolo.zsh" "$ZSHRC" 2>/dev/null; then
  printf "  ${DIM}Already in .zshrc, skipping...${RESET}\n"
else
  printf "\n${SOURCE_LINE}\n${SOURCE_CMD}\n" >> "$ZSHRC"
  printf "  ${GREEN}${BOLD}✔${RESET} Added to ~/.zshrc\n"
fi

printf "\n"
printf "  ${GREEN}${BOLD}✔  Installation complete!${RESET}\n"
printf "\n"
printf "  ${YELLOW}${BOLD}Usage:${RESET}\n"
printf "  ${DIM}  source ~/.zshrc          ${RESET}${DIM}# reload shell${RESET}\n"
printf "  ${DIM}  yolo                     ${RESET}${DIM}# interactive tool picker${RESET}\n"
printf "  ${DIM}  yolo claude              ${RESET}${DIM}# direct launch${RESET}\n"
printf "  ${DIM}  yolo battle \"prompt\"      ${RESET}${DIM}# parallel battle${RESET}\n"
printf "  ${DIM}  yolo battle -s \"prompt\"   ${RESET}${DIM}# sequential battle${RESET}\n"
printf "  ${DIM}  yolo battle -c \"prompt\"   ${RESET}${DIM}# collaborative battle${RESET}\n"
printf "\n"
