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
#   bash install-project.sh <project-path> --update     # update-only: refresh installed items that changed in this repo
#   bash install-project.sh <project-path> --models     # re-open the per-stage model picker
#   bash install-project.sh <project-path> --graphify   # set up Graphify knowledge graph (token saver, needs graphify CLI)
#   bash install-project.sh --list                      # list available items
#
# Updates: installed copies are never silently overwritten. Every run ends
# with an update check that compares the project's installed items against
# this repo's versions; differing items are listed and (interactively)
# offered for update. --update runs ONLY that check and refreshes all
# differing items without asking -- the intended flow after pulling new
# versions of this repo. Updating overwrites local edits to those files,
# so commit the project's .claude/ first.
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
# worklog + commit are in both presets: they carry the model-routing relay
# (plan on Fable -> execute on the session model writing .claude/worklog.md
# -> review-code on Fable reads only that scope -> commit on sonnet).
LEAN_SKILLS="ponytail ponytail-review worklog"
LEAN_COMMANDS="grill plan dispatch merge review-code commit save-session"
STRICT_SKILLS="tdd-workflow verification-loop worklog"
STRICT_COMMANDS="grill plan dispatch merge tdd verify review-code commit save-session"
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
    echo "Usage: bash install-project.sh <project-path> [--lean|--strict|--all] [--writing] [--taskmaster] [--rules lang1,lang2 | --no-rules] [--models] [--update] [--skills a,b] [--commands x,y] [--agents m,n] [--output-styles p,q]"
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
UPDATE_ONLY=false
MODEL_PICK=false
FORCE_MODELS=false
GRAPHIFY=false
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
        --update) UPDATE_ONLY=true ;;
        --models) FORCE_MODELS=true ;;
        --graphify) GRAPHIFY=true ;;
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
elif [ "$UPDATE_ONLY" = true ]; then
    # Update-only mode: install nothing new, just run the update check below.
    echo "[update-only] checking installed items against the repo..."
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
    # A freshly copied model-routed command means this is (part of) a first
    # install -- offer the model picker below.
    case "$kind/$name" in
        commands/plan|commands/review-code|commands/commit) MODEL_PICK=true ;;
    esac
}

for c in $COMMANDS; do install_md commands "$c"; done
for a in $AGENTS; do install_md agents "$a"; done
for o in $STYLES; do install_md output-styles "$o"; done

# --------------------------------------------------------------- models ----
# First-install model picker: probe whether claude-fable-5 is usable, then
# ask which model each stage should run on. Choices are written into THIS
# project's command copies (and optionally .claude/settings.json), so every
# project can route differently. Re-runs skip it (files already existed);
# re-open it any time with --models. Non-interactive runs keep the repo
# defaults (plan/review: claude-fable-5, commit: sonnet).

probe_fable() {
    command -v claude >/dev/null 2>&1 || return 2
    if command -v timeout >/dev/null 2>&1; then
        timeout 45 claude --model claude-fable-5 -p "ok" >/dev/null 2>&1
    else
        claude --model claude-fable-5 -p "ok" >/dev/null 2>&1
    fi
}

model_from_choice() { # $1=answer $2=default
    case "$1" in
        "") echo "$2" ;;
        1)  echo "claude-fable-5" ;;
        2)  echo "opus" ;;
        3)  echo "sonnet" ;;
        4)  echo "haiku" ;;
        *)  echo "$1" ;;
    esac
}

set_cmd_model() { # $1=command basename $2=model
    local f="$DEST/commands/$1.md"
    [ -f "$f" ] || return 0
    if grep -q '^model: ' "$f"; then
        sed -i "s/^model: .*/model: $2/" "$f"
        echo "  [model] commands/$1 -> $2"
    else
        echo "  [note] commands/$1.md has no model: line -- edit it manually"
    fi
}

if [ "$UPDATE_ONLY" != true ] && [ -t 0 ] && { [ "$MODEL_PICK" = true ] || [ "$FORCE_MODELS" = true ]; }; then
    echo ""
    echo "[models] Per-stage model routing for this project."
    printf "  Probing claude-fable-5 availability (one tiny API call via claude CLI)... "
    if probe_fable; then
        FABLE_ST="available"
    elif [ $? -eq 2 ]; then
        FABLE_ST="unknown (claude CLI not found; cannot verify)"
    else
        FABLE_ST="NOT available"
    fi
    echo "$FABLE_ST"
    DEF_PLAN="claude-fable-5"
    DEF_REVIEW="claude-fable-5"
    DEF_COMMIT="sonnet"
    if [ "$FABLE_ST" = "NOT available" ]; then
        DEF_PLAN="opus"
        DEF_REVIEW="opus"
        echo "  Falling back: plan/review defaults changed to opus."
    fi
    echo "  Choices: 1=claude-fable-5  2=opus  3=sonnet  4=haiku"
    echo "  (Enter keeps the default; you can also type a full model id)"
    printf "  plan    - /plan strategic planning     [default: %s]: " "$DEF_PLAN"
    read -r a || a=""
    M_PLAN="$(model_from_choice "$a" "$DEF_PLAN")"
    printf "  review  - /review-code code review     [default: %s]: " "$DEF_REVIEW"
    read -r a || a=""
    M_REVIEW="$(model_from_choice "$a" "$DEF_REVIEW")"
    printf "  commit  - /commit mechanical finish    [default: %s]: " "$DEF_COMMIT"
    read -r a || a=""
    M_COMMIT="$(model_from_choice "$a" "$DEF_COMMIT")"
    printf "  execute - main-loop model              [Enter=keep global setting]: "
    read -r a || a=""
    M_EXEC="$(model_from_choice "$a" "")"

    set_cmd_model plan "$M_PLAN"
    set_cmd_model review-code "$M_REVIEW"
    set_cmd_model commit "$M_COMMIT"
    if [ -n "$M_EXEC" ]; then
        SET_FILE="$DEST/settings.json"
        if [ ! -f "$SET_FILE" ]; then
            printf '{\n  "model": "%s"\n}\n' "$M_EXEC" > "$SET_FILE"
            echo "  [model] settings.json (created) -> $M_EXEC"
        elif grep -q '"model"' "$SET_FILE"; then
            sed -i "s/\"model\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"model\": \"$M_EXEC\"/" "$SET_FILE"
            echo "  [model] settings.json -> $M_EXEC"
        else
            echo "  [note] settings.json exists without a model key -- add \"model\": \"$M_EXEC\" manually"
        fi
    fi
fi

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
elif [ "$NO_RULES" != true ] && [ "$UPDATE_ONLY" != true ] && [ -t 0 ]; then
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

# ------------------------------------------------------------- graphify ----
# Optional token saver: Graphify (github.com/Graphify-Labs/graphify) parses
# the codebase locally (tree-sitter AST, no API calls) into a queryable
# knowledge graph, so the assistant follows graph edges to the relevant
# files instead of reading broadly. Worth it on larger projects (roughly
# 500+ files); on small ones the graph build costs more than it saves.
# We only orchestrate graphify's own installer -- the skill it creates
# (.claude/skills/graphify) belongs to the graphify CLI and is deliberately
# ignored by this repo's cleanup and update mechanisms.

# Full wiring is three layers -- the skill alone does NOT make the
# assistant use the graph:
#   1. skill      (graphify install --project)  -> manual /graphify commands
#   2. graph-first (graphify claude install)    -> CLAUDE.md instructions +
#      PreToolUse hook that nudges search-style tool calls toward the graph;
#      without this layer the assistant keeps reading files the old way
#   3. auto-rebuild (graphify hook install)     -> git post-commit/checkout
#      hooks re-extract only changed files, so the graph stays fresh
#      without manual rebuilds
install_graphify() {
    if ! command -v graphify >/dev/null 2>&1; then
        echo "  [skip] graphify CLI not found. Install it first:"
        echo "         uv tool install graphifyy    (or: pipx install graphifyy)"
        echo "         then re-run: blackcat --graphify"
        return 0
    fi
    echo "  [1/3] skill: graphify install --project"
    if (cd "$TARGET" && graphify install --project --platform claude >/dev/null 2>&1) \
       || (cd "$TARGET" && graphify install --project >/dev/null 2>&1); then
        echo "        [ok]"
    else
        echo "        [error] run manually inside the project: graphify install --project"
    fi
    echo "  [2/3] graph-first nudge: graphify claude install"
    if (cd "$TARGET" && graphify claude install >/dev/null 2>&1); then
        echo "        [ok] CLAUDE.md instructions + PreToolUse hook wired"
    else
        echo "        [error] run manually inside the project: graphify claude install"
        echo "                (without this the assistant will NOT use the graph automatically)"
    fi
    echo "  [3/3] auto-rebuild on commit: graphify hook install"
    if (cd "$TARGET" && graphify hook install >/dev/null 2>&1); then
        echo "        [ok] git hooks installed -- graph re-extracts changed files on commit"
    else
        echo "        [error] run manually inside the project: graphify hook install"
        echo "                (until then, refresh after changes with: graphify update .)"
    fi
    echo "  Build the graph once from inside Claude Code with: /graphify ."
}

if [ "$UPDATE_ONLY" != true ]; then
    if [ "$GRAPHIFY" = true ]; then
        echo ""
        echo "[graphify]"
        install_graphify
    elif [ -t 0 ] && [ "$MODEL_PICK" = true ] && [ ! -d "$DEST/skills/graphify" ]; then
        echo ""
        echo "[graphify] Optional: index this codebase into a local knowledge graph so"
        echo "           Claude navigates via graph queries instead of reading files"
        echo "           broadly (big token savings on larger projects, ~500+ files;"
        echo "           NOT worth it on small ones)."
        printf "Set up Graphify for this project? [y/N] "
        read -r ans || ans=""
        case "$ans" in
            y|Y|yes|YES) install_graphify ;;
            *) ;;
        esac
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

# --------------------------------------------------------------- update ----
# Installed copies are never silently overwritten ([keep] above). Compare
# every installed item against this repo's version and offer to refresh the
# ones that differ. --update refreshes all of them without asking.

UPDATE_LIST=""

for kind in skills rules; do
    for d in "$DEST/$kind"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        src="$SCRIPT_DIR/$kind/$name"
        [ -d "$src" ] || continue
        diff -rq "$src" "$d" >/dev/null 2>&1 || UPDATE_LIST="$UPDATE_LIST $kind/$name"
    done
done
for kind in commands agents output-styles; do
    for f in "$DEST/$kind"/*.md; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        src="$SCRIPT_DIR/$kind/$name"
        [ -f "$src" ] || continue
        # The frontmatter model line is a per-project choice (see the model
        # picker above) -- a difference there alone is not an update.
        cmp -s <(grep -v '^model: ' "$src") <(grep -v '^model: ' "$f") \
            || UPDATE_LIST="$UPDATE_LIST $kind/$name"
    done
done

do_update() {
    local src="$SCRIPT_DIR/$1" dst="$DEST/$1"
    if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
    else
        # Preserve the project's chosen frontmatter model across updates.
        local keep_model=""
        [ -f "$dst" ] && keep_model="$(grep -m1 '^model: ' "$dst" || true)"
        cp "$src" "$dst"
        if [ -n "$keep_model" ] && grep -q '^model: ' "$dst"; then
            sed -i "s/^model: .*/$keep_model/" "$dst"
        fi
    fi
    echo "  [update] $1"
    case "$1" in rules/*)
        echo "           (if this set gained NEW files, add their @-import lines to CLAUDE.md manually)" ;;
    esac
}

if [ -z "$UPDATE_LIST" ]; then
    [ "$UPDATE_ONLY" = true ] && echo "[update] everything is up to date with the repo"
else
    echo ""
    echo "[update] these installed items differ from the repo versions:"
    i=1
    upd_opts=""
    for item in $UPDATE_LIST; do
        printf "  %d) %s\n" "$i" "$item"
        upd_opts="$upd_opts $i:$item"
        i=$((i+1))
    done
    if [ "$UPDATE_ONLY" = true ]; then
        for item in $UPDATE_LIST; do do_update "$item"; done
    elif [ -t 0 ]; then
        echo "Updating OVERWRITES local edits to these files (commit the project's .claude/ first)."
        printf "Update which? (a for all, Enter for none, numbers to pick): "
        read -r sel || sel=""
        if [ "$sel" = "a" ] || [ "$sel" = "A" ]; then
            for item in $UPDATE_LIST; do do_update "$item"; done
        else
            for n in $sel; do
                for pair in $upd_opts; do
                    [ "${pair%%:*}" = "$n" ] && do_update "${pair#*:}"
                done
            done
        fi
    else
        echo "  (non-interactive run -- refresh them with: blackcat --update)"
    fi
fi

echo ""
echo "[done] Consider committing the project's .claude/ to its git repo."
echo "       To customize, edit the files inside the project directly."
