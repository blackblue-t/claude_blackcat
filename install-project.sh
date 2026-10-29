#!/bin/bash

# claude_blackcat project installer
# COPIES selected skills / commands / agents / output-styles into a target
# project's .claude/ directory. Copy, not symlink: once installed the files
# belong to the project and can be customized freely.
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
#   bash install-project.sh <project-path> --ui         # frontend pack: style library, /ui-style /ui-site /ui-page
#   bash install-project.sh <project-path> --pm         # project management pack: WBS, time log, package manager
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
LEAN_SKILLS="ponytail ponytail-review worklog session-etiquette"
LEAN_COMMANDS="go grill grill-ui grill-doc plan clean-plan dispatch merge review-code commit learn save-session session"
STRICT_SKILLS="tdd-workflow verification-loop worklog session-etiquette"
STRICT_COMMANDS="go grill grill-ui grill-doc plan clean-plan spec dispatch merge tdd verify review-code commit learn save-session session"

# Items renamed in this repo: "<old> <new>" pairs. When the new one installs,
# the stale old copy is moved to backups so projects do not keep both.
# (/plans and /tidy -> /clean-plan: explicit name, no near-miss with /plan.)
RENAMED_COMMANDS="plans:clean-plan tidy:clean-plan"
WRITING_SKILLS="speak-human-tw humanizer"
# Reply styles: inert until picked with /output-style, so both presets ship them.
PRESET_STYLES="terse plain-language"
UI_COMMANDS="ui-style ui-add ui-site ui-page pm-choose"
UI_AGENTS="ui-builder"
UI_SKILLS="ui-style-compliance package-manager"
PM_COMMANDS="task-init task-add task-next task-status time-log pm-choose"
PM_SKILLS="wbs package-manager"

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
    echo "--ui          (frontend pack: $UI_COMMANDS)"
    echo "--pm          (project management pack: $PM_COMMANDS)"
    echo "--taskmaster  (project-template: TaskMaster hooks + settings + coordination)"
}

show_help() {
    cat <<HELP
blackcat - install the blackcat Claude Code workflow into this project

Usage:  blackcat [options]        (runs on the current folder)
        bash install-project.sh <project-path> [options]

Run with no option = --lean. Re-running is safe: files already in the
project are kept ([keep]); changed ones are offered at the end.

PRESETS (pick one)
  --lean           Fast iteration. Minimal code (ponytail), /go one-stop
                   flow, plan -> build -> review -> commit. (default)
  --strict         Production. Same flow + test-first (/tdd), /verify,
                   /spec. Do not mix with --lean.

ADD-ON PACKS (combine freely)
  --ui             Frontend: pick a style from 104 references (/ui-style),
                   site map (/ui-site), build pages (/ui-page) with
                   screenshot checks.
  --pm             Project management: WBS task list (/task-init,
                   /task-next, /task-status), automatic time log
                   (/time-log), package manager choice (/pm-choose).
  --writing        Writing: remove AI tone from Chinese / English text.

REPLY STYLES (installed with every preset; switch in Claude Code with
/output-style)
  terse            Results and next step only. For when you are rushing.
  plain-language   Conclusion and impact first, technical terms explained
                   in one plain sentence the first time.
  --graphify       Code knowledge graph to save tokens on big projects
                   (needs the graphify CLI).
  --taskmaster     Old TaskMaster hooks. New projects: use --pm instead.

CODING RULES
  --rules python   Add coding rules (common + the language) to CLAUDE.md.
                   Languages: python, typescript, rust (comma separated).
  --no-rules       Do not ask about rules.

MAINTENANCE
  --update         After 'git pull' of blackcat: refresh every installed
                   file that changed. Overwrites local edits, so commit
                   the project's .claude/ first.
  --models         Choose again which model each step uses.
  --ui-refresh     Re-download ui-ux-pro-max (old copy is backed up).
  --usage          How often each skill / command / agent was used here.

PICK ITEMS BY HAND
  --skills a,b  --commands x,y  --agents m,n  --output-styles p,q
  --all            Install everything (not recommended).
  --list           Show every item name you can pick.
  --help, -h       This help.

Parallel tasks (separate tool): bcd --help
Full guide (Chinese): README.md in the blackcat repo.
HELP
}

# --help / --list may come anywhere: the blackcat shim always puts the
# current folder first, so they are rarely the first argument.
for _a in "$@"; do
    case "$_a" in
        -h|--help) show_help; exit 0 ;;
        --list)
            echo "Presets:"
            echo "  --lean     skills: $LEAN_SKILLS"
            echo "  --strict   skills: $STRICT_SKILLS"
            echo "  --writing  skills: $WRITING_SKILLS"
            echo ""
            list_items
            exit 0 ;;
    esac
done
if [ -z "$1" ]; then show_help; exit 0; fi

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
UI=false
UI_REFRESH=false
USAGE_MODE=false
PRESET="lean"

PM=false
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
        --ui) UI=true ;;
        --pm) PM=true ;;
        --ui-refresh) UI_REFRESH=true ;;
        --usage|--skill-freq) USAGE_MODE=true ;;
        --skills) SKILLS="${2//,/ }"; shift ;;
        --commands) COMMANDS="${2//,/ }"; shift ;;
        --agents) AGENTS="${2//,/ }"; shift ;;
        --output-styles) STYLES="${2//,/ }"; shift ;;
        *) echo "[error] unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------- usage ----
# blackcat --usage (alias --skill-freq): count how often each skill /
# command / agent was actually used in this project, by scanning Claude
# Code's own session transcripts (~/.claude/projects/<encoded-path>/*.jsonl).
# Zero runtime cost -- no hooks, purely retroactive analysis.
if [ "$USAGE_MODE" = true ]; then
    PROJ_STORE="$HOME/.claude/projects"
    ENC="$(printf '%s' "$TARGET" | sed 's|[^A-Za-z0-9]|-|g')"
    TDIR="$PROJ_STORE/$ENC"
    if [ ! -d "$TDIR" ]; then
        # fallback: suffix match on the encoded basename
        BASE_ENC="$(basename "$TARGET" | sed 's|[^A-Za-z0-9]|-|g')"
        CAND="$(ls "$PROJ_STORE" 2>/dev/null | grep -- "-$BASE_ENC$" | head -1)"
        [ -n "$CAND" ] && TDIR="$PROJ_STORE/$CAND"
    fi
    N_FILES="$(ls "$TDIR"/*.jsonl 2>/dev/null | wc -l)"
    if [ ! -d "$TDIR" ] || [ "$N_FILES" -eq 0 ]; then
        echo "[usage] no session transcripts found for this project"
        echo "        (looked in $PROJ_STORE/$ENC)"
        exit 0
    fi
    echo "[usage] scanning $N_FILES session transcript(s) in $(basename "$TDIR")"
    # Built-ins are Claude Code's own, not installed by this repo -- counting
    # them together with project items makes the report misleading.
    BUILTIN_CMDS="(clear|compact|resume-session|resume|mcp|model|config|help|cost|status|login|logout|agents|context|export|memory|doctor|fast|loop|vim|terminal-setup|add-dir|permissions|hooks|output-style|statusline|todos|bug|release-notes|upgrade|privacy-settings|exit|quit)"
    BUILTIN_AGENTS="(general-purpose|Explore|Plan|claude|statusline-setup|claude-code-guide|output-style-setup)"
    BUILTIN_SKILLS="(artifact-design|artifact-capabilities|artifact-diagramming|dataviz|skill-creator|pdf|docx|xlsx|pptx|grilling|update-config|simplify|run|morning|init)"

    TMPU="$TDIR/.bc-usage.tmp"
    grep -ho '"skill"[[:space:]]*:[[:space:]]*"[^"]*"' "$TDIR"/*.jsonl 2>/dev/null \
        | sed 's/.*"skill"[[:space:]]*:[[:space:]]*"//;s/"$//' | sort | uniq -c | sort -rn > "$TMPU.sk" || true
    grep -ho '<command-name>[^<]*</command-name>' "$TDIR"/*.jsonl 2>/dev/null \
        | sed 's|<command-name>/\{0,1\}||;s|</command-name>||' | sort | uniq -c | sort -rn > "$TMPU.cm" || true
    grep -ho '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' "$TDIR"/*.jsonl 2>/dev/null \
        | sed 's/.*: *"//;s/"$//' | sort | uniq -c | sort -rn > "$TMPU.ag" || true

    echo ""
    echo "-- YOUR commands (times run) --"
    grep -vE "^ *[0-9]+ $BUILTIN_CMDS\$" "$TMPU.cm" 2>/dev/null \
        | awk 'NF' | grep . || echo "  (none recorded)"
    echo ""
    echo "-- YOUR skills (times the Skill tool fired) --"
    echo "   note: slash commands also dispatch through the Skill tool, so names"
    echo "   matching your commands are command runs, not skill auto-triggers."
    grep -vE "^ *[0-9]+ $BUILTIN_SKILLS\$" "$TMPU.sk" 2>/dev/null \
        | awk 'NF' | grep . || echo "  (none recorded)"
    echo ""
    echo "-- YOUR agents (times dispatched) --"
    grep -vE "^ *[0-9]+ $BUILTIN_AGENTS\$" "$TMPU.ag" 2>/dev/null \
        | awk 'NF' | grep . || echo "  (none -- built-in agents only)"
    echo ""
    echo "-- built-in Claude Code usage (not installed by blackcat) --"
    printf "  commands: "; grep -E "^ *[0-9]+ $BUILTIN_CMDS\$" "$TMPU.cm" 2>/dev/null | awk '{printf "%s(%s) ", $2, $1}'; echo ""
    printf "  agents:   "; grep -E "^ *[0-9]+ $BUILTIN_AGENTS\$" "$TMPU.ag" 2>/dev/null | awk '{printf "%s(%s) ", $2, $1}'; echo ""
    printf "  skills:   "; grep -E "^ *[0-9]+ $BUILTIN_SKILLS\$" "$TMPU.sk" 2>/dev/null | awk '{printf "%s(%s) ", $2, $1}'; echo ""
    rm -f "$TMPU".sk "$TMPU".cm "$TMPU".ag
    echo ""
    echo "-- installed but never seen in these transcripts --"
    UNUSED=0
    # A skill can be used WITHOUT a Skill tool call: some ship a CLI that the
    # model runs via Bash (graphify), or are applied by following CLAUDE.md
    # instructions. Count a skill as used if its name appears in a Skill call
    # OR anywhere in a Bash command, so we do not report false negatives.
    for d in "$DEST"/skills/*/; do
        [ -d "$d" ] || continue
        n="$(basename "$d")"
        if grep -q "\"skill\"[[:space:]]*:[[:space:]]*\"$n\"" "$TDIR"/*.jsonl 2>/dev/null; then
            continue
        elif grep -q "\"command\"[[:space:]]*:[[:space:]]*\"[^\"]*$n" "$TDIR"/*.jsonl 2>/dev/null; then
            echo "  skill:   $n (no Skill call, but its CLI/name appears in Bash -- likely used indirectly)"
        else
            echo "  skill:   $n"; UNUSED=$((UNUSED+1))
        fi
    done
    for f in "$DEST"/commands/*.md; do
        [ -f "$f" ] || continue
        n="$(basename "$f" .md)"
        grep -q "<command-name>/\{0,1\}$n<" "$TDIR"/*.jsonl 2>/dev/null \
            || { echo "  command: /$n"; UNUSED=$((UNUSED+1)); }
    done
    [ "$UNUSED" -eq 0 ] && echo "  (everything installed has been used at least once)"
    # A skill listed as unused whose matching command DID run means the skill
    # never auto-triggered -- the command carried the work. That is a wiring
    # problem (skill auto-trigger is best-effort), not necessarily dead weight.
    echo ""
    echo "[how to read this]"
    echo "  - An unused SKILL whose matching command ran a lot = the skill never"
    echo "    auto-triggered. Either drop it, or force it via a line in CLAUDE.md."
    echo "  - Auto-triggering is driven by the skill's description text and is"
    echo "    best-effort. A vague description = a skill that never fires."
    echo "  - This only sees Skill tool calls and Bash mentions; a skill applied"
    echo "    purely by the model reading its rules is invisible here."
    echo "  - Lean skills (ponytail*) sitting in a strict project (or vice versa)"
    echo "    are preset leftovers -- run blackcat --strict / --lean to switch"
    echo "    cleanly (conflicting skills get moved to .claude/backups/)."
    echo "  - Low-frequency is not the same as useless: some items are monthly"
    echo "    (e.g. /plans) or situational (e.g. writing pack)."
    echo ""
    echo "[caveats] Counts cover sessions recorded on THIS machine for THIS"
    echo "          project path only. Transcripts are pruned by Claude Code's"
    echo "          retention setting, and worktree/headless sessions log under"
    echo "          their own paths -- treat numbers as a floor, not exact."
    exit 0
fi

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
    [ -z "$STYLES" ] && STYLES="$PRESET_STYLES"
    echo "[preset] $PRESET"
fi

if [ "$WRITING" = true ] && [ "$ALL" != true ]; then
    SKILLS="$SKILLS $WRITING_SKILLS"
    echo "[writing] adding: $WRITING_SKILLS"
fi

# ---- preset switch detection --------------------------------------------
# lean and strict are mutually exclusive (ponytail says "minimal checks",
# tdd-workflow says "80%+ coverage" -- both trigger on every coding task).
# If the OTHER preset's skills are already in the project, offer to move
# them out before installing this one.
if [ "$ALL" != true ] && [ "$UPDATE_ONLY" != true ]; then
    if [ "$PRESET" = "strict" ]; then
        OTHER_SKILLS="$LEAN_SKILLS"; OTHER_NAME="lean"
    else
        OTHER_SKILLS="$STRICT_SKILLS"; OTHER_NAME="strict"
    fi
    CONFLICTS=""
    for s in $OTHER_SKILLS; do
        case " $SKILLS " in *" $s "*) continue ;; esac   # shared skills are fine
        [ -d "$DEST/skills/$s" ] && CONFLICTS="$CONFLICTS $s"
    done
    if [ -n "$CONFLICTS" ]; then
        echo ""
        echo "[preset] CONFLICT: this project has $OTHER_NAME skills installed:$CONFLICTS"
        echo "         lean and strict are mutually exclusive -- keeping both gives"
        echo "         the model contradictory instructions on every coding task."
        if [ -t 0 ]; then
            printf "Switch to %s? (moves conflicting skills to .claude/backups) [y/N] " "$PRESET"
            read -r ans || ans=""
            case "$ans" in
                y|Y|yes|YES)
                    BK="$DEST/backups/preset-switch-$(date +%Y%m%d-%H%M%S)"
                    mkdir -p "$BK"
                    for s in $CONFLICTS; do
                        mv "$DEST/skills/$s" "$BK/$s"
                        echo "  [moved] skills/$s -> $BK"
                    done
                    echo "  (leftover $OTHER_NAME-only commands are harmless -- they only run when invoked)"
                    ;;
                *)
                    echo "  [warn] keeping both presets -- behavior will be unpredictable"
                    ;;
            esac
        else
            echo "         (non-interactive: not touching them -- remove manually or re-run interactively)"
        fi
    fi
fi

mkdir -p "$DEST"
echo "[target] $DEST"

# Retire renamed commands before installing (backup, never delete).
for pair in $RENAMED_COMMANDS; do
    _old="${pair%%:*}"; _new="${pair#*:}"
    if [ -f "$DEST/commands/$_old.md" ]; then
        _bkr="$DEST/backups/renamed-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$_bkr"
        mv "$DEST/commands/$_old.md" "$_bkr/$_old.md"
        echo "  [renamed] /$_old -> /$_new (old copy backed up)"
    fi
done

# Skill directories are copied whole; existing ones are kept untouched
# (the project may have customized them).
install_skill() {
    local s="$1" src="$SCRIPT_DIR/skills/$1"
    if [ ! -d "$src" ]; then echo "  [skip] skills/$s (not found)"; return; fi
    if [ -d "$DEST/skills/$s" ]; then echo "  [keep] skills/$s (already exists)"; return; fi
    mkdir -p "$DEST/skills"
    cp -r "$src" "$DEST/skills/$s"
    echo "  [copy] skills/$s"
}
for s in $SKILLS; do install_skill "$s"; done

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

# Add a hook entry to the project's settings.json (idempotent: skipped when
# the command is already registered). Needs jq to edit JSON safely; without
# it, print the entry so the user can paste it.
register_hook() { # $1=event $2=matcher $3=command
    local sf="$DEST/settings.json"
    if [ -f "$sf" ] && grep -qF "$(basename "${3%\"}")" "$sf"; then
        echo "  [keep] $1 hook $(basename "${3%\"}") (already registered)"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "  [note] jq not found -- add to $sf under hooks.$1 manually:"
        echo "         {\"matcher\": \"$2\", \"hooks\": [{\"type\": \"command\", \"command\": $(printf '%s' "$3" | sed 's/"/\\"/g; s/^/"/; s/$/"/')}]}"
        return 0
    fi
    [ -f "$sf" ] || echo '{}' > "$sf"
    local tmp="$sf.tmp.$$"
    if jq --arg ev "$1" --arg m "$2" --arg c "$3" \
        '.hooks[$ev] = ((.hooks[$ev] // []) + [{"matcher": $m, "hooks": [{"type": "command", "command": $c, "timeout": 10}]}])' \
        "$sf" > "$tmp"; then
        mv "$tmp" "$sf"
        echo "  [hook] $1 ($2) -> $(basename "${3%\"}")"
    else
        rm -f "$tmp"
        echo "  [error] could not update $sf (invalid JSON?) -- hook not registered"
    fi
}

# Pitfall gate: lessons in .claude/learned/ block a write to a matching file
# once per session. Exits immediately while learned/ holds no lessons.
if [ "$UPDATE_ONLY" != true ]; then
    mkdir -p "$DEST/hooks"
    if [ ! -f "$DEST/hooks/pitfall-gate.sh" ]; then
        cp "$SCRIPT_DIR/project-hooks/pitfall-gate.sh" "$DEST/hooks/pitfall-gate.sh"
        echo "  [copy] hooks/pitfall-gate.sh"
    fi
    if [ ! -d "$DEST/learned" ]; then
        mkdir -p "$DEST/learned"
        cp "$SCRIPT_DIR/templates/learned/README.md" "$SCRIPT_DIR/templates/learned/_TEMPLATE.md" "$DEST/learned/"
        echo "  [copy] learned/ (README + _TEMPLATE)"
    fi
    register_hook PreToolUse "Write|Edit|MultiEdit" 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/pitfall-gate.sh"'
fi

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

cmd_model() { # $1=command basename -> current model, empty if none
    local f="$DEST/commands/$1.md"
    [ -f "$f" ] || return 0
    awk '/^---$/{n++; next} n==1 && /^model:[[:space:]]/{sub(/^model:[[:space:]]*/,""); print; exit}' "$f"
}

set_cmd_model() { # $1=command basename $2=model
    local f="$DEST/commands/$1.md"
    [ -f "$f" ] || return 0
    if [ -n "$(cmd_model "$1")" ]; then
        # Only the FIRST model: line (frontmatter). Files like plan.md also
        # contain a model: line inside an example block that must not change.
        sed -i "0,/^model:[[:space:]].*/s//model: $2/" "$f"
        echo "  [model] commands/$1 -> $2"
    else
        echo "  [note] commands/$1.md has no model: line -- edit it manually"
    fi
}

set_main_model() { # $1=model
    local sf="$DEST/settings.json"
    if [ ! -f "$sf" ]; then
        printf '{\n  "model": "%s"\n}\n' "$1" > "$sf"
        echo "  [model] settings.json (created) -> $1"
    elif grep -q '"model"' "$sf"; then
        sed -i "s/\"model\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"model\": \"$1\"/" "$sf"
        echo "  [model] settings.json -> $1"
    elif command -v jq >/dev/null 2>&1 && jq --arg m "$1" '.model = $m' "$sf" > "$sf.tmp.$$"; then
        mv "$sf.tmp.$$" "$sf"
        echo "  [model] settings.json -> $1"
    else
        rm -f "$sf.tmp.$$"
        echo "  [note] settings.json has no model key -- add \"model\": \"$1\" manually"
    fi
}

if [ "$UPDATE_ONLY" != true ] && [ -t 0 ] && { [ "$MODEL_PICK" = true ] || [ "$FORCE_MODELS" = true ]; }; then
    echo ""
    echo "[models] Model routing for this project."
    echo "         (skills have no model of their own -- they run on whatever"
    echo "          model is active; only commands and agents can be routed)"

    # Every installed command that carries a model: line, in file order.
    MC_NAMES=""
    for f in "$DEST"/commands/*.md; do
        [ -f "$f" ] || continue
        n="$(basename "$f" .md)"
        [ -n "$(cmd_model "$n")" ] && MC_NAMES="$MC_NAMES $n"
    done

    # Probe Fable only if something is actually routed to it.
    NEEDS_FABLE=false
    for n in $MC_NAMES; do
        case "$(cmd_model "$n")" in *fable*) NEEDS_FABLE=true ;; esac
    done
    if [ "$NEEDS_FABLE" = true ]; then
        printf "  Probing claude-fable-5 (one tiny API call via claude CLI)... "
        if probe_fable; then
            echo "available"
        elif [ $? -eq 2 ]; then
            echo "unknown (claude CLI not found)"
        else
            echo "NOT available"
            printf "  Downgrade every claude-fable-5 route to opus? [Y/n] "
            read -r a || a=""
            case "$a" in
                n|N|no|NO) ;;
                *) for n in $MC_NAMES; do
                       case "$(cmd_model "$n")" in *fable*) set_cmd_model "$n" opus ;; esac
                   done ;;
            esac
        fi
    fi

    echo ""
    echo "  Current routing:"
    i=1; MC_OPTS=""
    for n in $MC_NAMES; do
        printf "   %2d) /%-12s %s\n" "$i" "$n" "$(cmd_model "$n")"
        MC_OPTS="$MC_OPTS $i:$n"
        i=$((i+1))
    done
    MAIN_CUR="$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$DEST/settings.json" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')"
    [ -n "$MAIN_CUR" ] || MAIN_CUR="(inherits global setting)"
    printf "   %2d) %-13s %s\n" "$i" "main loop" "$MAIN_CUR"
    MAIN_IDX=$i

    printf "  Change which? (numbers separated by spaces, Enter = keep all): "
    read -r sel || sel=""
    if [ -n "$sel" ]; then
        echo "  Choices: 1=claude-fable-5  2=opus  3=sonnet  4=haiku"
        echo "  (Enter keeps current; or type a full model id)"
        for num in $sel; do
            if [ "$num" = "$MAIN_IDX" ]; then
                printf "    main loop [current: %s]: " "$MAIN_CUR"
                read -r a || a=""
                nm="$(model_from_choice "$a" "")"
                [ -n "$nm" ] && set_main_model "$nm"
                continue
            fi
            for pair in $MC_OPTS; do
                if [ "${pair%%:*}" = "$num" ]; then
                    cn="${pair#*:}"
                    printf "    /%s [current: %s]: " "$cn" "$(cmd_model "$cn")"
                    read -r a || a=""
                    nm="$(model_from_choice "$a" "")"
                    [ -n "$nm" ] && set_cmd_model "$cn" "$nm"
                fi
            done
        done
    fi
    echo "  (re-open this any time with: blackcat --models)"
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

# ------------------------------------------------------------------- ui ----
# Frontend pack (opt-in; dead weight for backend-only projects):
# /ui-style -> DESIGN.md tokens, /ui-site -> IA + stubs, /ui-page -> deepen
# one page via the ui-builder agent. Pencil MCP recommended for design sync.
# Insert the "UX checks only" note after ui-ux-pro-max's frontmatter (once).
upm_note() {
    local f="$DEST/skills/ui-ux-pro-max/SKILL.md"
    [ -f "$f" ] || return 0
    grep -q '^> blackcat:' "$f" && return 0
    awk 'BEGIN{n=0} {print} /^---[[:space:]]*$/ && ++n==2 {print ""; print "> blackcat: in this project use this skill only for usability checks (--domain ux or chart): accessibility, touch, forms, navigation, charts. Style, color, fonts and layout come from .claude/ui/DESIGN.md; do not pick them from here."}' \
        "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

install_ui() {
    echo "[ui] installing frontend pack"
    for c in $UI_COMMANDS; do install_md commands "$c"; done
    for a in $UI_AGENTS; do install_md agents "$a"; done
    for s in $UI_SKILLS; do install_skill "$s"; done
    # The style library itself is global (~/.claude/ui-library, installed by
    # install.sh); /ui-style composes the chosen style into .claude/ui/.
    if [ ! -f "$HOME/.claude/ui-library/CATALOG.md" ]; then
        echo "  [note] style library not found at ~/.claude/ui-library"
        echo "         rerun install.bat / install.sh in the blackcat repo to get it"
    fi
    # ui-ux-pro-max (github.com/nextlevelbuilder/ui-ux-pro-max-skill, MIT):
    # searchable UX DB queried via its own script -- low context cost.
    # Used ONLY for usability checks (a11y, touch, forms, navigation,
    # charts); looks come from DESIGN.md, so a note saying so is inserted
    # right after its frontmatter.
    if [ -d "$DEST/skills/ui-ux-pro-max" ] && ! grep -q '^name: *ui-ux-pro-max *$' "$DEST/skills/ui-ux-pro-max/SKILL.md" 2>/dev/null; then
        # Installers before v26.10.2 copied the wrong skill (banner-design)
        # after upstream became a multi-skill repo. Back it up and refetch.
        _bkw="$DEST/backups/ui-ux-pro-max-wrong-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$_bkw" && mv "$DEST/skills/ui-ux-pro-max" "$_bkw/"
        echo "  [fix] skills/ui-ux-pro-max held a different skill; moved to $_bkw"
    fi
    if [ -d "$DEST/skills/ui-ux-pro-max" ]; then
        echo "  [keep] skills/ui-ux-pro-max (already installed)"
        upm_note
    else
        echo "  [ui-ux-pro-max] fetching design intelligence DB..."
        _upmtmp="$DEST/.upm-tmp"
        rm -rf "$_upmtmp"
        if git clone --depth 1 https://github.com/nextlevelbuilder/ui-ux-pro-max-skill "$_upmtmp" >/dev/null 2>&1; then
            # The upstream repo holds several skills (banner-design, brand,
            # slides ...). Take the one whose frontmatter says
            # name: ui-ux-pro-max, never just the first SKILL.md found.
            _upmsrc=""
            for _c in "$_upmtmp/.claude/skills/ui-ux-pro-max" "$_upmtmp"; do
                if grep -q '^name: *ui-ux-pro-max *$' "$_c/SKILL.md" 2>/dev/null; then _upmsrc="$_c"; break; fi
            done
            if [ -z "$_upmsrc" ]; then
                _upmfound="$(grep -rl --include=SKILL.md '^name: *ui-ux-pro-max *$' "$_upmtmp" 2>/dev/null | grep -v '/\.git/' | head -1)"
                [ -n "$_upmfound" ] && _upmsrc="$(dirname "$_upmfound")"
            fi
            if [ -n "$_upmsrc" ] && [ -f "$_upmsrc/SKILL.md" ]; then
                mkdir -p "$DEST/skills"
                cp -rL "$_upmsrc" "$DEST/skills/ui-ux-pro-max"
                rm -rf "$DEST/skills/ui-ux-pro-max/.git"
                # Upstream paths assume a plugin install; point them at the project copy.
                sed -i 's#\${CLAUDE_PLUGIN_ROOT}/\.claude/skills/ui-ux-pro-max#.claude/skills/ui-ux-pro-max#g' \
                    "$DEST/skills/ui-ux-pro-max/SKILL.md" 2>/dev/null || true
                upm_note
                echo "  [copy] skills/ui-ux-pro-max (styles/palettes/UX guidelines DB)"
            else
                echo "  [skip] ui-ux-pro-max: unexpected repo layout"
            fi
        else
            echo "  [skip] could not fetch ui-ux-pro-max (offline?)"
        fi
        rm -rf "$_upmtmp"
    fi
    # pen CLI (@pencil.dev/cli): headless .pen engine -- agent, MCP tools,
    # PNG/JPEG/WEBP/PDF export -- no desktop app needed. Auth: pen login.
    if command -v pen >/dev/null 2>&1; then
        echo "  [ok] pen CLI detected -- canvas-first flow available"
        echo "       (.pen mockups + headless PNG export; auth via: pen login)"
    else
        echo "  [note] optional canvas-first flow needs the pen CLI:"
        echo "         npm install -g @pencil.dev/cli   (Node 18+), then: pen login"
        echo "         MCP wiring: see https://docs.pencil.dev/for-developers/pen-cli"
        echo "         (the pencil desktop app wires its MCP automatically instead)"
    fi
}

# --ui-refresh: the externally fetched skill (ui-ux-pro-max) is
# pinned at whatever was latest when installed and are ignored by the
# normal update flow (they are not this repo's files). This re-fetches
# them, backing up the old copies first.
if [ "$UI_REFRESH" = true ] && [ "$UPDATE_ONLY" != true ]; then
    _bku="$DEST/backups/ui-refresh-$(date +%Y%m%d-%H%M%S)"
    for s in ui-ux-pro-max; do
        if [ -d "$DEST/skills/$s" ]; then
            mkdir -p "$_bku"
            mv "$DEST/skills/$s" "$_bku/$s"
            echo "[ui-refresh] backed up skills/$s -> $_bku"
        fi
    done
    UI=true
fi

if [ "$UPDATE_ONLY" != true ]; then
    if [ "$UI" = true ]; then
        echo ""
        install_ui
    elif [ -t 0 ] && [ "$MODEL_PICK" = true ] && [ ! -f "$DEST/commands/ui-style.md" ]; then
        echo ""
        printf "[ui] Will this project have a frontend? Install the UI pack (/ui-style /ui-site /ui-page)? [y/N] "
        read -r ans || ans=""
        case "$ans" in
            y|Y|yes|YES) install_ui ;;
            *) echo "  (add it later any time with: blackcat --ui)" ;;
        esac
    fi
fi

# ------------------------------------------------------------------- pm ----
# Project management pack (opt-in): WBS in .claude/taskmaster-data/wbs.md,
# /task-next feeds /go and /plan, /commit marks rows done. Time is logged
# by the global statusline whenever .claude/taskmaster-data/ exists (that
# folder is created by /task-init), so there is no hook to install.
install_pm() {
    echo "[pm] installing project management pack"
    for c in $PM_COMMANDS; do install_md commands "$c"; done
    for s in $PM_SKILLS; do install_skill "$s"; done
    echo "  next: /task-init to build the WBS (time tracking starts after that)"
}

if [ "$UPDATE_ONLY" != true ]; then
    if [ "$PM" = true ]; then
        echo ""
        install_pm
    elif [ -t 0 ] && [ "$MODEL_PICK" = true ] && [ ! -f "$DEST/commands/task-init.md" ]; then
        echo ""
        printf "[pm] Track this project with a WBS and time log (/task-init /task-next /time-log)? [y/N] "
        read -r ans || ans=""
        case "$ans" in
            y|Y|yes|YES) install_pm ;;
            *) echo "  (add it later any time with: blackcat --pm)" ;;
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

# Hallmark was fetched by --ui up to v26.10.2. Its rules clash with the
# chosen brand style and duplicate anti-ai.md, so it is retired: move the
# old copy to backups (never deleted) on any run, --update included.
if grep -q '^name: *hallmark' "$DEST/skills/hallmark/SKILL.md" 2>/dev/null; then
    _bkh="$DEST/backups/hallmark-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$_bkh" && mv "$DEST/skills/hallmark" "$_bkh/"
    echo "[retired] skills/hallmark moved to $_bkh (replaced by ui-style-compliance)"
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
# Project hooks ship from project-hooks/ but live in .claude/hooks/.
for f in "$DEST"/hooks/*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    src="$SCRIPT_DIR/project-hooks/$name"
    [ -f "$src" ] || continue
    cmp -s "$src" "$f" || UPDATE_LIST="$UPDATE_LIST hooks/$name"
done

do_update() {
    local src="$SCRIPT_DIR/$1" dst="$DEST/$1"
    case "$1" in hooks/*) src="$SCRIPT_DIR/project-hooks/${1#hooks/}" ;; esac
    if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
    else
        # Preserve the project's chosen frontmatter model across updates
        # (first model: line only -- some files carry example blocks too).
        local keep_model=""
        [ -f "$dst" ] && keep_model="$(awk '/^---$/{n++; next} n==1 && /^model:[[:space:]]/{print; exit}' "$dst")"
        cp "$src" "$dst"
        if [ -n "$keep_model" ] && grep -q '^model:[[:space:]]' "$dst"; then
            sed -i "0,/^model:[[:space:]].*/s//$keep_model/" "$dst"
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
