#!/usr/bin/env bash
# Verify the dsh + Figma setup on macOS, Linux, or Windows under Git Bash
set -uo pipefail

GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
FAIL=0

pass() { printf '  %s[ OK ]%s %s\n' "$GREEN" "$OFF" "$*"; }
fail() { printf '  %s[FAIL]%s %s\n' "$RED" "$OFF" "$*"; FAIL=1; }
warn() { printf '  %s[WARN]%s %s\n' "$YEL" "$OFF" "$*"; }
hint() { printf '         %s%s%s\n' "$DIM" "$*" "$OFF"; }

OS="linux"
case "$(uname -s)" in
  Darwin)               OS="mac" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

printf '\n%s============================================%s\n' "$BOLD" "$OFF"
printf '%s  dsh + Figma - Verify%s\n' "$BOLD" "$OFF"
printf '%s============================================%s\n\n' "$BOLD" "$OFF"
printf '  Platform: %s\n\n' "$OS"

# ---------- Node ----------
if command -v node >/dev/null 2>&1; then
  pass "Node.js $(node -v)"
else
  fail "Node.js not found"
  hint "Run ./setup.sh, then open a new terminal."
fi

# ---------- Git ----------
if command -v git >/dev/null 2>&1; then
  pass "Git $(git --version | awk '{print $3}')"
else
  warn "Git not found - only needed for version control"
fi

# ---------- dsh ----------
if command -v dsh >/dev/null 2>&1; then
  pass "dsh installed"
else
  fail "dsh not found"
  hint "Run ./setup.sh - it installs the pinned version with the right allowlist."
fi

# ---------- Figma token ----------
# Two valid ways to have set this: the shell env var (export/setx, or this
# script's own environment), or the Settings > General "Figma token" row,
# which writes into the installed plugin copy's cordis.patch.yml instead -
# dsh-mcp-client never sees it as a shell env var in that case.
PLUGIN_CFG_TOKEN_CHECK="$HOME/.dsh/profiles/web/node_modules/dsh-figma-bridge/cordis.patch.yml"
if [ -n "${FIGMA_ACCESS_TOKEN:-}" ]; then
  pass "FIGMA_ACCESS_TOKEN is set in this shell"
  case "$FIGMA_ACCESS_TOKEN" in
    figd_*) ;;
    *) warn "Token does not start with figd_ - check you copied the right value" ;;
  esac
elif [ -f "$PLUGIN_CFG_TOKEN_CHECK" ] && grep -q "FIGMA_ACCESS_TOKEN:" "$PLUGIN_CFG_TOKEN_CHECK"; then
  pass "Figma token saved via Settings > General (not a shell env var - that's fine)"
else
  fail "No Figma token found - not in this shell, not in Settings"
  hint "dsh web -> Settings -> General -> Figma token   (or export FIGMA_ACCESS_TOKEN=\"figd_...\")"
fi

# ---------- ENABLE_MCP_APPS ----------
if [ -n "${ENABLE_MCP_APPS:-}" ]; then
  pass "ENABLE_MCP_APPS = $ENABLE_MCP_APPS"
elif [ -f "$PLUGIN_CFG_TOKEN_CHECK" ] && grep -q "ENABLE_MCP_APPS:" "$PLUGIN_CFG_TOKEN_CHECK"; then
  pass "ENABLE_MCP_APPS set via Settings > General (not a shell env var - that's fine)"
else
  warn "ENABLE_MCP_APPS not set"
  hint "export ENABLE_MCP_APPS=true   (or set the token via Settings > General, which sets this too)"
fi

# ---------- MCP config ----------
# Plugin-managed: the figma entry lives in the plugin's own installed copy of
# cordis.patch.yml (profiles/web/node_modules/dsh-figma-bridge/), not the
# profile's personal one - dsh plugin add appends the package as a bundle
# rather than copying its patch into the profile's own file.
CFG="$HOME/.dsh/profiles/web/cordis.patch.yml"
PROFILE_PKG="$HOME/.dsh/profiles/web/package.json"
PLUGIN_CFG="$HOME/.dsh/profiles/web/node_modules/dsh-figma-bridge/cordis.patch.yml"
if [ -f "$PROFILE_PKG" ] && grep -q '"dsh-figma-bridge"' "$PROFILE_PKG"; then
  pass "figma-bridge plugin installed (dsh plugin add)"
  if [ -f "$PLUGIN_CFG" ] && grep -q "serverName: figma" "$PLUGIN_CFG"; then
    pass "MCP config has the figma entry"
  else
    fail "figma-bridge is installed but its cordis.patch.yml has no figma entry"
    hint "dsh plugin --profile web remove dsh-figma-bridge, then re-run ./setup.sh"
  fi
  command -v node >/dev/null 2>&1 && node "$SCRIPT_DIR/plugins/figma-bridge/lib/pin.js" --check
elif [ -f "$CFG" ] && grep -q "serverName: figma" "$CFG"; then
  warn "figma entry present but not plugin-managed - looks like an old hand-copy"
  hint "./update.sh will migrate it automatically"
elif [ ! -f "$CFG" ]; then
  fail "cordis.patch.yml not found"
  hint "Run dsh web once to create the profile, then run ./setup.sh again."
else
  fail "No figma entry found"
  hint "dsh plugin --profile web add \"file:$SCRIPT_DIR/plugins/figma-bridge\""
fi

# ---------- Provider API key ----------
if [ -f "$HOME/.dsh/.credentials.yaml" ]; then
  pass "Credentials file exists"
else
  warn "No credentials file yet"
  hint "Add your API key in dsh: Settings > Models"
fi

# ---------- Bridge plugin ----------
PLUG="$HOME/.figma-console-mcp/plugin/manifest.json"
if [ "$OS" = "linux" ]; then
  warn "Figma write access is not available on Linux (no desktop app)"
  hint "Read-only Figma tools still work via your PAT."
elif [ -f "$PLUG" ]; then
  pass "Bridge plugin files present"
  if [ "$OS" = "mac" ]; then
    hint "Import in Figma Desktop: Cmd+/ then type \"import\""
  else
    hint "Import in Figma Desktop: Ctrl+/ then type \"import\""
  fi
  hint "$PLUG"
else
  fail "Bridge plugin files not generated yet"
  hint "Start dsh web and open a session once, then re-run this."
fi

# ---------- shared agent rules ----------
# dsh loads $DSH_HOME/AGENTS.md into every session of every project. It is one
# file per machine, generated by agents.sh, so all this has to check is whether
# it is there and whether it came from this version of the repo.
DSH_DIR="${DSH_HOME:-$HOME/.dsh}"
RULES="$DSH_DIR/AGENTS.md"
REPO_V="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/VERSION" 2>/dev/null)"

if [ ! -f "$RULES" ]; then
  fail "No agent rules at $RULES"
  hint "./agents.sh          (asks once which roles this machine works in)"
elif ! head -n1 "$RULES" | grep -q 'dsh-setup:'; then
  warn "$RULES exists but was not written by agents.sh - leaving it alone"
  hint "./agents.sh          (it will save a .bak first)"
else
  # tr: agents.bat writes this line with CRLF, and the trailing CR would land
  # after the "-->" the roles pattern anchors on.
  STAMP="$(head -n1 "$RULES" | tr -d '\r')"
  FILE_V="$(printf '%s\n' "$STAMP" | sed -n 's/.*dsh-setup: v\([^ ]*\).*/\1/p')"
  ROLES="$(printf '%s\n' "$STAMP" | sed -n 's/.*roles: *\([^ ]*\) *-->$/\1/p')"
  if [ "$FILE_V" = "$REPO_V" ]; then
    pass "Agent rules current (v$FILE_V, roles: ${ROLES:-none})"
  else
    warn "Agent rules are v$FILE_V but this checkout is v$REPO_V"
    hint "./agents.sh          (rewrites them; your roles are remembered)"
  fi
fi

# ---------- dsh running? ----------
# lsof is absent on plain Linux images and in Git Bash, where the port check
# would otherwise always say "not running". The netstat address separator is
# ":" on Windows and "." on BSD/macOS.
port_3080_busy() {
  command -v lsof    >/dev/null 2>&1 && lsof -i :3080          >/dev/null 2>&1 && return 0
  command -v ss      >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ':3080[[:space:]]' && return 0
  command -v netstat >/dev/null 2>&1 && netstat -an 2>/dev/null | grep -q '[:.]3080[[:space:]]' && return 0
  return 1
}
if port_3080_busy; then
  pass "Something is listening on port 3080"
else
  printf '  %s[INFO]%s dsh does not appear to be running - start it with: dsh web\n' "$DIM" "$OFF"
fi

printf '\n%s============================================%s\n' "$BOLD" "$OFF"
if [ "$FAIL" -eq 1 ]; then
  printf '%s  SOME CHECKS FAILED - see the notes above%s\n' "$RED" "$OFF"
  printf '  Details in SETUP.md\n'
else
  printf '%s  ALL CHECKS PASSED%s\n' "$GREEN" "$OFF"
  if [ "$OS" != "linux" ]; then
    printf '\n  Last step is manual: open Figma Desktop, run the\n'
    printf '  "Figma Desktop Bridge" plugin, and look for the\n'
    printf '  green "Connected" status.\n'
  fi
  printf '\n  Then in a dsh session, run:  figma_get_status\n'
fi
printf '%s============================================%s\n\n' "$BOLD" "$OFF"

exit $FAIL