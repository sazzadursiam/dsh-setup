#!/usr/bin/env bash
# Verify the dsh + Figma setup on macOS or Linux
set -uo pipefail

GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
FAIL=0

pass() { printf '  %s[ OK ]%s %s\n' "$GREEN" "$OFF" "$*"; }
fail() { printf '  %s[FAIL]%s %s\n' "$RED" "$OFF" "$*"; FAIL=1; }
warn() { printf '  %s[WARN]%s %s\n' "$YEL" "$OFF" "$*"; }
hint() { printf '         %s%s%s\n' "$DIM" "$*" "$OFF"; }

OS="linux"
case "$(uname -s)" in
  Darwin) OS="mac" ;;
esac

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
  hint "npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs @deepseek-ai/dsh"
fi

# ---------- Figma token ----------
if [ -n "${FIGMA_ACCESS_TOKEN:-}" ]; then
  pass "FIGMA_ACCESS_TOKEN is set"
  case "$FIGMA_ACCESS_TOKEN" in
    figd_*) ;;
    *) warn "Token does not start with figd_ - check you copied the right value" ;;
  esac
else
  fail "FIGMA_ACCESS_TOKEN not set in this shell"
  hint 'export FIGMA_ACCESS_TOKEN="figd_..."  (add it to ~/.zshrc or ~/.bashrc)'
fi

# ---------- ENABLE_MCP_APPS ----------
if [ -n "${ENABLE_MCP_APPS:-}" ]; then
  pass "ENABLE_MCP_APPS = $ENABLE_MCP_APPS"
else
  warn "ENABLE_MCP_APPS not set"
  hint "export ENABLE_MCP_APPS=true"
fi

# ---------- MCP config ----------
CFG="$HOME/.dsh/profiles/web/cordis.patch.yml"
if [ ! -f "$CFG" ]; then
  fail "cordis.patch.yml not found"
  hint "Run dsh web once to create the profile, then copy the config."
elif grep -q "serverName: figma" "$CFG"; then
  pass "MCP config has the figma entry"
else
  fail "cordis.patch.yml has no figma entry"
  hint "cp cordis.patch.yml ~/.dsh/profiles/web/"
fi

# ---------- Anthropic key ----------
if [ -f "$HOME/.dsh/.credentials.yaml" ]; then
  pass "Credentials file exists"
else
  warn "No credentials file yet"
  hint "Add your API key in dsh: Settings > Models"
fi

# ---------- Bridge plugin ----------
PLUG="$HOME/.figma-console-mcp/plugin/manifest.json"
if [ "$OS" = "mac" ]; then
  if [ -f "$PLUG" ]; then
    pass "Bridge plugin files present"
    hint "Import in Figma Desktop: Cmd+/ then type \"import\""
    hint "$PLUG"
  else
    fail "Bridge plugin files not generated yet"
    hint "Start dsh web and open a session once, then re-run this."
  fi
else
  warn "Figma write access is not available on Linux (no desktop app)"
  hint "Read-only Figma tools still work via your PAT."
fi

# ---------- AGENTS.md freshness ----------
# Pulling this repo updates templates/AGENTS.md, but every project keeps its own
# copy. Compare the version stamps so a stale copy does not sit there silently.
# Usage: ./verify.sh [project-dir]   (defaults to the current directory)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/templates/AGENTS.md"
TARGET_DIR="${1:-$PWD}"

stamp_of() { grep -m1 'dsh-setup-template-version:' "$1" 2>/dev/null | awk '{print $3}'; }

if [ ! -f "$TEMPLATE" ]; then
  warn "Template missing: $TEMPLATE"
elif [ "$(cd "$TARGET_DIR" 2>/dev/null && pwd)" = "$SCRIPT_DIR" ]; then
  printf '  %s[INFO]%s AGENTS.md check skipped - run from a project folder, or: ./verify.sh <project-dir>\n' "$DIM" "$OFF"
elif [ ! -d "$TARGET_DIR" ]; then
  fail "Not a directory: $TARGET_DIR"
elif [ ! -f "$TARGET_DIR/AGENTS.md" ]; then
  warn "No AGENTS.md in $TARGET_DIR"
  hint "cp \"$TEMPLATE\" \"$TARGET_DIR/\""
else
  TPL_V="$(stamp_of "$TEMPLATE")"
  PRJ_V="$(stamp_of "$TARGET_DIR/AGENTS.md")"
  if [ -z "$PRJ_V" ]; then
    warn "AGENTS.md has no version stamp - it predates versioning (template is v$TPL_V)"
    hint "diff \"$TARGET_DIR/AGENTS.md\" \"$TEMPLATE\""
  elif [ "$PRJ_V" = "$TPL_V" ]; then
    pass "AGENTS.md is current (v$PRJ_V)"
  else
    warn "AGENTS.md is v$PRJ_V but the template is v$TPL_V - re-apply the changes"
    hint "diff \"$TARGET_DIR/AGENTS.md\" \"$TEMPLATE\""
    hint "Copy the changed sections across by hand. Do NOT overwrite the whole"
    hint "file - you would lose everything under '## Project specifics'."
    hint "Changed rules only reach a session started AFTER the edit."
  fi
fi

# ---------- dsh running? ----------
if command -v lsof >/dev/null 2>&1 && lsof -i :3080 >/dev/null 2>&1; then
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
  if [ "$OS" = "mac" ]; then
    printf '\n  Last step is manual: open Figma Desktop, run the\n'
    printf '  "Figma Desktop Bridge" plugin, and look for the\n'
    printf '  green "Connected" status.\n'
  fi
  printf '\n  Then in a dsh session, run:  figma_get_status\n'
fi
printf '%s============================================%s\n\n' "$BOLD" "$OFF"

exit $FAIL