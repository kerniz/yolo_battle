#!/bin/bash
# yolo_battle installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kerniz/yolo_battle/main/install.sh | bash
#   or: git clone ... && ./install.sh
set -e

YOLO_DIR="${HOME}/.yolo"
REPO_URL="https://github.com/kerniz/yolo_battle.git"
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

# load nvm if installed (non-interactive shells don't auto-load it)
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
fi

# detect OS + package manager
OS_KIND="$(uname -s)"
PKG_MGR=""
PKG_INSTALL=""
PKG_LABEL=""
if [ "$OS_KIND" = "Linux" ]; then
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt-get"
    PKG_INSTALL="sudo apt-get update && sudo apt-get install -y"
    PKG_LABEL="Debian/Ubuntu"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
    PKG_INSTALL="sudo dnf install -y"
    PKG_LABEL="Fedora/RHEL"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
    PKG_INSTALL="sudo pacman -S --noconfirm"
    PKG_LABEL="Arch"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MGR="zypper"
    PKG_INSTALL="sudo zypper install -y"
    PKG_LABEL="openSUSE"
  elif command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"
    PKG_INSTALL="sudo apk add"
    PKG_LABEL="Alpine"
  fi
fi

# helper: attempt automatic install of a package on Linux
_auto_install() {
  local pkg="$1"
  if [ -z "$PKG_MGR" ]; then
    return 1
  fi
  printf "  ${DIM}Installing ${pkg} via ${PKG_MGR} (${PKG_LABEL})...${RESET}\n"
  if ! command -v sudo >/dev/null 2>&1; then
    printf "  ${RED}${BOLD}✖  sudo not found — cannot auto-install ${pkg}${RESET}\n"
    return 1
  fi
  # shellcheck disable=SC2086
  bash -c "${PKG_INSTALL} ${pkg}"
}

# check zsh
if ! command -v zsh >/dev/null 2>&1; then
  if [ "$OS_KIND" = "Darwin" ]; then
    printf "  ${RED}${BOLD}✖  zsh not found on macOS (unexpected)${RESET}\n"
    printf "  ${DIM}  brew install zsh${RESET}\n"
    exit 1
  fi
  printf "  ${YELLOW}${BOLD}⚠  zsh not found — attempting automatic install${RESET}\n"
  if _auto_install zsh && command -v zsh >/dev/null 2>&1; then
    printf "  ${GREEN}${BOLD}✔${RESET} zsh installed\n"
  else
    printf "  ${RED}${BOLD}✖  zsh install failed. Please install manually:${RESET}\n"
    printf "  ${DIM}  sudo apt-get install zsh       ${RESET}${DIM}# Debian/Ubuntu${RESET}\n"
    printf "  ${DIM}  sudo dnf install zsh           ${RESET}${DIM}# Fedora/RHEL${RESET}\n"
    printf "  ${DIM}  sudo pacman -S zsh             ${RESET}${DIM}# Arch${RESET}\n"
    printf "  ${DIM}  sudo zypper install zsh        ${RESET}${DIM}# openSUSE${RESET}\n"
    printf "  ${DIM}  sudo apk add zsh               ${RESET}${DIM}# Alpine${RESET}\n"
    exit 1
  fi
fi

# check tmux
if ! command -v tmux >/dev/null 2>&1; then
  printf "  ${YELLOW}${BOLD}⚠  tmux not found${RESET} ${DIM}(required for battle mode)${RESET}\n"
  printf "  ${DIM}  brew install tmux              ${RESET}${DIM}# macOS${RESET}\n"
  printf "  ${DIM}  sudo apt-get install tmux      ${RESET}${DIM}# Debian/Ubuntu${RESET}\n"
  printf "  ${DIM}  sudo dnf install tmux          ${RESET}${DIM}# Fedora/RHEL${RESET}\n"
  printf "  ${DIM}  sudo pacman -S tmux            ${RESET}${DIM}# Arch${RESET}\n"
  printf "  ${DIM}  sudo zypper install tmux       ${RESET}${DIM}# openSUSE${RESET}\n"
  printf "  ${DIM}  sudo apk add tmux              ${RESET}${DIM}# Alpine${RESET}\n\n"
fi

# check AI CLIs
printf "  ${DIM}Checking AI CLIs...${RESET}\n"
found=0
for cli in claude gemini codex opencode; do
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
  printf "  ${DIM}  npm install -g @openai/codex              ${RESET}${DIM}# Codex${RESET}\n"
  printf "  ${DIM}  npm install -g opencode-ai                ${RESET}${DIM}# OpenCode (or: brew install anomalyco/tap/opencode)${RESET}\n"
  printf "\n"
  printf "  ${YELLOW}${BOLD}Note:${RESET} ${DIM}If 'npm install -g' fails with EACCES,${RESET}\n"
  printf "  ${DIM}  install nvm for a user-owned Node:${RESET}\n"
  printf "  ${DIM}    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash${RESET}\n"
  printf "  ${DIM}    source ~/.bashrc && nvm install --lts${RESET}\n"
  printf "  ${DIM}  or set npm prefix to a user dir:${RESET}\n"
  printf "  ${DIM}    npm config set prefix \"\$HOME/.local\"${RESET}\n\n"
  exit 1
fi

# determine source: local clone or remote download
SCRIPT_DIR=""
TMPCLONE=""

if [ -f "$(cd "$(dirname "$0")" 2>/dev/null && pwd)/yolo.zsh" ] 2>/dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  printf "  ${DIM}Installing from local directory...${RESET}\n"
else
  if ! command -v git >/dev/null 2>&1; then
    printf "  ${RED}${BOLD}✖  git is required for remote install${RESET}\n"
    exit 1
  fi
  TMPCLONE="$(mktemp -d /tmp/yolo-install-XXXXXX)"
  printf "  ${DIM}Downloading from GitHub...${RESET}\n"
  git clone --depth 1 "$REPO_URL" "$TMPCLONE" 2>/dev/null
  SCRIPT_DIR="$TMPCLONE"
fi

# install files
printf "  ${DIM}Installing to ${YOLO_DIR}...${RESET}\n"
mkdir -p "$YOLO_DIR"
chmod 700 "$YOLO_DIR"

cp "$SCRIPT_DIR/yolo.zsh" "$YOLO_DIR/yolo.zsh"
cp "$SCRIPT_DIR/battle.zsh" "$YOLO_DIR/battle.zsh"
mkdir -p "$YOLO_DIR/modes"
cp "$SCRIPT_DIR/modes/"*.zsh "$YOLO_DIR/modes/" 2>/dev/null
mkdir -p "$YOLO_DIR/lib"
cp "$SCRIPT_DIR/lib/"*.zsh "$YOLO_DIR/lib/" 2>/dev/null
chmod +x "$YOLO_DIR/yolo.zsh" "$YOLO_DIR/battle.zsh"

# cleanup temp clone
if [ -n "$TMPCLONE" ]; then
  rm -rf "$TMPCLONE"
fi

printf "  ${GREEN}${BOLD}✔${RESET} Files installed\n\n"

# add to shell config
ZSHRC="${HOME}/.zshrc"
SOURCE_LINE='# yolo battle'
SOURCE_CMD="source \"\${HOME}/.yolo/yolo.zsh\""
ALIAS_CMD="alias yolo-kill='tmux kill-session -t yolo-battle 2>/dev/null'"

if [ ! -f "$ZSHRC" ]; then
  touch "$ZSHRC"
fi

if grep -q "yolo/yolo.zsh" "$ZSHRC" 2>/dev/null; then
  printf "  ${DIM}Already in .zshrc, skipping source line...${RESET}\n"
else
  printf "\n${SOURCE_LINE}\n${SOURCE_CMD}\n" >> "$ZSHRC"
  printf "  ${GREEN}${BOLD}✔${RESET} Added source line to ~/.zshrc\n"
fi

if grep -q "alias yolo-kill" "$ZSHRC" 2>/dev/null; then
  printf "  ${DIM}yolo-kill alias already present, skipping...${RESET}\n"
else
  printf "%s\n" "$ALIAS_CMD" >> "$ZSHRC"
  printf "  ${GREEN}${BOLD}✔${RESET} Added yolo-kill alias to ~/.zshrc\n"
fi

printf "\n"
printf "  ${GREEN}${BOLD}✔  Installation complete!${RESET}\n"
printf "\n"
printf "  ${YELLOW}${BOLD}Usage:${RESET}\n"
printf "  ${DIM}  exec zsh                 ${RESET}${DIM}# switch to zsh (required — yolo is zsh-only)${RESET}\n"
printf "  ${DIM}  yolo                     ${RESET}${DIM}# interactive tool picker${RESET}\n"
printf "  ${DIM}  yolo claude              ${RESET}${DIM}# direct launch${RESET}\n"
printf "  ${DIM}  yolo battle \"prompt\"      ${RESET}${DIM}# parallel battle${RESET}\n"
printf "  ${DIM}  yolo battle -s \"prompt\"   ${RESET}${DIM}# sequential battle${RESET}\n"
printf "  ${DIM}  yolo battle -c \"prompt\"   ${RESET}${DIM}# collaborative battle${RESET}\n"
printf "  ${DIM}  yolo-kill                ${RESET}${DIM}# kill stuck yolo-battle tmux session${RESET}\n"
printf "\n"
