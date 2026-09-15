#!/usr/bin/env bash
# Check whether new commits have landed on the shared repo, and offer to
# update. Built to be safe to run on a schedule: when this checkout is already
# up to date it prints one line and exits, so a cron/LaunchAgent run is silent.
# It only stops and asks when there is something new.
set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s[ OK ]%s %s\n' "$GREEN" "$OFF" "$*"; }
warn() { printf '  %s[WARN]%s %s\n' "$YEL" "$OFF" "$*"; }
info() { printf '  %s[INFO]%s %s\n' "$DIM" "$OFF" "$*"; }
die()  { printf '\n%sCHECK FAILED%s\n\n%s\n\n' "$RED" "$OFF" "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || die "Cannot enter $SCRIPT_DIR"

command -v git >/dev/null 2>&1 || die "git not found."
git rev-parse --git-dir >/dev/null 2>&1 || die "$SCRIPT_DIR is not a git clone."

say ""
say "  Checking for updates..."

# A fetch only refreshes origin/* - it never touches your working tree. The
# actual pull happens in update.sh, and only after you answer y.
git fetch --quiet || {
  warn "Could not reach the repo to check (offline?)."
  die "Nothing changed. Run ./update.sh when you are back online."
}

git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 \
  || die "This clone has no upstream branch to check against. Run ./update.sh by hand."

BEHIND="$(git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)"

if [ "$BEHIND" -eq 0 ]; then
  ok "Already up to date"
  exit 0
fi

say ""
say "  ${BOLD}${BEHIND} update(s) available.${OFF}"
say "  The shared rules and dsh itself may have changed."
say ""
printf '  Update now? [y/N] '
read -r ANS
case "$ANS" in
  y|Y) bash "$SCRIPT_DIR/update.sh" ;;
  *)   info "Skipped - run ./update.sh whenever you want." ;;
esac
