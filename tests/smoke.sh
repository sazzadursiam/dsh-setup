#!/usr/bin/env bash
# Smoke test for agents.sh and verify.sh, safe to run in CI or by hand.
#
#   ./tests/smoke.sh
#
# Everything runs against a throwaway HOME/DSH_HOME under mktemp, so a real
# machine's ~/.dsh/AGENTS.md, credentials, or dsh install are never read or
# touched. This is not a substitute for running setup.sh/update.sh for real —
# it only proves agents.sh and verify.sh still behave the way the rest of this
# repo (README, SETUP.md, CHANGELOG) says they do.
set -uo pipefail

GREEN=$'\033[32m'; RED=$'\033[31m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
FAILED=0
pass() { printf '  %s[ OK ]%s %s\n' "$GREEN" "$OFF" "$*"; }
fail() { printf '  %s[FAIL]%s %s\n' "$RED" "$OFF" "$*"; FAILED=1; }
step() { printf '\n%s%s%s\n' "$BOLD" "$*" "$OFF"; }

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
export DSH_HOME="$HOME/.dsh"
mkdir -p "$HOME"
RULES="$DSH_HOME/AGENTS.md"
OUT="$SANDBOX/out.txt"

rules_exist() { [ -f "$RULES" ]; }
out_has() { grep -q "$1" "$OUT"; }

step "agents.sh --role=none"
if ./agents.sh --role=none >"$OUT" 2>&1; then pass "exits 0"; else fail "exited non-zero: $(cat "$OUT")"; fi
if rules_exist; then pass "AGENTS.md written"; else fail "AGENTS.md missing"; fi
case "$(head -n1 "$RULES" 2>/dev/null)" in
  *'roles:  -->') pass "stamp records no roles" ;;
  *) fail "stamp did not record empty roles: $(head -n1 "$RULES" 2>/dev/null)" ;;
esac

step "agents.sh --role=figma"
if ./agents.sh --role=figma >"$OUT" 2>&1; then pass "exits 0"; else fail "exited non-zero: $(cat "$OUT")"; fi
case "$(head -n1 "$RULES" 2>/dev/null)" in
  *'roles: figma'*) pass "stamp records the figma role" ;;
  *) fail "stamp missing figma: $(head -n1 "$RULES" 2>/dev/null)" ;;
esac
if grep -q "Figma" "$RULES" 2>/dev/null; then pass "role block assembled into AGENTS.md"; else fail "no Figma content found"; fi

step "agents.sh --no-ask with no rules file yet"
rm -f "$RULES"
if ./agents.sh --no-ask >"$OUT" 2>&1; then pass "exits 0, does not prompt"; else fail "exited non-zero: $(cat "$OUT")"; fi
if out_has INFO; then pass "explains itself instead of asking"; else fail "no explanation printed"; fi
if rules_exist; then pass "AGENTS.md written"; else fail "AGENTS.md missing"; fi

step "agents.sh --role=bogus is rejected"
if ./agents.sh --role=bogus >"$OUT" 2>&1; then fail "should have exited non-zero"; else pass "exits non-zero"; fi
if out_has "Unknown role"; then pass "explains why"; else fail "no explanation printed"; fi

step "agents.sh --show"
if ./agents.sh --show >"$OUT" 2>&1; then pass "exits 0"; else fail "exited non-zero: $(cat "$OUT")"; fi
if out_has "target :"; then pass "prints the target path"; else fail "missing target line"; fi

step "verify.sh reports failure with no Figma token set"
FIGMA_ACCESS_TOKEN='' ENABLE_MCP_APPS='' ./verify.sh >"$OUT" 2>&1
code=$?
if [ "$code" -eq 1 ]; then pass "exits 1"; else fail "exited $code, expected 1: $(cat "$OUT")"; fi
if out_has FAIL; then pass "prints at least one FAIL"; else fail "no FAIL line printed"; fi

step "plugins/figma-bridge/lib/migrate.js removes a hand-copied legacy entry"
PROFILE_CFG="$DSH_HOME/profiles/web/cordis.patch.yml"
mkdir -p "$DSH_HOME/profiles/web"
cat > "$PROFILE_CFG" <<'EOF'
# Your patch layer for this dsh profile, applied after every bundle layer:
- insert:
    - id: mcp-figma
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: figma
        transport: stdio
        command: npx
        args: ['-y', 'figma-console-mcp@latest']
EOF
if node plugins/figma-bridge/lib/migrate.js >"$OUT" 2>&1; then pass "exits 0"; else fail "exited non-zero: $(cat "$OUT")"; fi
if grep -q "serverName: figma" "$PROFILE_CFG"; then fail "legacy entry still present"; else pass "legacy entry removed"; fi
if [ -f "$PROFILE_CFG.bak" ]; then pass "backup written"; else fail "no .bak written"; fi
if node plugins/figma-bridge/lib/migrate.js >"$OUT" 2>&1; then pass "second run exits 0"; else fail "second run exited non-zero: $(cat "$OUT")"; fi
if out_has "no legacy entry found"; then pass "second run is a clean no-op"; else fail "second run did not report a no-op: $(cat "$OUT")"; fi

echo ""
if [ "$FAILED" -eq 0 ]; then
  printf '%sall smoke checks passed%s\n' "$GREEN" "$OFF"
else
  printf '%ssome smoke checks failed%s\n' "$RED" "$OFF"
fi
exit "$FAILED"
