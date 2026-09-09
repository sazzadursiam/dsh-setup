#!/usr/bin/env bash
# Update an existing dsh + Figma setup on macOS or Linux.
#
#   ./update.sh                      pull + update dsh
#   ./update.sh ~/projects/site ...  also check those projects' AGENTS.md
#   ./update.sh --skip-dsh           pull only, leave the npm package alone
#
# Project paths can also be listed one per line in `projects.txt` next to this
# script (git-ignored), so plain `./update.sh` checks them every time.
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
PROJECTS=()
for arg in "$@"; do
  case "$arg" in
    --skip-dsh) SKIP_DSH=1 ;;
    -h|--help)  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          PROJECTS+=("$arg") ;;
  esac
done

if [ ${#PROJECTS[@]} -eq 0 ] && [ -f "$SCRIPT_DIR/projects.txt" ]; then
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    PROJECTS+=("$line")
  done < "$SCRIPT_DIR/projects.txt"
fi

stamp_of() { grep -m1 'dsh-setup-template-version:' "$1" 2>/dev/null | awk '{print $3}'; }

say ""
say "${BOLD}============================================${OFF}"
say "${BOLD}  dsh + Figma - Update${OFF}"
say "${BOLD}============================================${OFF}"
say ""

# ---------- 1. this repo ----------
say "${BOLD}[1/3]${OFF} Updating this repo..."
command -v git >/dev/null 2>&1 || die "git not found."
git rev-parse --git-dir >/dev/null 2>&1 || die "$SCRIPT_DIR is not a git clone. Re-clone the repo to get updates."

OLD_TPL="$(stamp_of "$SCRIPT_DIR/templates/AGENTS.md")"
OLD_HEAD="$(git rev-parse HEAD 2>/dev/null)"

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
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
  say "       This takes a few minutes."
  # Not `npm update -g`: that does not re-apply the allowlist, leaving the
  # native modules unbuilt. See SETUP.md, Part 9.
  npm install -g \
    --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs \
    @deepseek-ai/dsh && ok "dsh updated" || warn "dsh update failed - see the npm output above"
fi
say ""

# ---------- 3. project AGENTS.md copies ----------
say "${BOLD}[3/3]${OFF} Checking project AGENTS.md copies..."
TPL="$SCRIPT_DIR/templates/AGENTS.md"
NEW_TPL="$(stamp_of "$TPL")"

if [ ${#PROJECTS[@]} -eq 0 ]; then
  info "No projects given - pass paths, or list them in projects.txt"
  hint "  ./update.sh ~/projects/my-site"
  hint "  printf '%s\\n' ~/projects/my-site > projects.txt"
  [ -n "$OLD_TPL" ] && [ "$OLD_TPL" != "$NEW_TPL" ] && \
    warn "The template moved v$OLD_TPL -> v$NEW_TPL, so your copies are now behind."
else
  STALE=0
  for p in "${PROJECTS[@]}"; do
    p="${p/#\~/$HOME}"
    if [ ! -d "$p" ]; then
      warn "$p - not a directory"
    elif [ ! -f "$p/AGENTS.md" ]; then
      warn "$p - no AGENTS.md"
      hint "cp \"$TPL\" \"$p/\""
      STALE=$((STALE+1))
    else
      V="$(stamp_of "$p/AGENTS.md")"
      if [ "$V" = "$NEW_TPL" ]; then
        ok "$p (v$V)"
      else
        if [ -n "$V" ]; then SHOWV="v$V"; else SHOWV="unstamped"; fi
        warn "$p - $SHOWV vs template v$NEW_TPL"
        hint "diff \"$p/AGENTS.md\" \"$TPL\""
        STALE=$((STALE+1))
      fi
    fi
  done
  if [ "$STALE" -gt 0 ]; then
    say ""
    say "  ${YEL}$STALE project(s) need attention.${OFF}"
    say "  Copy the changed sections across by hand - do ${BOLD}not${OFF} overwrite the"
    say "  whole file, or you lose everything under '## Project specifics'."
  fi
fi

say ""
say "${BOLD}============================================${OFF}"
say "  Done. Two things this cannot do for you:"
say "  - ${BOLD}Restart your sessions.${OFF} Changed AGENTS.md rules only reach a"
say "    session started afterwards."
say "  - ${BOLD}Update ~/.dsh/settings.yaml.${OFF} Model choice, reasoning effort and"
say "    API keys are per-machine and live outside this repo."
say "${BOLD}============================================${OFF}"
say ""
