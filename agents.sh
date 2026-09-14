#!/usr/bin/env bash
# Write the shared agent rules to ~/.dsh/AGENTS.md.
#
#   ./agents.sh                              regenerate using the remembered settings
#   ./agents.sh --role=figma,visual-assets   set the roles for this machine
#   ./agents.sh --role=none                  core rules only, no role block
#   ./agents.sh --lang=Bengali               reply language (default: English)
#   ./agents.sh --show                       print the target path and current settings
#   ./agents.sh --no-ask                     never prompt: with no roles yet, core rules only
#
# dsh loads $DSH_HOME/AGENTS.md (default ~/.dsh/AGENTS.md) into every session of
# every project, before any project's own AGENTS.md. So the shared rules live
# there once per machine instead of being copied into each project, where copies
# drift and go stale.
#
# Which roles apply is a property of the person at this machine, not of the
# repo, so it is asked once and remembered in the generated file's first line.
#
# Project-specific rules belong in that project's own AGENTS.md, which this
# script never touches. See templates/project.example.md.
set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s[ OK ]%s %s\n' "$GREEN" "$OFF" "$*"; }
warn() { printf '  %s[WARN]%s %s\n' "$YEL" "$OFF" "$*"; }
info() { printf '  %s[INFO]%s %s\n' "$DIM" "$OFF" "$*"; }
die()  { printf '\n%s[FAIL]%s %s\n\n' "$RED" "$OFF" "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TPL="$SCRIPT_DIR/templates"
ROLES_DIR="$TPL/roles"
INDEX="$ROLES_DIR/index.txt"

[ -f "$TPL/core.md" ] || die "Missing $TPL/core.md - is this a complete checkout?"
[ -f "$INDEX" ]       || die "Missing $INDEX - is this a complete checkout?"

VERSION="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/VERSION" 2>/dev/null)"
[ -n "$VERSION" ] || VERSION="unknown"

DSH_DIR="${DSH_HOME:-$HOME/.dsh}"
TARGET="$DSH_DIR/AGENTS.md"

# The stamp is how the settings are remembered, so there is no extra state file
# in ~/.dsh - a directory that otherwise holds credentials. Roles stay last in
# the line so their pattern can anchor on the closing "-->".
STAMP_PREFIX="<!-- dsh-setup:"
DEFAULT_LANG="English"
# agents.bat writes this line with CRLF. Without the tr the trailing CR sits
# after the "-->" and the roles pattern below stops anchoring, so a machine that
# ran agents.bat once would silently lose its remembered roles here.
stamp_of() {
  head -n1 "$1" | tr -d '\r'
}
roles_of() {
  [ -f "$1" ] || return 0
  stamp_of "$1" | sed -n 's/^<!-- dsh-setup:.*roles: *\([^ ]*\) *-->$/\1/p'
}
lang_of() {
  [ -f "$1" ] || return 0
  stamp_of "$1" | sed -n 's/^<!-- dsh-setup:.*lang: \(.*\) | roles:.*/\1/p'
}

# ---------- available roles ----------
SLUGS=(); DESCS=()
while IFS='|' read -r slug desc; do
  # tolerate a CRLF index.txt - it is a plain text file people may edit on Windows
  slug="${slug%$'\r'}"; desc="${desc%$'\r'}"
  case "$slug" in ''|\#*) continue ;; esac
  [ -f "$ROLES_DIR/$slug.md" ] || { warn "index.txt lists '$slug' but $slug.md is missing - skipping"; continue; }
  SLUGS+=("$slug"); DESCS+=("$desc")
done < "$INDEX"
[ ${#SLUGS[@]} -gt 0 ] || die "No usable roles found in $INDEX"

is_role() { local n="$1" s; for s in "${SLUGS[@]}"; do [ "$s" = "$n" ] && return 0; done; return 1; }

# ---------- arguments ----------
REQUESTED=""; HAVE_REQUEST=0; SHOW=0; LANG_ARG=""; HAVE_LANG=0; NO_ASK=0
for arg in "$@"; do
  case "$arg" in
    --role=*)  REQUESTED="${arg#--role=}"; HAVE_REQUEST=1 ;;
    --lang=*)  LANG_ARG="${arg#--lang=}"; HAVE_LANG=1 ;;
    --show)    SHOW=1 ;;
    --no-ask)  NO_ASK=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         die "Unknown argument: $arg   (try --help)" ;;
  esac
done

# The language goes into the stamp line, so it must not contain the separators
# that line is parsed with.
case "$LANG_ARG" in
  *'|'*|*'-->'*) die "--lang cannot contain '|' or '-->'" ;;
esac

if [ "$SHOW" -eq 1 ]; then
  say ""
  say "  target : $TARGET"
  if [ -f "$TARGET" ]; then
    CUR="$(roles_of "$TARGET")"
    say "  roles  : ${CUR:-none (core only)}"
    say "  lang   : $(lang_of "$TARGET")"
    say "  stamp  : $(head -n1 "$TARGET")"
    say "  size   : $(wc -c < "$TARGET" | tr -d ' ') bytes"
  else
    say "  roles  : - (not written yet)"
  fi
  say "  offered: $(IFS=,; echo "${SLUGS[*]}")"
  [ -f "$SCRIPT_DIR/local.md" ] && say "  local  : local.md is appended ($(wc -c < "$SCRIPT_DIR/local.md" | tr -d ' ') bytes)"
  say ""
  exit 0
fi

# ---------- decide the language ----------
if [ "$HAVE_LANG" -eq 0 ]; then
  LANG_ARG="$(lang_of "$TARGET")"
  [ -z "$LANG_ARG" ] && LANG_ARG="$DEFAULT_LANG"
fi

# ---------- decide the roles ----------
if [ "$HAVE_REQUEST" -eq 0 ]; then
  REMEMBERED="$(roles_of "$TARGET")"
  if [ -f "$TARGET" ] && [ -n "$(head -n1 "$TARGET" | grep -F "$STAMP_PREFIX")" ]; then
    REQUESTED="$REMEMBERED"                      # regenerate as before
    info "Using the roles already set on this machine: ${REQUESTED:-none}"
  elif [ "$NO_ASK" -eq 1 ]; then
    # Roles are optional, and an update is not the moment to stop and ask.
    REQUESTED=""
    info "No roles set on this machine - writing the core rules only."
    info "Add role blocks any time: ./agents.sh --role=$(IFS=,; echo "${SLUGS[*]}")"
  elif [ -t 0 ]; then
    say ""
    say "  ${BOLD}Which kinds of work happen on this machine?${OFF} ${DIM}(optional)${OFF}"
    say "  ${DIM}This picks which rule blocks get loaded. Nothing else changes.${OFF}"
    say "  ${DIM}Change it any time with ./agents.sh --role=...${OFF}"
    say ""
    i=1
    for idx in "${!SLUGS[@]}"; do
      printf '    %d) %-16s %s%s%s\n' "$i" "${SLUGS[$idx]}" "$DIM" "${DESCS[$idx]}" "$OFF"
      i=$((i+1))
    done
    say ""
    printf '  Numbers, separated by spaces - or Enter to skip: '
    read -r PICKED
    SEL=""
    for n in $PICKED; do
      case "$n" in
        ''|*[!0-9]*) warn "Ignoring '$n' - not a number"; continue ;;
      esac
      if [ "$n" -ge 1 ] && [ "$n" -le "${#SLUGS[@]}" ]; then
        SEL="$SEL,${SLUGS[$((n-1))]}"
      else
        warn "Ignoring '$n' - out of range"
      fi
    done
    REQUESTED="${SEL#,}"
    say ""
  else
    die "No roles set yet and this is not an interactive terminal.
       Pass them explicitly, for example:
         ./agents.sh --role=figma,design-to-code
         ./agents.sh --role=none
       Available: $(IFS=,; echo "${SLUGS[*]}")"
  fi
fi

[ "$REQUESTED" = "none" ] && REQUESTED=""

CHOSEN=()
OLDIFS="$IFS"; IFS=','
for r in $REQUESTED; do
  IFS="$OLDIFS"
  r="$(printf '%s' "$r" | tr -d ' ')"
  [ -z "$r" ] && continue
  is_role "$r" || die "Unknown role: $r
       Available: $(IFS=,; echo "${SLUGS[*]}")"
  # ignore a repeat rather than emitting the block twice
  dup=0; for c in ${CHOSEN[@]+"${CHOSEN[@]}"}; do [ "$c" = "$r" ] && dup=1; done
  [ "$dup" -eq 0 ] && CHOSEN+=("$r")
  IFS=','
done
IFS="$OLDIFS"

ROLE_LIST="$(IFS=,; echo "${CHOSEN[*]+${CHOSEN[*]}}")"

# ---------- protect anything we did not write ----------
mkdir -p "$DSH_DIR" || die "Cannot create $DSH_DIR"
if [ -f "$TARGET" ] && ! head -n1 "$TARGET" | grep -qF "$STAMP_PREFIX"; then
  cp "$TARGET" "$TARGET.bak" || die "Cannot back up $TARGET"
  warn "$TARGET was not written by this script - saved a copy as AGENTS.md.bak"
fi

# ---------- assemble ----------
TMP="$TARGET.tmp.$$"
{
  printf '<!-- dsh-setup: v%s | lang: %s | roles: %s -->\n' "$VERSION" "$LANG_ARG" "$ROLE_LIST"
  printf '<!-- Generated by dsh-setup. Edits here are overwritten on the next\n'
  printf '     update. Project rules go in that project'"'"'s own AGENTS.md; machine-\n'
  printf '     specific rules go in local.md in your dsh-setup checkout. -->\n\n'
  # The scripts own the document skeleton so the language rule can be a setting;
  # core.md picks up from "Be direct" inside this same section.
  printf '# Agent Instructions\n\n'
  printf 'Rules for any agent working with me, on any project on this machine.\n\n'
  printf "Project-specific rules live in that project's own \`AGENTS.md\`, and take\n"
  printf 'precedence over anything here.\n\n'
  printf '## Communication\n\n'
  printf 'Reply in %s. Write code, comments, commit messages, variable names, and\n' "$LANG_ARG"
  printf 'file names in English.\n\n'
  cat "$TPL/core.md"
  for r in ${CHOSEN[@]+"${CHOSEN[@]}"}; do
    printf '\n---\n\n'
    cat "$ROLES_DIR/$r.md"
  done
  # Appended verbatim and never parsed: this is the one place a user's own
  # machine-specific rules survive an update.
  if [ -f "$SCRIPT_DIR/local.md" ]; then
    printf '\n---\n\n'
    sed 's/\r$//' "$SCRIPT_DIR/local.md"   # tolerate a CRLF local.md on Windows
  fi
} > "$TMP" || { rm -f "$TMP"; die "Cannot write to $DSH_DIR"; }

CHANGED=1
if [ -f "$TARGET" ] && cmp -s "$TMP" "$TARGET"; then CHANGED=0; fi
mv -f "$TMP" "$TARGET" || { rm -f "$TMP"; die "Cannot replace $TARGET"; }

BYTES="$(wc -c < "$TARGET" | tr -d ' ')"
if [ "$CHANGED" -eq 0 ]; then
  ok "$TARGET already current (${ROLE_LIST:-core only}, $BYTES bytes)"
else
  ok "Wrote $TARGET (${ROLE_LIST:-core only}, $BYTES bytes)"
  info "Reply language: $LANG_ARG"
  # dsh's default budget for the whole rendered instruction baseline.
  [ "$BYTES" -gt 65536 ] && warn "That is over dsh's default 65536-byte instruction budget - it will be truncated."
  info "Rules reach only a session started AFTER this. Restart any open dsh session."
fi
