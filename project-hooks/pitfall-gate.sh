#!/bin/bash
# Pitfall gate (PreToolUse: Write|Edit|MultiEdit).
#
# Lessons live in .claude/learned/*.md, each with a frontmatter "files:" list
# of globs. When Claude is about to write a file that matches a lesson, block
# that write ONCE per session and show the lesson; retrying the same edit
# passes. Blocking instead of a non-blocking note is deliberate: a note would
# arrive together with the edit, after the change is already written.
#
# Cost: this runs on every write. With no lessons it exits before reading
# stdin. Escape hatch: PITFALL_GATE=off.

[ "${PITFALL_GATE:-on}" = "off" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
DIR="$ROOT/.claude/learned"
[ -d "$DIR" ] || exit 0
ls "$DIR"/*.md >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
json_str() { # $1=key -> first string value, JSON backslashes turned into /
    printf '%s' "$INPUT" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
        | head -1 | sed 's#\\\\#/#g; s#\\#/#g; s#//*#/#g'
}
TARGET="$(json_str file_path)"
[ -n "$TARGET" ] || exit 0
SID="$(json_str session_id)"
ROOT_N="$(printf '%s' "$ROOT" | sed 's#\\#/#g')"
REL="${TARGET#"$ROOT_N"/}"

fm() { # $1=file $2=key -> scalar frontmatter value
    awk -v k="$2" '
        NR==1 && $0 !~ /^---/ { exit }
        /^---[[:space:]]*$/ { n++; if (n==2) exit; next }
        n==1 && index($0, k ":")==1 { sub("^" k ":[[:space:]]*", ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit }
    ' "$1" 2>/dev/null
}
fm_files() { # $1=file -> one glob per line; inline [a, b] and block "- a" both work
    awk '
        NR==1 && $0 !~ /^---/ { exit }
        /^---[[:space:]]*$/ { n++; if (n==2) exit; next }
        n==1 && index($0, "files:")==1 { r=$0; sub(/^files:[[:space:]]*/, "", r); if (r!="") print r; else l=1; next }
        n==1 && l && /^[[:space:]]*-/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); print; next }
        n==1 && l && /^[^[:space:]-]/ { l=0 }
    ' "$1" 2>/dev/null | tr ',' '\n' | tr -d '[]"\047' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

SEEN="$ROOT/.claude/.pitfall-seen"
HITS=""
# Patterns are read line by line and only used in case statements, which do
# pattern matching but never pathname expansion, so no set -f is needed.
for f in "$DIR"/*.md; do
    base="${f##*/}"
    case "$base" in _*|README.md) continue ;; esac
    hit=0
    while IFS= read -r pat; do
        [ -n "$pat" ] || continue
        case "$REL" in $pat) hit=1 ;; esac
        case "$TARGET" in */$pat) hit=1 ;; esac
        [ "$hit" = 1 ] && break
    done <<EOF
$(fm_files "$f")
EOF
    [ "$hit" = 1 ] || continue
    grep -qxF "$SID|$REL|$base" "$SEEN" 2>/dev/null && continue
    printf '%s|%s|%s\n' "$SID" "$REL" "$base" >> "$SEEN" 2>/dev/null
    HITS="$HITS
- [$(fm "$f" severity)] $(fm "$f" title)
  symptom: $(fm "$f" symptom)
  root cause: $(fm "$f" root-cause)
  how to avoid: $(fm "$f" guard)
  full note: .claude/learned/$base"
done

[ -n "$HITS" ] || exit 0
cat >&2 <<EOF
This file has a recorded pitfall. Read it before changing $REL:
$HITS

Check your edit does not repeat the mistake, then retry the same edit; it
will pass (one block per file per session). If a lesson is outdated, update
or delete its file in .claude/learned/ instead of working around the gate.
EOF
exit 2
