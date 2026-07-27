#!/bin/bash

# claude_blackcat project installer
# COPIES selected skills / commands / agents / output-styles into a target
# project's .claude/ directory. Copy, not symlink: once installed the files
# belong to the project and can be customized freely (mattpocock-style).
#
# Usage:
#   bash install-project.sh <project-path> --lean       # fast iteration: ponytail (YAGNI minimal)
#   bash install-project.sh <project-path> --strict     # production: tdd-workflow + verification-loop
#   bash install-project.sh <project-path> --writing    # add writing pack: speak-human-tw + humanizer (stacks on any preset)
#   bash install-project.sh <project-path> --all        # install everything
#   bash install-project.sh <project-path> --skills a,b --commands x,y --agents m,n
#   bash install-project.sh <project-path> --rules python    # coding rules (common + language sets)
#   bash install-project.sh <project-path> --taskmaster # add TaskMaster workflow (project-template)
#   bash install-project.sh --list                      # list available items
#
# --rules copies rule files into <project>/.claude/rules/ AND writes a marked
# @-import block into the project's CLAUDE.md. Claude Code does NOT auto-load
# rules directories -- files only reach the system prompt when CLAUDE.md
# imports them, so the import block is what actually wires them up.
#
# When run interactively WITHOUT --rules, an interactive picker offers the
# rule sets (with a one-line description each) after the main install.
# Pass --no-rules to suppress the picker; non-interactive runs (no TTY on
# stdin) skip it automatically.
#
# Default preset (no flags) is --lean.
# lean and strict are intentionally exclusive: ponytail ("one minimal check
# is enough") and tdd-workflow ("test-first, 80%+ coverage") both trigger on
# every coding task and give the model contradictory instructions when
# installed together. To mix them anyway, pass --skills explicitly.

set -e

# When bash.exe is launched directly (non-login, e.g. via the blackcat.cmd
# shim), Git Bash does not put /usr/bin on PATH, so coreutils like dirname,
# cp and sed are all missing. Re-add them here using bash builtins only --
# this must run before any external command.
for _d in /usr/bin /mingw64/bin /bin; do
    if [ -d "$_d" ]; then
        case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH" ;; esac
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# preset bundles
LEAN_SKILLS="ponytail ponytail-review"
LEAN_COMMANDS="plan review-code save-session"
STRICT_SKILLS="tdd-workflow verification-loop"
STRICT_COMMANDS="plan tdd verify review-code save-session"
WRITING_SKILLS="speak-human-tw humanizer"

list_items() {
    local kind
    for kind in skills commands agents output-styles; do
        echo "-- $kind --"
        if [ "$kind" = "skills" ]; then
            ls "$SCRIPT_DIR/$kind"
        else
            ls "$SCRIPT_DIR/$kind" | sed 's/\.md$//'
        fi
        echo ""
    done
    echo "-- rules (via --rules; common always included) --"
    ls "$SCRIPT_DIR/rules" | grep -v 'README' | grep -v '^common$'
    echo ""
    echo "-- extras --"
    echo "--taskmaster  (project-template: TaskMaster hooks + settings + coordination)"
}

if [ "$1" = "--list" ] || [ -z "$1" ]; then
    echo "Usage: bash install-project.sh <project-path> [--lean|--strict|--all] [--writing] [--taskmaster] [--rules lang1,lang2 | --no-rules] [--skills a,b] [--commands x,y] [--agents m,n] [--output-styles p,q]"
    echo ""
    echo "  --lean     fast-iteration preset: $LEAN_SKILLS (default)"
    echo "  --strict   production preset:     $STRICT_SKILLS"
    echo "  --writing  writing pack (stacks): $WRITING_SKILLS"
    echo ""
    list_items
    exit 0
fi

TARGET="$1"; shift
if [ ! -d "$TARGET" ]; then
    echo "[error] project path does not exist: $TARGET"
    exit 1
fi
DEST="$TARGET/.claude"

ALL=false
TASKMASTER=false
WRITING=false
RULES=""
NO_RULES=false
PRESET="lean"
SKILLS=""
COMMANDS=""
AGENTS=""
STYLES=""

while [ $# -gt 0 ]; do
    case "$1" in
        --all) ALL=true ;;
        --lean) PRESET="lean" ;;
        --strict) PRESET="strict" ;;
        --writing) WRITING=true ;;
        --taskmaster) TASKMASTER=true ;;
        --rules) RULES="${2//,/ }"; shift ;;
        --no-rules) NO_RULES=true ;;
        --skills) SKILLS="${2//,/ }"; shift ;;
        --commands) COMMANDS="${2//,/ }"; shift ;;
        --agents) AGENTS="${2//,/ }"; shift ;;
        --output-styles) STYLES="${2//,/ }"; shift ;;
        *) echo "[error] unknown option: $1"; exit 1 ;;
    esac
    shift
done

if [ "$ALL" = true ]; then
    SKILLS=$(ls "$SCRIPT_DIR/skills")
    COMMANDS=$(ls "$SCRIPT_DIR/commands" | sed 's/\.md$//')
    AGENTS=$(ls "$SCRIPT_DIR/agents" | sed 's/\.md$//')
    STYLES=$(ls "$SCRIPT_DIR/output-styles" | grep '\.md$' | sed 's/\.md$//')
else
    # Anything not explicitly given via --skills/--commands falls back to the preset.
    if [ -z "$SKILLS" ]; then
        [ "$PRESET" = "strict" ] && SKILLS="$STRICT_SKILLS" || SKILLS="$LEAN_SKILLS"
    fi
    if [ -z "$COMMANDS" ]; then
        [ "$PRESET" = "strict" ] && COMMANDS="$STRICT_COMMANDS" || COMMANDS="$LEAN_COMMANDS"
    fi
    echo "[preset] $PRESET"
fi

if [ "$WRITING" = true ] && [ "$ALL" != true ]; then
    SKILLS="$SKILLS $WRITING_SKILLS"
    echo "[writing] adding: $WRITING_SKILLS"
fi

mkdir -p "$DEST"
echo "[target] $DEST"

# Skill directories are copied whole; existing ones are kept untouched
# (the project may have customized them).
for s in $SKILLS; do
    src="$SCRIPT_DIR/skills/$s"
    if [ ! -d "$src" ]; then echo "  [skip] skills/$s (not found)"; continue; fi
    if [ -d "$DEST/skills/$s" ]; then echo "  [keep] skills/$s (already exists)"; continue; fi
    mkdir -p "$DEST/skills"
    cp -r "$src" "$DEST/skills/$s"
    echo "  [copy] skills/$s"
done

install_md() {
    local kind="$1" name="$2"
    local src="$SCRIPT_DIR/$kind/$name.md"
    if [ ! -f "$src" ]; then echo "  [skip] $kind/$name (not found)"; return; fi
    if [ -f "$DEST/$kind/$name.md" ]; then echo "  [keep] $kind/$name (already exists)"; return; fi
    mkdir -p "$DEST/$kind"
    cp "$src" "$DEST/$kind/$name.md"
    echo "  [copy] $kind/$name"
}

for c in $COMMANDS; do install_md commands "$c"; done
for a in $AGENTS; do install_md agents "$a"; done
for o in $STYLES; do install_md output-styles "$o"; done

# ---------------------------------------------------------------- rules ----
# Claude Code does not auto-load rules directories. Rule files only reach
# the system prompt if the project's CLAUDE.md @-imports them, so the final
# step below appends a marked import block (idempotent via the marker;
# existing CLAUDE.md content is never modified).

COMMON_ALL="agents coding-style development-workflow git-workflow hooks patterns performance security testing"

rule_desc() {
    case "$1" in
        agents)               echo "when/how to design subagents and delegate work" ;;
        coding-style)         echo "naming, function size, immutability defaults" ;;
        development-workflow) echo "plan -> implement -> verify working loop" ;;
        git-workflow)         echo "branching, commit messages, PR conventions" ;;
        hooks)                echo "auto-run formatters/linters via PostToolUse hooks" ;;
        patterns)             echo "preferred design patterns and anti-patterns" ;;
        performance)          echo "measure-before-optimize guidelines" ;;
        security)             echo "secrets, input validation, dependency hygiene" ;;
        testing)              echo "test structure and coverage expectations" ;;
        python)               echo "Python set: style/testing/patterns/hooks/security" ;;
        rust)                 echo "Rust set: style/testing/patterns/hooks/security" ;;
        typescript)           echo "TypeScript/JS set: style/testing/patterns/hooks/security" ;;
        *)                    echo "" ;;
    esac
}

LANG_SETS=""
COMMON_SEL=""

if [ -n "$RULES" ]; then
    # Explicit --rules keeps the original behavior: all common rules plus
    # every named language set.
    COMMON_SEL="$COMMON_ALL"
    for r in $RULES; do
        [ "$r" = "common" ] && continue
        LANG_SETS="$LANG_SETS $r"
    done
elif [ "$NO_RULES" != true ] && [ -t 0 ]; then
    # Interactive picker: only when stdin is a terminal.
    echo ""
    echo "[rules] Coding rules can be @-imported into this project's CLAUDE.md."
    echo "        Each imported file costs context every session -- pick only what you need."
    printf "Add coding rules to CLAUDE.md? [y/N] "
    read -r ans || ans=""
    case "$ans" in
        y|Y|yes|YES)
            echo ""
            echo "Language sets (a set imports all 5 of its files):"
            i=1
            lang_opts=""
            for l in $(ls "$SCRIPT_DIR/rules"); do
                [ "$l" = "common" ] && continue
                [ -d "$SCRIPT_DIR/rules/$l" ] || continue
                printf "  %d) %-12s %s\n" "$i" "$l" "$(rule_desc "$l")"
                lang_opts="$lang_opts $i:$l"
                i=$((i+1))
            done
            printf "Select sets (numbers separated by spaces, Enter for none): "
            read -r sel || sel=""
            for n in $sel; do
                for pair in $lang_opts; do
                    [ "${pair%%:*}" = "$n" ] && LANG_SETS="$LANG_SETS ${pair#*:}"
                done
            done

            echo ""
            echo "Common rules (language-agnostic):"
            i=1
            common_opts=""
            for c in $COMMON_ALL; do
                printf "  %d) %-24s %s\n" "$i" "$c.md" "$(rule_desc "$c")"
                common_opts="$common_opts $i:$c"
                i=$((i+1))
            done
            printf "Select common rules (Enter for all, n for none, numbers to pick): "
            read -r sel || sel=""
            if [ -z "$sel" ]; then
                COMMON_SEL="$COMMON_ALL"
            elif [ "$sel" = "n" ] || [ "$sel" = "N" ]; then
                COMMON_SEL=""
            else
                for n in $sel; do
                    for pair in $common_opts; do
                        [ "${pair%%:*}" = "$n" ] && COMMON_SEL="$COMMON_SEL ${pair#*:}"
                    done
                done
            fi
            ;;
        *) ;;
    esac
fi

if [ -n "$LANG_SETS$COMMON_SEL" ]; then
    echo ""
    echo "[rules] installing:${COMMON_SEL:+ common:(${COMMON_SEL# })}${LANG_SETS:+ sets:${LANG_SETS# }}"
    # The common directory is always copied when anything is selected --
    # language files reference ../common/ counterparts. Only the SELECTED
    # files get @-imported, so unselected copies cost zero context.
    for r in common $LANG_SETS; do
        src="$SCRIPT_DIR/rules/$r"
        if [ ! -d "$src" ]; then echo "  [skip] rules/$r (not found)"; continue; fi
        if [ -d "$DEST/rules/$r" ]; then echo "  [keep] rules/$r (already exists)"; continue; fi
        mkdir -p "$DEST/rules"
        cp -r "$src" "$DEST/rules/$r"
        echo "  [copy] rules/$r"
    done
    CMD_FILE="$TARGET/CLAUDE.md"
    MARK="<!-- blackcat:rules -->"
    if [ -f "$CMD_FILE" ] && grep -qF "$MARK" "$CMD_FILE"; then
        echo "  [keep] CLAUDE.md import block (marker already present)"
    else
        {
            [ -f "$CMD_FILE" ] && echo ""
            echo "$MARK"
            echo "<!-- Coding rules installed by claude_blackcat. Claude Code only"
            echo "     loads these because they are @-imported below. To drop a rule,"
            echo "     delete its line; to drop them all, delete this block. -->"
            for c in $COMMON_SEL; do
                [ -f "$DEST/rules/common/$c.md" ] && echo "@.claude/rules/common/$c.md"
            done
            for r in $LANG_SETS; do
                [ -d "$DEST/rules/$r" ] || continue
                for f in "$DEST/rules/$r"/*.md; do
                    [ -f "$f" ] || continue
                    base="${f##*/}"
                    [ "$base" = "README.md" ] && continue
                    echo "@.claude/rules/$r/$base"
                done
            done
        } >> "$CMD_FILE"
        echo "  [add] @-import block -> $CMD_FILE"
    fi
fi

if [ "$TASKMASTER" = true ]; then
    echo ""
    echo "[taskmaster] installing project-template..."
    for item in hooks coordination context taskmaster-data logs; do
        src="$SCRIPT_DIR/project-template/$item"
        [ -d "$src" ] || continue
        if [ -d "$DEST/$item" ]; then echo "  [keep] $item (already exists)"; continue; fi
        cp -r "$src" "$DEST/$item"
        echo "  [copy] $item"
    done
    if [ ! -f "$DEST/settings.json" ]; then
        cp "$SCRIPT_DIR/project-template/settings.json" "$DEST/settings.json"
        echo "  [copy] settings.json"
    else
        echo "  [keep] settings.json (already exists -- merge TaskMaster hooks manually)"
    fi
fi

echo ""
echo "[done] Consider committing the project's .claude/ to its git repo."
echo "       To customize, edit the files inside the project directly."
