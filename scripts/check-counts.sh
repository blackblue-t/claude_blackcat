#!/bin/bash
# Consistency check for this repo: README counts, preset names in the
# installer, items README never mentions, ui-library catalog, and ASCII-only
# installer scripts. Run after adding/removing a skill, command, agent,
# output style or ui-library style. Exit 1 when anything is out of sync.
#
# Usage: bash scripts/check-counts.sh

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
FAIL=0
bad() { echo "  [x] $*"; FAIL=1; }
ok()  { echo "  [ok] $*"; }

count_dirs()  { ls -d "$1"/*/ 2>/dev/null | wc -l | tr -d ' '; }
count_md()    { ls "$1"/*.md 2>/dev/null | grep -vc '/README\.md$'; }
readme_num()  { grep -m1 "$1" README.md | grep -o '[0-9]\+' | head -1; }
readme_num2() { grep -m1 "$1" README.md | grep -o '[0-9]\+' | sed -n 2p; }

echo "[counts] README headings vs files"
check() { # $1=label $2=actual $3=readme value
    if [ -z "$3" ]; then bad "$1: heading not found in README"
    elif [ "$2" != "$3" ]; then bad "$1: README says $3, repo has $2"
    else ok "$1: $2"; fi
}
check skills        "$(count_dirs skills)"   "$(readme_num '^## Skills')"
check commands      "$(count_md commands)"   "$(readme_num '^## Commands')"
check agents        "$(count_md agents)"     "$(readme_num '^## Agents')"
check output-styles "$(count_md output-styles)" "$(readme_num2 '^## Agents')"

echo "[mentions] every item named somewhere in README"
for d in skills/*/; do n="$(basename "$d")"; grep -qF "$n" README.md || bad "skill $n not in README"; done
for kind in commands agents output-styles; do
    for f in "$kind"/*.md; do
        n="$(basename "$f" .md)"; [ "$n" = README ] && continue
        grep -qF "$n" README.md || bad "${kind%s} $n not in README"
    done
done

echo "[presets] names in install-project.sh exist"
for var in LEAN_SKILLS STRICT_SKILLS WRITING_SKILLS UI_SKILLS PM_SKILLS; do
    for n in $(grep -m1 "^$var=" install-project.sh | sed 's/^[^"]*"//; s/".*//'); do
        [ -d "skills/$n" ] || bad "$var: skills/$n missing"
    done
done
for var in LEAN_COMMANDS STRICT_COMMANDS UI_COMMANDS PM_COMMANDS; do
    for n in $(grep -m1 "^$var=" install-project.sh | sed 's/^[^"]*"//; s/".*//'); do
        [ -f "commands/$n.md" ] || bad "$var: commands/$n.md missing"
    done
done
for n in $(grep -m1 '^UI_AGENTS=' install-project.sh | sed 's/^[^"]*"//; s/".*//'); do
    [ -f "agents/$n.md" ] || bad "UI_AGENTS: agents/$n.md missing"
done
for n in $(grep -m1 '^PRESET_STYLES=' install-project.sh | sed 's/^[^"]*"//; s/".*//'); do
    [ -f "output-styles/$n.md" ] || bad "PRESET_STYLES: output-styles/$n.md missing"
done

echo "[ui-library] catalog vs style folders"
if [ -d ui-library ]; then
    styles=0
    for d in ui-library/*/; do
        n="$(basename "$d")"; case "$n" in _*) continue ;; esac
        styles=$((styles+1))
        [ -f "$d/DESIGN.md" ]   || bad "ui-library/$n: no DESIGN.md"
        [ -f "$d/SOURCE.json" ] || bad "ui-library/$n: no SOURCE.json"
        grep -qF "**$n**" ui-library/CATALOG.md || bad "ui-library/$n not in CATALOG.md"
    done
    cat_n="$(grep -m1 -o '[0-9]\+' ui-library/CATALOG.md)"
    check ui-library "$styles" "$cat_n"
fi

echo "[ignored] files README or skills point to must be tracked"
for f in scripts/check-counts.sh ui-library/_tools/extract-style.js ui-library/_tools/probe-cli.js; do
    git check-ignore -q "$f" 2>/dev/null && bad "$f is gitignored -- it would be lost on a fresh clone"
done

echo "[ascii] installer scripts (cmd mis-parses UTF-8)"
for f in install.sh install-project.sh install.bat dispatch.sh project-hooks/*.sh scripts/*.sh; do
    [ -f "$f" ] || continue
    if LC_ALL=C grep -q '[^ -~[:space:]]' "$f"; then
        bad "$f has non-ASCII bytes (line $(LC_ALL=C grep -n -m1 '[^ -~[:space:]]' "$f" | cut -d: -f1))"
    fi
done

echo ""
if [ "$FAIL" = 0 ]; then echo "[pass] everything in sync"; else echo "[fail] fix the [x] lines above"; exit 1; fi
