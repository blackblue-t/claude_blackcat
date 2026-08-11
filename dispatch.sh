#!/bin/bash

# claude_blackcat parallel task dispatcher
#
# Runs plan-exported tasks (.claude/tasks/*.md) as INDEPENDENT headless
# Claude sessions, each in its own git worktree on its own branch. This is
# deliberate context isolation: no shared session, no sub-agent results
# piling up in one context window, no re-reading the same background.
#
# Usage (run from inside the project):
#   blackcat-dispatch                 # run all pending tasks
#   blackcat-dispatch --max 3         # limit concurrent sessions (this run)
#   blackcat-dispatch --max 3 --save  # ...and persist to .claude/dispatch.conf
#   blackcat-dispatch --dry-run       # list what would run, launch nothing
#   blackcat-dispatch --status        # show task/branch states
#   blackcat-dispatch --merge         # merge finished task branches into current branch
#   blackcat-dispatch --clean         # remove merged worktrees + branches
#
# Config (.claude/dispatch.conf, shell syntax):
#   MAX_PARALLEL=2            # max concurrent sessions (default 2)
#   DISPATCH_MODEL=opus       # default model for task sessions
#   DISPATCH_WINDOW=0         # 1 (or --windows): open each task in a real
#                             # terminal window titled "bc-<slug>" so you can
#                             # watch sessions live without mixing them up;
#                             # window closes on success, stays open on error
#   DISPATCH_PERMISSIONS=skip # or: acceptEdits
#     skip (default): --dangerously-skip-permissions. Full autonomy inside
#       the worktree. Field-tested rationale: acceptEdits blocks running
#       verification commands, git add/commit, and .claude/ writes, so
#       honest agents deadlock in status: pending and the dispatcher never
#       returns. The real safety gates are elsewhere: file-scope rule in
#       the task, review gate before main, and no push ever.
#     acceptEdits: file edits auto-approved but command execution blocked
#       unless the project allowlists it. Only for untrusted projects;
#       expect tasks to stall unless allowlists cover the verify commands.
#
# Task file format (.claude/tasks/<slug>.md), written by /plan:
#   ---
#   branch: task/<slug>
#   files: src/a.py, tests/test_a.py
#   model: opus          # optional, overrides DISPATCH_MODEL
#   status: pending      # pending -> done (set by the task session)
#   ---
#   # task description, acceptance criteria, verification commands

set -e

for _d in /usr/bin /mingw64/bin /bin; do
    if [ -d "$_d" ]; then
        case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH" ;; esac
    fi
done

PROJ="$PWD"
TASKS_DIR="$PROJ/.claude/tasks"
CONF="$PROJ/.claude/dispatch.conf"
LOG_DIR="$PROJ/.claude/dispatch-logs"

MAX_PARALLEL=2
DISPATCH_MODEL="opus"
DISPATCH_PERMISSIONS="skip"
DISPATCH_WINDOW=0
[ -f "$CONF" ] && . "$CONF"

MODE="run"
DRY=false
SAVE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --max) MAX_PARALLEL="$2"; shift ;;
        --model) DISPATCH_MODEL="$2"; shift ;;
        --save) SAVE=true ;;
        --windows) DISPATCH_WINDOW=1 ;;
        --dry-run) DRY=true ;;
        --status) MODE="status" ;;
        --merge) MODE="merge" ;;
        --clean) MODE="clean" ;;
        -h|--help) sed -n '3,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "[error] unknown option: $1"; exit 1 ;;
    esac
    shift
done

git -C "$PROJ" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "[error] not a git repository: $PROJ"; exit 1; }

if [ "$SAVE" = true ]; then
    mkdir -p "$PROJ/.claude"
    {
        echo "MAX_PARALLEL=$MAX_PARALLEL"
        echo "DISPATCH_MODEL=$DISPATCH_MODEL"
        echo "DISPATCH_PERMISSIONS=$DISPATCH_PERMISSIONS"
        echo "DISPATCH_WINDOW=$DISPATCH_WINDOW"
    } > "$CONF"
    echo "[conf] saved to $CONF"
fi

BASE_BRANCH="$(git -C "$PROJ" branch --show-current)"
WT_ROOT="$(dirname "$PROJ")/$(basename "$PROJ")-worktrees"

task_meta() { # $1=file $2=key
    grep -m1 "^$2: " "$1" | sed "s/^$2: //" || true
}

pending_tasks() {
    [ -d "$TASKS_DIR" ] || return 0
    for t in "$TASKS_DIR"/*.md; do
        [ -f "$t" ] || continue
        [ "$(task_meta "$t" status)" = "pending" ] && echo "$t"
    done
}

branch_done() { # non-empty commits on task branch beyond base
    [ -n "$(git -C "$PROJ" log --oneline "$BASE_BRANCH..$1" 2>/dev/null)" ]
}

# ---------------------------------------------------------------- status ----
if [ "$MODE" = "status" ]; then
    echo "[status] base branch: $BASE_BRANCH / configured max: $MAX_PARALLEL (conf/default)"
    if [ -f "$LOG_DIR/last-run.info" ]; then
        echo "[status] last run actual values:"
        sed 's/^/    /' "$LOG_DIR/last-run.info"
    fi
    [ -d "$TASKS_DIR" ] || { echo "  no .claude/tasks/ directory"; exit 0; }
    for t in "$TASKS_DIR"/*.md; do
        [ -f "$t" ] || continue
        slug="$(basename "$t" .md)"
        branch="$(task_meta "$t" branch)"; [ -n "$branch" ] || branch="task/$slug"
        st="$(task_meta "$t" status)"
        extra=""
        branch_done "$branch" && extra=" (branch has commits)"
        [ -d "$WT_ROOT/$slug" ] && extra="$extra [worktree active]"
        echo "  $slug: $st$extra"
    done
    exit 0
fi

# ----------------------------------------------------------------- merge ----
if [ "$MODE" = "merge" ]; then
    echo "[merge] merging finished task branches into $BASE_BRANCH"
    merged=0
    for t in "$TASKS_DIR"/*.md; do
        [ -f "$t" ] || continue
        slug="$(basename "$t" .md)"
        branch="$(task_meta "$t" branch)"; [ -n "$branch" ] || branch="task/$slug"
        branch_done "$branch" || { echo "  [skip] $slug (no commits on $branch)"; continue; }
        echo "  [merge] $branch"
        if ! git -C "$PROJ" merge --no-ff --no-edit "$branch"; then
            echo ""
            echo "[stop] merge conflict on $branch. Resolve it (a Claude session"
            echo "       can help), commit, then re-run: blackcat-dispatch --merge"
            exit 1
        fi
        merged=$((merged+1))
    done
    echo "[merge] done ($merged branches). Next: open a FRESH session and run"
    echo "        /review-code, then /commit. Clean up with: blackcat-dispatch --clean"
    exit 0
fi

# ----------------------------------------------------------------- clean ----
if [ "$MODE" = "clean" ]; then
    echo "[clean] removing worktrees and merged task branches"
    for t in "$TASKS_DIR"/*.md; do
        [ -f "$t" ] || continue
        slug="$(basename "$t" .md)"
        branch="$(task_meta "$t" branch)"; [ -n "$branch" ] || branch="task/$slug"
        if [ -d "$WT_ROOT/$slug" ]; then
            git -C "$PROJ" worktree remove --force "$WT_ROOT/$slug" 2>/dev/null \
                && echo "  [rm] worktree $slug" \
                || echo "  [warn] could not remove worktree $slug"
        fi
        if git -C "$PROJ" branch -d "$branch" >/dev/null 2>&1; then
            echo "  [rm] branch $branch"
        elif git -C "$PROJ" show-ref --verify --quiet "refs/heads/$branch"; then
            echo "  [keep] branch $branch (not merged; delete manually with -D if abandoned)"
        fi
    done
    rmdir "$WT_ROOT" 2>/dev/null || true
    exit 0
fi

# ------------------------------------------------------------------- run ----
command -v claude >/dev/null 2>&1 || {
    echo "[error] claude CLI not found on PATH"; exit 1; }

TASKS="$(pending_tasks)"
if [ -z "$TASKS" ]; then
    echo "[run] no pending tasks in .claude/tasks/ -- generate them with /plan first"
    exit 0
fi

COUNT=$(echo "$TASKS" | wc -l)
echo "[run] $COUNT pending task(s), max $MAX_PARALLEL concurrent, model default: $DISPATCH_MODEL"
echo "      permissions: $DISPATCH_PERMISSIONS / base: $BASE_BRANCH"

# Never dispatch straight off main/master: tasks would merge into main
# BEFORE review. An integration branch is created instead -- review happens
# there, and /commit merges it back into main only after verdict: pass.
NEED_INT=false
if [ "$BASE_BRANCH" = "main" ] || [ "$BASE_BRANCH" = "master" ]; then
    NEED_INT=true
fi

if [ "$DRY" = true ]; then
    # dry-run is strictly read-only: no branch creation, no HEAD switch.
    if [ "$NEED_INT" = true ]; then
        echo "  [note] on $BASE_BRANCH: a real run would first create integration"
        echo "         branch integrate/<timestamp> and switch to it ($BASE_BRANCH"
        echo "         stays clean until /review-code passes and /commit merges back)"
    fi
    for t in $TASKS; do
        slug="$(basename "$t" .md)"
        m="$(task_meta "$t" model)"; [ -n "$m" ] || m="$DISPATCH_MODEL"
        echo "  [would run] $slug  (model: $m, files: $(task_meta "$t" files))"
    done
    exit 0
fi

if [ "$NEED_INT" = true ]; then
    INT_BRANCH="integrate/$(date +%Y%m%d-%H%M%S)"
    git -C "$PROJ" switch -c "$INT_BRANCH" >/dev/null 2>&1 || {
        echo "[error] could not create integration branch $INT_BRANCH"; exit 1; }
    echo "[branch] on $BASE_BRANCH -- created integration branch $INT_BRANCH"
    echo "         (tasks branch from and merge back into it; $BASE_BRANCH stays"
    echo "         clean until /review-code passes and /commit merges it back)"
    BASE_BRANCH="$INT_BRANCH"
fi

if [ "$DISPATCH_PERMISSIONS" = "skip" ]; then
    PERM_FLAGS="--dangerously-skip-permissions"
    echo "[perm] skip: sessions run fully autonomous inside their worktrees"
    echo "       (safety gates: task file-scope rule, review gate, no push)"
else
    PERM_FLAGS="--permission-mode acceptEdits"
    echo "[perm] WARNING: acceptEdits blocks command execution (verify commands,"
    echo "       git add/commit, .claude/ writes) unless the project allowlists"
    echo "       them -- tasks may deadlock in pending. Set"
    echo "       DISPATCH_PERMISSIONS=skip in .claude/dispatch.conf for autonomy."
fi

mkdir -p "$LOG_DIR" "$WT_ROOT"
{
    echo "started: $(date '+%F %T')"
    echo "max: $MAX_PARALLEL"
    echo "model-default: $DISPATCH_MODEL"
    echo "permissions: $DISPATCH_PERMISSIONS"
    echo "window-mode: $DISPATCH_WINDOW"
    echo "base: $BASE_BRANCH"
} > "$LOG_DIR/last-run.info"

task_prompt() { # $1=slug $2=branch
    printf '%s' "\
You are executing ONE isolated task in a dedicated git worktree on branch $2.
Read .claude/tasks/$1.md and execute exactly that task -- nothing else.
Rules:
0. Follow this project's installed skills and coding rules (.claude/skills/, CLAUDE.md imports) -- e.g. if tdd-workflow is installed, work test-first.
1. Only modify files listed in the task's 'files:' line, plus the task file itself and .claude/worklog.d/.
2. Record your work in .claude/worklog.d/$1.md (sections: files / did / why / verify), creating the directory if needed.
3. Run the verification steps listed in the task and record real results.
4. Change 'status: pending' to 'status: done' in .claude/tasks/$1.md when (and only when) verification passes.
5. git add your changed files and git commit on this branch with a conventional message. Do NOT push. Do NOT merge. Do NOT switch branches."
}

spawn_window() { # $1=title $2=runner script path
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            local wbash wrun
            wbash="$(cygpath -w /usr/bin/bash.exe 2>/dev/null || echo bash)"
            wrun="$(cygpath -w "$2" 2>/dev/null || echo "$2")"
            if command -v wt.exe >/dev/null 2>&1; then
                wt.exe new-tab --title "$1" -- "$wbash" "$wrun" >/dev/null 2>&1 &
            else
                cmd //c start "$1" "$wbash" "$wrun" >/dev/null 2>&1 &
            fi
            ;;
        Darwin)
            osascript -e "tell application \"Terminal\" to do script \"bash '$2'\"" >/dev/null 2>&1 &
            ;;
        *)
            if command -v gnome-terminal >/dev/null 2>&1; then
                gnome-terminal --title "$1" -- bash "$2" >/dev/null 2>&1 &
            elif command -v xterm >/dev/null 2>&1; then
                xterm -T "$1" -e bash "$2" >/dev/null 2>&1 &
            else
                echo "  [warn] no terminal emulator found -- running this task headless"
                bash "$2" >/dev/null 2>&1 &
            fi
            ;;
    esac
}

launch_task() { # $1=task file
    local t="$1"
    local slug branch model wt
    slug="$(basename "$t" .md)"
    branch="$(task_meta "$t" branch)"; [ -n "$branch" ] || branch="task/$slug"
    model="$(task_meta "$t" model)"; [ -n "$model" ] || model="$DISPATCH_MODEL"
    wt="$WT_ROOT/$slug"
    if [ ! -d "$wt" ]; then
        git -C "$PROJ" worktree add -b "$branch" "$wt" "$BASE_BRANCH" >/dev/null 2>&1 \
            || git -C "$PROJ" worktree add "$wt" "$branch" >/dev/null 2>&1 \
            || { echo "  [error] $slug: cannot create worktree"; touch "$LOG_DIR/$slug.done"; return 0; }
    fi
    if [ "$DISPATCH_WINDOW" = 1 ]; then
        echo "  [window] $slug -> $branch (model: $model, title: bc-$slug)"
        task_prompt "$slug" "$branch" > "$LOG_DIR/$slug.prompt"
        # Runner script avoids nested-quoting hell across cmd/wt/osascript.
        # Sets the terminal title, runs the session, drops a .done sentinel;
        # window closes on success and stays open for inspection on error.
        cat > "$LOG_DIR/$slug.run.sh" <<RUNNER
#!/bin/bash
printf '\033]0;bc-$slug\007'
cd "$wt" || { echo "[error] cannot cd to worktree"; read -r; exit 1; }
claude -p "\$(cat "$LOG_DIR/$slug.prompt")" --model "$model" $PERM_FLAGS 2>&1 | tee "$LOG_DIR/$slug.log"
rc=\${PIPESTATUS[0]}
touch "$LOG_DIR/$slug.done"
if [ "\$rc" != 0 ]; then
    echo ""
    echo "[bc-$slug] session exited with code \$rc -- press Enter to close"
    read -r
fi
RUNNER
        chmod +x "$LOG_DIR/$slug.run.sh"
        spawn_window "bc-$slug" "$LOG_DIR/$slug.run.sh"
    else
        echo "  [launch] $slug -> $branch (model: $model, log: .claude/dispatch-logs/$slug.log)"
        (
            cd "$wt" && claude -p "$(task_prompt "$slug" "$branch")" \
                --model "$model" $PERM_FLAGS
            touch "$LOG_DIR/$slug.done"
        ) > "$LOG_DIR/$slug.log" 2>&1 &
    fi
}

# Pool control is sentinel-based (.done files) so it works for both modes:
# windowed sessions are detached processes we cannot wait(1) on.
rm -f "$LOG_DIR"/*.done "$LOG_DIR"/*.run.sh "$LOG_DIR"/*.prompt 2>/dev/null || true
done_count() { ls "$LOG_DIR"/*.done 2>/dev/null | wc -l; }

LAUNCHED=0
for t in $TASKS; do
    while [ $((LAUNCHED - $(done_count))) -ge "$MAX_PARALLEL" ]; do
        sleep 5
    done
    launch_task "$t"
    LAUNCHED=$((LAUNCHED+1))
done
while [ "$(done_count)" -lt "$LAUNCHED" ]; do
    sleep 5
done
wait 2>/dev/null || true

echo ""
echo "[run] all sessions finished. Results:"
ok=0; bad=0
for t in $TASKS; do
    slug="$(basename "$t" .md)"
    branch="$(task_meta "$t" branch)"; [ -n "$branch" ] || branch="task/$slug"
    if branch_done "$branch"; then
        echo "  [done] $slug ($(git -C "$PROJ" log --oneline "$BASE_BRANCH..$branch" | wc -l) commit(s) on $branch)"
        ok=$((ok+1))
    else
        echo "  [FAIL] $slug -- no commits; see .claude/dispatch-logs/$slug.log"
        bad=$((bad+1))
    fi
done
echo ""
echo "[next] $ok done, $bad failed."
echo "       Merge:  blackcat-dispatch --merge"
echo "       Review: open a FRESH session, run /review-code, then /commit"
echo "       Clean:  blackcat-dispatch --clean"
