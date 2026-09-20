#!/usr/bin/env bash
# dsh + Figma setup for macOS, Ubuntu and other Linux distros
set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s      %s\n' "$GREEN✓$OFF" "$*"; }
warn() { printf '%s      %s\n' "$YEL!$OFF" "$*"; }
die()  { printf '\n%sSETUP FAILED%s\n\n%s\n\n' "$RED" "$OFF" "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

WITH_FIGMA=0
for arg in "$@"; do
  case "$arg" in
    --with-figma) WITH_FIGMA=1 ;;
    *)            die "Unknown argument: $arg   (try --with-figma)" ;;
  esac
done

# ---------- detect platform ----------
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
esac
[ "$OS" = "unknown" ] && die "Unsupported OS: $(uname -s). On Windows use setup.bat instead."

say ""
say "${BOLD}============================================${OFF}"
say "${BOLD}  dsh + Figma - Setup${OFF}"
say "${BOLD}============================================${OFF}"
say ""
say "Platform: ${BOLD}$OS${OFF}"
say ""

if [ "$OS" = "linux" ]; then
  say "${YEL}NOTE${OFF}  Figma Desktop does not exist on Linux."
  say "      dsh and coding will work. Figma ${BOLD}write${OFF} access will not,"
  say "      because the Desktop Bridge plugin needs the desktop app."
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
    linux)
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
    linux)
      # Node comes from nvm, which is distro-agnostic; git has to come from
      # whatever package manager this distro actually ships.
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y git
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm git
      elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive install git
      elif command -v apk >/dev/null 2>&1; then
        sudo apk add git
      else
        die "No supported package manager found (apt-get, dnf, pacman, zypper, apk).
Install git with your distro's tool, then run this again."
      fi || die "git install failed. Install it by hand, then run this again."
      ;;
  esac
  ok "Installed $(git --version | awk '{print $3}')"
fi
say ""

# ---------- 3. dsh ----------
# Pinned, not "latest": the newest release on the registry is not always one
# this setup can use. DSH_VERSION records the version we install; see the
# blocked list in plugins/team-updater/cordis.patch.yml for what is being
# avoided and why. Empty or missing file means "whatever is latest".
DSH_SPEC="@deepseek-ai/dsh"
if [ -f "$SCRIPT_DIR/DSH_VERSION" ]; then
  DSH_PIN="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/DSH_VERSION")"
  [ -n "$DSH_PIN" ] && DSH_SPEC="@deepseek-ai/dsh@$DSH_PIN"
fi
# The packages whose install scripts npm may run. It belongs to the pinned
# version - a new dsh can bring a new native dependency - so it lives in
# DSH_ALLOW_SCRIPTS next to DSH_VERSION, read by every install path.
DSH_ALLOW="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/DSH_ALLOW_SCRIPTS" 2>/dev/null)"
[ -n "$DSH_ALLOW" ] || die "DSH_ALLOW_SCRIPTS is missing or empty - this checkout is incomplete."
say "${BOLD}[3/3]${OFF} Installing dsh ${DSH_PIN:-latest} (this takes a few minutes)..."
npm install -g --allow-scripts="$DSH_ALLOW" "$DSH_SPEC" || die "dsh install failed. Check the npm output above."
ok "dsh installed"

say ""

# ---------- Figma integration (opt-in) ----------
INSTALL_FIGMA=0
if [ "$WITH_FIGMA" = 1 ]; then
  INSTALL_FIGMA=1
else
  say "${BOLD}[+]${OFF} Figma integration"
  say "    Adds a Figma MCP server (125 extra tools) and a Settings token row."
  say "    Skip if you only do coding work - add it later from Settings → General"
  say "    (\"Add Figma integration\" row), no terminal needed."
  if [ -t 0 ]; then
    printf "    Install Figma integration now? [y/N] "
    read -r FIGMA_ANS
    case "$FIGMA_ANS" in y|Y|yes|YES) INSTALL_FIGMA=1 ;; esac
  else
    say "    Not an interactive terminal - skipping by default."
  fi
  say ""
fi

# ---------- dsh plugins (update button, Figma MCP) ----------
# `dsh plugin ... add` appends each bundle by itself, because the packages
# declare dsh.bundle.patch - but only once the web profile exists. Rather than
# ask the user to run `dsh web` first and re-run this script, --dump-config
# creates the profile as a side effect and exits immediately, no server or
# browser involved.
say "${BOLD}[+]${OFF} Adding dsh plugins (update button, Figma MCP)..."
PLUGIN_LOG="${TMPDIR:-/tmp}/dsh-setup-plugin-add.log"
if [ ! -d "${DSH_HOME:-$HOME/.dsh}/profiles/web" ]; then
  dsh --profile web --dump-config >/dev/null 2>&1
fi
# pnpm resolves a `file:` spec as a filesystem path, and on Git Bash/MSYS
# $SCRIPT_DIR is POSIX-style (/c/Users/...) - pnpm fails on that with
# ERR_PNPM_LINKED_PKG_DIR_NOT_FOUND. cygpath -w gives it a path it accepts;
# elsewhere (mac/linux) cygpath does not exist and $SCRIPT_DIR is used as-is.
PLUGIN_DIR="$SCRIPT_DIR"
command -v cygpath >/dev/null 2>&1 && PLUGIN_DIR="$(cygpath -w "$SCRIPT_DIR")"
case "$SCRIPT_DIR" in
  # pnpm uses brackets in lockfile keys and fails with "Mismatch parenthesis".
  *'('*|*')'*)
    warn "Skipped: pnpm cannot install a plugin from a folder whose path contains a bracket."
    say  "        Move this checkout to a path without ( or ) and run this again." ;;
  *)
    if [ ! -d "${DSH_HOME:-$HOME/.dsh}/profiles/web" ]; then
      warn "Could not create the web profile - run 'dsh web' once, then re-run this script"
    else
      # `dsh plugin` runs whatever pnpm is on PATH and does not ship one. Major
      # 12 is what this was tested with; its install script swaps in the native
      # binary, which npm 11 only runs when allowed.
      if ! command -v pnpm >/dev/null 2>&1; then
        say "        pnpm not found - installing it, dsh plugins need it..."
        npm install -g --allow-scripts=pnpm pnpm@12 || warn "pnpm install failed - see the npm output above"
      fi
      # A hand-copied profile from before figma-bridge existed would otherwise
      # end up with two "serverName: figma" rows once the plugin is added.
      command -v node >/dev/null 2>&1 && node "$SCRIPT_DIR/plugins/figma-bridge/lib/migrate.js"
      PLUGINS_TO_INSTALL="team-updater"
      [ "$INSTALL_FIGMA" = 1 ] && PLUGINS_TO_INSTALL="$PLUGINS_TO_INSTALL figma-bridge"
      for plugin in $PLUGINS_TO_INSTALL; do
        if dsh plugin --profile web add "file:$PLUGIN_DIR/plugins/$plugin" >"$PLUGIN_LOG" 2>&1; then
          ok "$plugin added"
        else
          warn "Could not add $plugin. pnpm said:"
          sed 's/^/        /' "$PLUGIN_LOG"
          say  "        Run this by hand once the cause is fixed:"
          say  "        dsh plugin --profile web add \"file:$PLUGIN_DIR/plugins/$plugin\""
        fi
      done
    fi ;;
esac

say ""

# ---------- agent rules ----------
# One file per machine at ~/.dsh/AGENTS.md, which dsh loads into every session
# of every project. Asks once which roles this machine works in.
say "${BOLD}[+]${OFF} Setting up the shared agent rules..."
if [ -f "$SCRIPT_DIR/agents.sh" ]; then
  bash "$SCRIPT_DIR/agents.sh" || warn "Could not write the agent rules - run ./agents.sh by hand"
else
  warn "agents.sh is missing from this checkout - skipping"
fi

say ""

# ---------- done ----------
say "${BOLD}============================================${OFF}"
say "${BOLD}${GREEN}  INSTALL COMPLETE${OFF}"
say "${BOLD}============================================${OFF}"
say ""
say "Manual steps left — see SETUP.md for detail:"
say ""
if [ "$INSTALL_FIGMA" = 1 ]; then
  say "  1. Set your Figma token (figma.com → Settings → Security):"
  say "       Run ${BOLD}dsh web${OFF}, then Settings → General → \"Figma token\" — paste it there."
  say "       ${DIM}(No terminal needed for this; restart dsh after saving.)${OFF}"
  say "     Or by hand: ${BOLD}export FIGMA_ACCESS_TOKEN=\"figd_your_token\"${OFF}"
  say "                 ${BOLD}export ENABLE_MCP_APPS=true${OFF}"
  say "                 Add both to ~/.zshrc or ~/.bashrc so they persist."
else
  say "  ${DIM}Figma integration was skipped. Add it later from Settings → General${OFF}"
  say "  ${DIM}(\"Add Figma integration\" row), or run:${OFF}"
  say "  ${DIM}dsh plugin --profile web add \"file:$SCRIPT_DIR/plugins/figma-bridge\"${OFF}"
fi
say ""
say "  2. Run:  ${BOLD}dsh web${OFF}"
say "     Open: http://127.0.0.1:3080"
say "     Settings → Models → add your API key: DeepSeek or Anthropic"
say "     ${DIM}platform.deepseek.com or console.anthropic.com${OFF}"
say ""
if [ "$INSTALL_FIGMA" = 1 ]; then
  if [ "$OS" = "mac" ]; then
    say "  3. Open Figma Desktop, press ${BOLD}Cmd+/${OFF} , type: import"
    say "     Choose \"Import plugin from manifest…\""
    say "     File: ~/.figma-console-mcp/plugin/manifest.json"
    say "     ${DIM}(Folder appears only AFTER dsh has started the MCP server once.)${OFF}"
    say ""
    say "  4. Run the \"Figma Desktop Bridge\" plugin in your Figma file."
    say "     Wait for the green \"Connected\" status."
  else
    say "  3. ${YEL}Figma write access is not available on Linux.${OFF}"
    say "     Read-only Figma tools still work via your PAT."
    say "     For design creation, use a Windows or Mac machine."
  fi
  say ""
fi
say "  ${DIM}The shared agent rules are already installed at ~/.dsh/AGENTS.md and${OFF}"
say "  ${DIM}apply to every project. Per-project rules go in that project's own${OFF}"
say "  ${DIM}AGENTS.md - see templates/project.example.md.${OFF}"
say ""