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
#   bash install-project.sh <project-path> --graphify   # set up Graphify knowledge graph (experimental, needs graphify CLI)
#   bash install-project.sh <project-path> --graphify-remove  # take Graphify back out of a project
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
# --rules copies rule files into <project>/.claude/rules/, which Claude Code
# loads by itself: files without "paths:" frontmatter at launch, files with
# it only when a matching file is touched. No CLAUDE.md import is written
# (an import would load the same text a second time).
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
LEAN_COMMANDS="go next sync grill grill-ui grill-doc plan clean-plan dispatch merge review-code review-deep commit learn save-session session"
STRICT_SKILLS="tdd-workflow verification-loop worklog session-etiquette"
STRICT_COMMANDS="go next sync grill grill-ui grill-doc plan clean-plan spec dispatch merge tdd verify review-code review-deep commit learn save-session session"

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
PM_COMMANDS="task-init task-add task-next task-auto task-status time-log pm-choose"
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
  --graphify       Code knowledge graph (experimental, needs the graphify
                   CLI). Measured on a real project: Claude ignored it and
                   grep answered better. Try only on huge single-language
                   code bases, and check /time-log or --usage afterwards.
  --graphify-remove  Take Graphify back out: its skill, CLAUDE.md section,
                   hooks and git hooks. Asks before deleting graphify-out/.
  --taskmaster     Old TaskMaster hooks. New projects: use --pm instead.

CODING RULES
  --rules python   Copy coding rules (common + the language) into .claude/rules/.
                   Languages: python, typescript, rust (comma separated).
  --no-rules       Do not ask about rules.

MAINTENANCE
  --update         After 'git pull' of blackcat: refresh every installed
                   file that changed. Overwrites local edits, so commit
                   the project's .claude/ first.
  --models         Choose again which model each step uses, one by one.
  --models save|balanced|max
                   Set all of them at once. balanced (default): planning
                   on fable, the per-task review on opus, deep review on
                   fable. save: one step cheaper everywhere. max: all fable.
  --doctor         Read-only report: what is loaded into every session and
                   how big, files that keep growing, hooks, which model
                   each command uses, git state. Start here when tokens
                   run out fast.
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
MODEL_PROFILE=""
DOCTOR=false
GRAPHIFY=false
GRAPHIFY_REMOVE=false
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
        --models) FORCE_MODELS=true
            case "${2:-}" in save|balanced|max) MODEL_PROFILE="$2"; shift ;; esac ;;
        --doctor) DOCTOR=true ;;
        --graphify) GRAPHIFY=true ;;
        --graphify-remove) GRAPHIFY_REMOVE=true ;;
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

remove_graphify() {
    echo "[graphify-remove] $TARGET"
    if command -v graphify >/dev/null 2>&1; then
        # --project keeps graphify's user-global skill untouched; the bare
        # "graphify claude uninstall" would delete that too.
        (cd "$TARGET" && graphify uninstall --project --platform claude 2>&1 | sed 's/^/  /') \
            || echo "  [warn] graphify uninstall --project --platform claude failed"
        (cd "$TARGET" && graphify hook uninstall 2>&1 | sed 's/^/  /') \
            || echo "  [warn] graphify hook uninstall failed"
    else
        echo "  [manual] graphify CLI not found, so remove these by hand:"
        echo "    - .claude/skills/graphify/"
        echo "    - the '## graphify' section in CLAUDE.md"
        echo "    - hooks whose command mentions graphify in .claude/settings.json"
        echo "    - blocks between '# graphify-...-start' and '-end' in .git/hooks/post-*"
    fi
    local out="$TARGET/graphify-out"
    if [ -d "$out" ]; then
        local size; size="$(du -sh "$out" 2>/dev/null | cut -f1)"
        if [ -t 0 ]; then
            printf "  Delete graphify-out/ (%s, generated data only)? [y/N] " "$size"
            read -r ans || ans=""
            case "$ans" in
                y|Y|yes|YES) rm -rf "$out" && echo "  [removed] graphify-out/ ($size)" ;;
                *) echo "  [keep] graphify-out/ ($size)" ;;
            esac
        else
            echo "  [keep] graphify-out/ ($size) -- delete it yourself if unused"
        fi
    fi
}

if [ "$GRAPHIFY_REMOVE" = true ]; then
    remove_graphify
    exit 0
fi

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

# ---------------------------------------------------------- model profile ----
# blackcat --models save|balanced|max : set every thinking route at once.
#   one-off thinking = grill grill-doc spec task-init plan (run once per
#                      feature or project)
#   review-code      = runs after EVERY task, so it is the biggest repeat cost
#   review-deep      = critical tasks only
apply_model_profile() { # $1=save|balanced|max
    local think review deep main=""
    case "$1" in
        max)      think=fable; review=fable;  deep=fable ;;
        balanced) think=fable; review=opus;   deep=fable ;;
        save)     think=opus;  review=sonnet; deep=opus; main=sonnet ;;
    esac
    echo "[models] profile: $1"
    local n
    for n in grill grill-doc spec task-init plan; do
        [ -f "$DEST/commands/$n.md" ] && set_cmd_model "$n" "$think"
    done
    [ -f "$DEST/commands/review-code.md" ] && set_cmd_model review-code "$review"
    [ -f "$DEST/commands/review-deep.md" ] && set_cmd_model review-deep "$deep"
    if [ -n "$main" ]; then
        set_main_model "$main"
    elif grep -q '"model"[[:space:]]*:[[:space:]]*"sonnet"' "$DEST/settings.json" 2>/dev/null; then
        # undo what the save profile set
        set_main_model opus
    else
        echo "  [keep] main loop model (change it with: blackcat --models)"
    fi
    echo "  Price per million tokens, input/output (2026-11): fable 8/40, opus 4/20, sonnet 2/10 USD"
}

if [ -n "$MODEL_PROFILE" ]; then
    if [ ! -d "$DEST/commands" ]; then
        echo "[error] no .claude/commands here -- install a preset first (blackcat --lean)"; exit 1
    fi
    apply_model_profile "$MODEL_PROFILE"
    exit 0
fi

# ----------------------------------------------------------------- doctor ----
# blackcat --doctor : read-only report of what costs tokens in this project.
# Sizes are bytes; 1 KB of mixed Chinese/English text is very roughly 300-400
# tokens, paid again in every new session (and after every /clear).
doctor_size() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || echo 0; }
doctor_lines() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
doctor_name() { # shorten a path for display
    case "$1" in
        "$TARGET"/*) echo "${1#"$TARGET"/}" ;;
        "$HOME"/*)   echo "~/${1#"$HOME"/}" ;;
        *)           echo "$1" ;;
    esac
}
doctor_row() { # $1=label $2=bytes $3=lines $4=warn-bytes
    local flag=""
    [ "$2" -gt "$4" ] && flag="  <-- large"
    [ "$2" -gt 0 ] && printf "  %-46s %7s B %5s lines%s\n" "$1" "$2" "$3" "$flag"
}
doctor_imports() { # print @imports of a CLAUDE.md, one path per line, ~ expanded
    [ -f "$1" ] || return 0
    grep -o '^@[^[:space:]]*' "$1" 2>/dev/null | sed 's/^@//' | while read -r imp; do
        case "$imp" in
            "~/"*) echo "$HOME/${imp#\~/}" ;;
            /*)    echo "$imp" ;;
            *)     echo "$(dirname "$1")/$imp" ;;
        esac
    done
}
run_doctor() {
    echo "blackcat doctor: $TARGET"
    echo ""
    echo "[1] Loaded into EVERY new session (also after /clear)"
    local total=0 f sz
    for f in "$HOME/.claude/CLAUDE.md" "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.local.md" "$DEST/CLAUDE.md"; do
        [ -f "$f" ] || continue
        sz=$(doctor_size "$f"); total=$((total+sz))
        doctor_row "$(doctor_name "$f")" "$sz" "$(doctor_lines "$f")" 8000
        doctor_imports "$f" | while read -r imp; do
            [ -f "$imp" ] && doctor_row "  import $(doctor_name "$imp")" "$(doctor_size "$imp")" "$(doctor_lines "$imp")" 6000
        done
        for imp in $(doctor_imports "$f"); do [ -f "$imp" ] && total=$((total+$(doctor_size "$imp"))); done
    done
    # .claude/rules: files without "paths:" load at launch, the rest on demand.
    local rl=0 rn=0 rs=0 rsn=0
    for f in "$DEST"/rules/*.md "$DEST"/rules/*/*.md; do
        [ -f "$f" ] || continue
        if head -5 "$f" | grep -q '^paths:'; then rs=$((rs+$(doctor_size "$f"))); rsn=$((rsn+1))
        else rl=$((rl+$(doctor_size "$f"))); rn=$((rn+1)); fi
    done
    [ "$rn" -gt 0 ] && printf "  %-46s %7s B  (%s files)%s\n" ".claude/rules (no paths: -> always loaded)" "$rl" "$rn" "$([ "$rl" -gt 8000 ] && echo '  <-- large')"
    [ "$rsn" -gt 0 ] && printf "  %-46s %7s B  (%s files, only when a matching file is touched)\n" ".claude/rules (path-scoped, not counted)" "$rs" "$rsn"
    total=$((total+rl))
    grep -qF '<!-- blackcat:rules -->' "$TARGET/CLAUDE.md" 2>/dev/null \
        && echo "      CLAUDE.md still @-imports .claude/rules: loaded twice. Run blackcat --update to remove the block."
    # Claude Code auto memory: only the head of MEMORY.md is loaded.
    local enc mem
    enc="$(printf '%s' "$TARGET" | sed 's|[^A-Za-z0-9]|-|g')"
    mem="$HOME/.claude/projects/$enc/memory/MEMORY.md"
    if [ -f "$mem" ]; then
        sz=$(doctor_size "$mem"); total=$((total+sz))
        doctor_row "auto memory MEMORY.md" "$sz" "$(doctor_lines "$mem")" 20000
        [ "$(doctor_lines "$mem")" -gt 200 ] && echo "      over 200 lines: Claude Code loads only the first part; move detail into topic files"
        echo "      folder: ${mem%/MEMORY.md}  ($(ls "${mem%/MEMORY.md}" 2>/dev/null | wc -l | tr -d ' ') files; edit with /memory)"
    fi
    if [ -f "$DEST/session-board.md" ] && grep -q "load-session-board" "$DEST/settings.json" 2>/dev/null; then
        sz=$(doctor_size "$DEST/session-board.md"); total=$((total+sz))
        doctor_row ".claude/session-board.md (hook)" "$sz" "$(doctor_lines "$DEST/session-board.md")" 3000
    fi
    local nsk=0 ncm=0 nag=0 dsc=0
    for f in "$DEST"/skills/*/SKILL.md; do [ -f "$f" ] || continue; nsk=$((nsk+1)); dsc=$((dsc+$(grep -m1 '^description:' "$f" | wc -c))); done
    for f in "$DEST"/commands/*.md; do [ -f "$f" ] || continue; ncm=$((ncm+1)); dsc=$((dsc+$(grep -m1 '^description:' "$f" | wc -c))); done
    for f in "$DEST"/agents/*.md; do [ -f "$f" ] || continue; nag=$((nag+1)); dsc=$((dsc+$(grep -m1 '^description:' "$f" | wc -c))); done
    total=$((total+dsc))
    printf "  %-46s %7s B  (%s skills, %s commands, %s agents)\n" "descriptions of installed items" "$dsc" "$nsk" "$ncm" "$nag"
    if [ -f "$TARGET/.mcp.json" ]; then
        local nm; nm=$(grep -c '"command"\|"url"' "$TARGET/.mcp.json" 2>/dev/null || true)
        echo "  .mcp.json: about $nm server(s) -- every connected server adds its tool list to each session"
        grep -q '"memory"' "$TARGET/.mcp.json" && echo "      'memory' server: keeps everything in ONE json file and can dump all of it into context; remove it if unused"
        grep -q '"sequential-thinking"' "$TARGET/.mcp.json" && echo "      'sequential-thinking' server: little gain on current models; remove it to save tokens"
    fi
    printf "  %-46s %7s B  (roughly %s tokens per new session)\n" "TOTAL (files above)" "$total" "$((total/3))"
    [ "$total" -gt 40000 ] && echo "  => heavy. Trim CLAUDE.md / MEMORY.md, uninstall unused skills (blackcat --usage shows which)."

    echo ""
    echo "[2] Files that grow (read on demand, but they bloat if never archived)"
    local wl; wl=$(doctor_lines "$DEST/worklog.md")
    [ "$wl" -gt 0 ] && printf "  %-46s %5s lines%s\n" ".claude/worklog.md" "$wl" "$([ "$wl" -gt 150 ] && echo '  <-- review + /commit to archive it')"
    local ns; ns=$(ls "$DEST"/sessions/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$ns" -gt 0 ] && printf "  %-46s %5s files%s\n" ".claude/sessions/" "$ns" "$([ "$ns" -gt 10 ] && echo '  <-- keep 10, move older to sessions/archive/')"
    local nl; nl=$(ls "$DEST"/learned/*.md 2>/dev/null | grep -vc '_TEMPLATE\|README' || true)
    [ "$nl" -gt 0 ] && printf "  %-46s %5s files%s\n" ".claude/learned/" "$nl" "$([ "$nl" -gt 30 ] && echo '  <-- merge duplicates with /learn')"
    local np; np=$(grep -l '^status: active' "$DEST"/plans/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$np" -gt 0 ] && printf "  %-46s %5s active%s\n" ".claude/plans/" "$np" "$([ "$np" -gt 3 ] && echo '  <-- /clean-plan')"
    local wbs="$DEST/taskmaster-data/wbs.md"
    if [ -f "$wbs" ]; then
        local rows; rows=$(grep -c '^| *[0-9][0-9]*\.[0-9]' "$wbs" || true)
        printf "  %-46s %5s tasks%s\n" "WBS" "$rows" "$([ "$rows" -gt 40 ] && echo '  <-- archive finished milestones (/task-status)')"
    fi
    [ -d "$TARGET/graphify-out" ] && echo "  graphify-out/  $(du -sh "$TARGET/graphify-out" 2>/dev/null | cut -f1)  <-- measured as not worth it: blackcat --graphify-remove"

    echo ""
    echo "[3] Hooks (each one runs on every matching event)"
    if [ -f "$DEST/settings.json" ] && command -v jq >/dev/null 2>&1; then
        jq -r '.hooks // {} | to_entries[] | .key as $e | .value[]? | "  \($e) [\(.matcher // "*")] \(.hooks[]?.command)"' "$DEST/settings.json" 2>/dev/null | cut -c1-110 || true
        grep -q 'graphify' "$DEST/settings.json" && echo "  => graphify hooks fire on every Read/Grep/Bash and add a reminder each time: blackcat --graphify-remove"
    else
        echo "  (no .claude/settings.json, or jq missing)"
    fi

    echo ""
    echo "[4] Which model each command runs on"
    local main; main="$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$DEST/settings.json" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')"
    [ -n "$main" ] || main="$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$HOME/.claude/settings.json" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')"
    echo "  main loop: ${main:-"(Claude Code default)"}   <- every command marked (main) below runs on this"
    local line="" n m
    for f in "$DEST"/commands/*.md; do
        [ -f "$f" ] || continue
        n="$(basename "$f" .md)"; m="$(cmd_model "$n")"
        printf "  /%-14s %s\n" "$n" "${m:-(main)}"
    done | sort -k2 | awk '{printf "%-34s", $0; if (NR%2==0) printf "\n"} END {if (NR%2) printf "\n"}'
    grep -l '^model: claude-fable-5[[:space:]]*$' "$DEST"/commands/*.md >/dev/null 2>&1 \
        && echo "  => some commands pin claude-fable-5 (old, dearer): run blackcat --update"
    [ "$(cmd_model review-code)" = "fable" ] \
        && echo "  => /review-code runs after EVERY task and is on fable. Default is now opus;" \
        && echo "     /review-deep (fable) covers critical tasks. One step: blackcat --models balanced"
    echo "  Profiles: blackcat --models save | balanced | max     Pick one by one: blackcat --models"

    echo ""
    echo "[5] Git"
    if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
        local br up cnt
        br="$(git -C "$TARGET" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
        up="$(git -C "$TARGET" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
        echo "  branch: $br   uncommitted files: $(git -C "$TARGET" status --short 2>/dev/null | wc -l | tr -d ' ')"
        if [ -n "$up" ]; then
            cnt="$(git -C "$TARGET" rev-list --left-right --count "$up...HEAD" 2>/dev/null || true)"
            echo "  vs $up (as of last fetch): behind $(echo "$cnt" | cut -f1), ahead $(echo "$cnt" | cut -f2)   -> /sync"
        elif [ -n "$(git -C "$TARGET" remote 2>/dev/null)" ]; then
            echo "  this branch has no upstream yet   -> /sync push"
        else
            echo "  no remote configured"
        fi
        local wt; wt=$(git -C "$TARGET" worktree list 2>/dev/null | wc -l | tr -d ' ')
        [ "$wt" -gt 1 ] && echo "  worktrees: $wt   (finished dispatch runs: bcd --clean)"
        local ib; ib=$(git -C "$TARGET" branch --list 'integrate/*' 'task/*' 2>/dev/null | wc -l | tr -d ' ')
        [ "$ib" -gt 0 ] && echo "  leftover integrate/* and task/* branches: $ib   (bcd --clean removes merged ones)"
    else
        echo "  not a git repository"
    fi
}

if [ "$DOCTOR" = true ]; then
    run_doctor
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
# First-install model picker: probe whether the fable alias is usable, then
# ask which model each stage should run on. Choices are written into THIS
# project's command copies (and optionally .claude/settings.json), so every
# project can route differently. Re-runs skip it (files already existed);
# re-open it any time with --models. Non-interactive runs keep the repo
# defaults (plan/review: fable, commit: sonnet). Aliases, not pinned ids:
# a pinned id goes stale (claude-fable-5 costs more than its successor).

probe_fable() {
    command -v claude >/dev/null 2>&1 || return 2
    if command -v timeout >/dev/null 2>&1; then
        timeout 45 claude --model fable -p "ok" >/dev/null 2>&1
    else
        claude --model fable -p "ok" >/dev/null 2>&1
    fi
}

model_from_choice() { # $1=answer $2=default
    case "$1" in
        "") echo "$2" ;;
        1)  echo "fable" ;;
        2)  echo "opus" ;;
        3)  echo "sonnet" ;;
        4)  echo "haiku" ;;
        *)  echo "$1" ;;
    esac
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
        printf "  Probing fable (one tiny API call via claude CLI)... "
        if probe_fable; then
            echo "available"
        elif [ $? -eq 2 ]; then
            echo "unknown (claude CLI not found)"
        else
            echo "NOT available"
            printf "  Downgrade every fable route to opus? [Y/n] "
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
        echo "  Choices: 1=fable  2=opus  3=sonnet  4=haiku"
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
    echo "[rules] Coding rules can be copied into this project's .claude/rules/."
    echo "        Language sets load only when a matching file is touched; every"
    echo "        common rule costs context in every session -- pick only what you need."
    printf "Add coding rules? [y/N] "
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
    # Claude Code loads every .md under .claude/rules/ by itself: files
    # without "paths:" frontmatter at launch, files with it only when a
    # matching file is touched (the language sets are path-scoped). So copy
    # ONLY the selected common files, and write no @-import: an import
    # would load the same text a second time, and unscoped.
    mkdir -p "$DEST/rules/common"
    for c in $COMMON_SEL; do
        src="$SCRIPT_DIR/rules/common/$c.md"
        [ -f "$src" ] || { echo "  [skip] rules/common/$c (not found)"; continue; }
        if [ -f "$DEST/rules/common/$c.md" ]; then echo "  [keep] rules/common/$c"; continue; fi
        cp "$src" "$DEST/rules/common/$c.md"
        echo "  [copy] rules/common/$c (loaded every session)"
    done
    rmdir "$DEST/rules/common" 2>/dev/null || true
    for r in $LANG_SETS; do
        src="$SCRIPT_DIR/rules/$r"
        if [ ! -d "$src" ]; then echo "  [skip] rules/$r (not found)"; continue; fi
        if [ -d "$DEST/rules/$r" ]; then echo "  [keep] rules/$r (already exists)"; continue; fi
        cp -r "$src" "$DEST/rules/$r"
        echo "  [copy] rules/$r (loaded only when a matching file is touched)"
    done
fi

# Rules installed before v26.11.4 were ALSO @-imported from CLAUDE.md, and
# the whole common/ folder was copied even when only some were picked. Both
# cost context every session: imports duplicated what Claude Code already
# loads from .claude/rules/, and unpicked common files loaded anyway. Fix it
# on any run: keep what the import block listed, move unlisted common files
# to backups, then drop the block.
RULES_MD="$TARGET/CLAUDE.md"
if [ -f "$RULES_MD" ] && grep -qF '<!-- blackcat:rules -->' "$RULES_MD"; then
    _bkr="$DEST/backups/rules-unselected-$(date +%Y%m%d-%H%M%S)"
    for f in "$DEST"/rules/common/*.md; do
        [ -f "$f" ] || continue
        if ! grep -qF "@.claude/rules/common/$(basename "$f")" "$RULES_MD"; then
            mkdir -p "$_bkr" && mv "$f" "$_bkr/"
            echo "[rules] common/$(basename "$f") was never selected but loaded anyway -> moved to backups"
        fi
    done
    cp "$RULES_MD" "$RULES_MD.blackcat-bak"
    awk '
        /^<!-- blackcat:rules -->$/ {skip=1; next}
        skip && /^<!-- Coding rules installed by claude_blackcat/ {incomment=1}
        skip && incomment { if ($0 ~ /-->/) incomment=0; next }
        skip && /^@\.claude\/rules\// {next}
        {skip=0; print}
    ' "$RULES_MD.blackcat-bak" > "$RULES_MD"
    if grep -q '@\.claude/rules/' "$RULES_MD"; then
        echo "[rules] could not cleanly remove the import block -- restored CLAUDE.md, remove the @.claude/rules/ lines by hand"
        mv "$RULES_MD.blackcat-bak" "$RULES_MD"
    else
        rm -f "$RULES_MD.blackcat-bak"
        echo "[rules] removed the @-import block from CLAUDE.md (.claude/rules/ loads natively; imports doubled it)"
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

# Graphify is opt-in only. It used to be offered on first install, but on
# a real project its hook nudged 583 times with zero graph queries, grep
# answered 6 of 7 relation questions better, and graphify-out/ grew to
# 411 MB -- so blackcat no longer suggests it.
if [ "$UPDATE_ONLY" != true ] && [ "$GRAPHIFY" = true ]; then
    echo ""
    echo "[graphify] experimental -- see blackcat --help before relying on it"
    install_graphify
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

# Commands installed before v26.11.3 pinned "model: claude-fable-5". That id
# is the first Fable release: it is dearer than the current one and never
# moves forward. Rewrite exactly that value to the alias (any other model a
# project chose is left alone). The update check ignores model lines, so
# without this the stale id would survive every --update.
for f in "$DEST"/commands/*.md; do
    [ -f "$f" ] || continue
    if grep -q '^model: claude-fable-5[[:space:]]*$' "$f"; then
        sed -i 's/^model: claude-fable-5[[:space:]]*$/model: fable/' "$f"
        echo "[model] $(basename "$f" .md): claude-fable-5 -> fable (alias follows the latest Fable)"
    fi
done

# Companion commands: newer versions of installed commands call these, and
# --update alone only refreshes files that already exist. Add the missing
# ones on any run so an updated /go never points at a file that is absent.
ensure_cmd() { # $1=command $2=needed by
    [ -f "$DEST/commands/$1.md" ] && return 0
    [ -f "$SCRIPT_DIR/commands/$1.md" ] || return 0
    cp "$SCRIPT_DIR/commands/$1.md" "$DEST/commands/$1.md"
    echo "[new] commands/$1 (used by $2)"
    NEW_CMDS="$NEW_CMDS $1"
}
NEW_CMDS=""
if [ -f "$DEST/commands/go.md" ]; then
    for c in sync next review-deep; do ensure_cmd "$c" /go; done
fi
[ -f "$DEST/commands/task-next.md" ] && ensure_cmd task-auto "bcd --loop"
case " $NEW_CMDS " in *" review-deep "*)
    if grep -q '^model: fable[[:space:]]*$' "$DEST/commands/review-code.md" 2>/dev/null; then
        echo "[cost] /review-code runs after every task and is still on fable in this project."
        echo "       /review-deep (fable) now covers critical tasks; to put the everyday review"
        echo "       on opus run: blackcat --models balanced"
    fi ;;
esac

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

for d in "$DEST/skills"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    src="$SCRIPT_DIR/skills/$name"
    [ -d "$src" ] || continue
    diff -rq "$src" "$d" >/dev/null 2>&1 || UPDATE_LIST="$UPDATE_LIST skills/$name"
done
# Rules are compared file by file: a project holds only the rule files it
# picked, so a whole-folder diff would always report (and re-add) the rest.
for f in "$DEST"/rules/*/*.md; do
    [ -f "$f" ] || continue
    rel="rules/$(basename "$(dirname "$f")")/$(basename "$f")"
    [ -f "$SCRIPT_DIR/$rel" ] || continue
    cmp -s "$SCRIPT_DIR/$rel" "$f" || UPDATE_LIST="$UPDATE_LIST $rel"
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
