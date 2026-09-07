#!/usr/bin/env bash
# dsh + Figma setup for macOS, Ubuntu and WSL
set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s      %s\n' "$GREEN✓$OFF" "$*"; }
warn() { printf '%s      %s\n' "$YEL!$OFF" "$*"; }
die()  { printf '\n%sSETUP FAILED%s\n\n%s\n\n' "$RED" "$OFF" "$*"; exit 1; }

# ---------- detect platform ----------
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="mac" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl"; else OS="linux"; fi
    ;;
esac
[ "$OS" = "unknown" ] && die "Unsupported OS: $(uname -s). On Windows use setup.bat instead."

say ""
say "${BOLD}============================================${OFF}"
say "${BOLD}  dsh + Figma - Setup${OFF}"
say "${BOLD}============================================${OFF}"
say ""
say "Platform: ${BOLD}$OS${OFF}"
say ""

if [ "$OS" = "linux" ] || [ "$OS" = "wsl" ]; then
  say "${YEL}NOTE${OFF}  Figma Desktop does not exist on Linux."
  say "      dsh and coding will work. Figma ${BOLD}write${OFF} access will not,"
  say "      because the Desktop Bridge plugin needs the desktop app."
  if [ "$OS" = "wsl" ]; then
    say "      On WSL you can run Figma on the Windows side — see README."
  fi
  say ""
fi

read -r -p "Press Enter to continue, Ctrl+C to cancel... " _
say ""

# ---------- 1. Node.js ----------
say "${BOLD}[1/3]${OFF} Checking Node.js..."
if command -v node >/dev/null 2>&1; then
  ok "Found $(node -v)"
else
  say "       Not found. Installing..."
  case "$OS" in
    mac)
      command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install it from https://brew.sh then run this again."
      brew install node || die "brew install node failed."
      ;;
    linux|wsl)
      say "       Using nvm (does not need sudo)."
      curl -fsSL -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
        || die "nvm install failed. Check your internet connection."
      export NVM_DIR="$HOME/.nvm"
      # shellcheck disable=SC1091
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      nvm install --lts || die "nvm install --lts failed."
      ;;
  esac
  command -v node >/dev/null 2>&1 || die "Node installed but not on PATH. Open a new terminal and run this script again."
  ok "Installed $(node -v)"
fi
say ""

# ---------- 2. Git ----------
say "${BOLD}[2/3]${OFF} Checking Git..."
if command -v git >/dev/null 2>&1; then
  ok "Found $(git --version | awk '{print $3}')"
else
  say "       Not found. Installing..."
  case "$OS" in
    mac)   brew install git || die "brew install git failed." ;;
    linux|wsl)
      sudo apt-get update -qq && sudo apt-get install -y git || die "apt install git failed."
      ;;
  esac
  ok "Installed $(git --version | awk '{print $3}')"
fi
say ""

# ---------- 3. dsh ----------
say "${BOLD}[3/3]${OFF} Installing dsh (this takes a few minutes)..."
npm install -g \
  --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs \
  @deepseek-ai/dsh || die "dsh install failed. Check the npm output above."
ok "dsh installed"

say ""

# ---------- done ----------
say "${BOLD}============================================${OFF}"
say "${BOLD}${GREEN}  INSTALL COMPLETE${OFF}"
say "${BOLD}============================================${OFF}"
say ""
say "Manual steps left — see SETUP.md for detail:"
say ""
say "  1. Set your Figma token (figma.com → Settings → Security):"
say "       ${BOLD}export FIGMA_ACCESS_TOKEN=\"figd_your_token\"${OFF}"
say "       ${BOLD}export ENABLE_MCP_APPS=true${OFF}"
say "     Add both to ~/.zshrc or ~/.bashrc so they persist."
say ""
say "  2. Copy the MCP config into your dsh profile:"
say "       ${BOLD}mkdir -p ~/.dsh/profiles/web${OFF}"
say "       ${BOLD}cp cordis.patch.yml ~/.dsh/profiles/web/${OFF}"
say "     ${DIM}If that file already has entries, merge by hand instead.${OFF}"
say ""
say "  3. Run:  ${BOLD}dsh web${OFF}"
say "     Open: http://127.0.0.1:3080"
say "     Settings → Models → add your Anthropic API key"
say "     ${DIM}console.anthropic.com${OFF}"
say ""
if [ "$OS" = "mac" ]; then
  say "  4. Open Figma Desktop, press ${BOLD}Cmd+/${OFF} , type: import"
  say "     Choose \"Import plugin from manifest…\""
  say "     File: ~/.figma-console-mcp/plugin/manifest.json"
  say "     ${DIM}(Folder appears only AFTER dsh has started the MCP server once.)${OFF}"
  say ""
  say "  5. Run the \"Figma Desktop Bridge\" plugin in your Figma file."
  say "     Wait for the green \"Connected\" status."
  say ""
  say "  6. Copy AGENTS.md into each project folder you work in."
else
  say "  4. ${YEL}Figma write access is not available on Linux.${OFF}"
  say "     Read-only Figma tools still work via your PAT."
  say "     For design creation, use a Windows or Mac machine."
  say ""
  say "  5. Copy AGENTS.md into each project folder you work in."
fi
say ""