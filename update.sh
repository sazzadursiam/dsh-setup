#!/usr/bin/env bash
# Update an existing dsh + Figma setup on macOS or Linux.
#
#   ./update.sh                        pull, update dsh, rewrite the agent rules
#   ./update.sh --skip-dsh             pull only, leave the npm package alone
#   ./update.sh --role=figma           also change which role blocks this machine gets
#
# Nothing here touches your projects. The shared agent rules live in one file per
# machine, ~/.dsh/AGENTS.md, which dsh loads into every session automatically —
# so there are no per-project copies to fall behind.
set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s[ OK ]%s %s\n' "$GREEN" "$OFF" "$*"; }
warn() { printf '  %s[WARN]%s %s\n' "$YEL" "$OFF" "$*"; }
info() { printf '  %s[INFO]%s %s\n' "$DIM" "$OFF" "$*"; }
hint() { printf '         %s%s%s\n' "$DIM" "$*" "$OFF"; }
die()  { printf '\n%sUPDATE FAILED%s\n\n%s\n\n' "$RED" "$OFF" "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || die "Cannot enter $SCRIPT_DIR"

SKIP_DSH=0
AFTER_PULL=0
ROLE_ARG=""
for arg in "$@"; do
  case "$arg" in
    --skip-dsh) SKIP_DSH=1 ;;
    --after-pull) AFTER_PULL=1 ;;
    --role=*)   ROLE_ARG="$arg" ;;
    -h|--help)  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "Unknown argument: $arg   (try --help)" ;;
  esac
done

say ""
say "${BOLD}============================================${OFF}"
say "${BOLD}  dsh + Figma - Update${OFF}"
say "${BOLD}============================================${OFF}"
say ""

# ---------- 1. this repo ----------
say "${BOLD}[1/3]${OFF} Updating this repo..."
command -v git >/dev/null 2>&1 || die "git not found."
git rev-parse --git-dir >/dev/null 2>&1 || die "$SCRIPT_DIR is not a git clone. Re-clone the repo to get updates."

OLD_HEAD="$(git rev-parse HEAD 2>/dev/null)"

if [ "$AFTER_PULL" = 1 ]; then
  ok "Pulled - now running the updated copy of this script"
elif [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  warn "You have local changes - not pulling, so nothing of yours is lost."
  hint "Commit or stash them, then run this again:"
  hint "  git stash && ./update.sh && git stash pop"
else
  git pull --ff-only || die "git pull failed. Resolve it by hand, then re-run."
  NEW_HEAD="$(git rev-parse HEAD 2>/dev/null)"
  if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
    ok "Already up to date"
  else
    ok "Updated"
    say ""
    say "  ${BOLD}What changed:${OFF}"
    git log --oneline --no-decorate "$OLD_HEAD..$NEW_HEAD" | sed 's/^/    /'
    say ""
    hint "Full notes in CHANGELOG.md"
    # The rest of this run should be the script that was just pulled, not the
    # one already in memory. Kept inside this if-block, which bash has parsed
    # whole, so nothing is read from the rewritten file before the handover.
    exec bash "$SCRIPT_DIR/update.sh" --after-pull "$@"
  fi
fi
say ""

# ---------- 2. dsh itself ----------
say "${BOLD}[2/3]${OFF} Updating dsh..."
if [ "$SKIP_DSH" -eq 1 ]; then
  info "Skipped (--skip-dsh)"
elif ! command -v npm >/dev/null 2>&1; then
  warn "npm not found - skipping"
else
  # Pinned, not "latest": the newest release is not always one this setup can
  # use, and an explicit version also moves a machine back down if it already
  # took a bad one. See plugins/team-updater/cordis.patch.yml for what is
  # avoided and why.
  DSH_SPEC="@deepseek-ai/dsh"
  if [ -f "$SCRIPT_DIR/DSH_VERSION" ]; then
    DSH_PIN="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/DSH_VERSION")"
    [ -n "$DSH_PIN" ] && DSH_SPEC="@deepseek-ai/dsh@$DSH_PIN"
  fi
  say "       Installing ${DSH_PIN:-latest}. This takes a few minutes."
  # Not `npm update -g`: that does not re-apply the allowlist, leaving the
  # native modules unbuilt. See SETUP.md, Part 9.
  npm install -g \
    --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs \
    "$DSH_SPEC" && ok "dsh updated" || warn "dsh update failed - see the npm output above"
fi
say ""

# ---------- the in-GUI update button ----------
# Re-run on every update so an existing install picks the button up, and so the
# spec follows this checkout if it was moved. Adding it twice is a no-op.
say "${BOLD}[+]${OFF} Checking the in-app update button..."
if [ -d "${DSH_HOME:-$HOME/.dsh}/profiles/web" ]; then
  if dsh plugin --profile web add "file:$SCRIPT_DIR/plugins/team-updater" >/dev/null 2>&1; then
    ok "Update button present - Settings > General"
  else
    warn "Could not add it - run: dsh plugin --profile web add file:$SCRIPT_DIR/plugins/team-updater"
  fi
else
  warn "No web profile yet - run 'dsh web' once, then re-run this script"
fi
say ""

# ---------- 3. the shared agent rules ----------
say "${BOLD}[3/3]${OFF} Rewriting the shared agent rules..."
if [ ! -x "$SCRIPT_DIR/agents.sh" ] && [ ! -f "$SCRIPT_DIR/agents.sh" ]; then
  warn "agents.sh is missing from this checkout - skipping"
else
  # agents.sh reuses the roles recorded in the generated file. --no-ask keeps it
  # silent even with none recorded: roles are optional, so an update writes the
  # core rules and says how to add roles instead of stopping to ask.
  if [ -n "$ROLE_ARG" ]; then
    bash "$SCRIPT_DIR/agents.sh" --no-ask "$ROLE_ARG" || warn "Could not write the agent rules - see above"
  else
    bash "$SCRIPT_DIR/agents.sh" --no-ask || warn "Could not write the agent rules - see above"
  fi
fi

say ""
say "${BOLD}============================================${OFF}"
say "  Done. Two things this cannot do for you:"
say "  - ${BOLD}Restart your sessions.${OFF} Changed rules only reach a session"
say "    started afterwards - there is no file watcher."
say "  - ${BOLD}Update ~/.dsh/settings.yaml.${OFF} Model choice, reasoning effort and"
say "    API keys are per-machine and live outside this repo."
say ""
say "  ${DIM}Project-specific rules live in each project's own AGENTS.md and are${OFF}"
say "  ${DIM}yours to maintain - see templates/project.example.md.${OFF}"
say "${BOLD}============================================${OFF}"
say ""
