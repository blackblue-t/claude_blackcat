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
#   DISPATCH_PERMISSIONS=acceptEdits   # or: skip
#     acceptEdits: file edits auto-approved; Bash commands still need
#       project-level permission allowlists (git commit may be blocked
#       unless the project allows it -- see README)
#     skip: --dangerously-skip-permissions; full autonomy INSIDE the
#       worktree. More capable, use only in projects you trust.
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
DISPATCH_PERMISSIONS="acceptEdits"
[ -f "$CONF" ] && . "$CONF"

MODE="run"
DRY=false
SAVE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --max) MAX_PARALLEL="$2"; shift ;;
        --model) DISPATCH_MODEL="$2"; shift ;;
        --save) SAVE=true ;;
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
    echo "[status] base branch: $BASE_BRANCH / max parallel: $MAX_PARALLEL"
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

if [ "$DRY" = true ]; then
    for t in $TASKS; do
        slug="$(basename "$t" .md)"
        m="$(task_meta "$t" model)"; [ -n "$m" ] || m="$DISPATCH_MODEL"
        echo "  [would run] $slug  (model: $m, files: $(task_meta "$t" files))"
    done
    exit 0
fi

PERM_FLAGS="--permission-mode acceptEdits"
[ "$DISPATCH_PERMISSIONS" = "skip" ] && PERM_FLAGS="--dangerously-skip-permissions"

mkdir -p "$LOG_DIR" "$WT_ROOT"

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
            || { echo "  [error] $slug: cannot create worktree"; return 0; }
    fi
    echo "  [launch] $slug -> $branch (model: $model, log: .claude/dispatch-logs/$slug.log)"
    (
        cd "$wt" && claude -p "$(printf '%s' "\
You are executing ONE isolated task in a dedicated git worktree on branch $branch.
Read .claude/tasks/$slug.md and execute exactly that task -- nothing else.
Rules:
1. Only modify files listed in the task's 'files:' line, plus the task file itself and .claude/worklog.d/.
2. Record your work in .claude/worklog.d/$slug.md (sections: files / did / why / verify), creating the directory if needed.
3. Run the verification steps listed in the task and record real results.
4. Change 'status: pending' to 'status: done' in .claude/tasks/$slug.md when (and only when) verification passes.
5. git add your changed files and git commit on this branch with a conventional message. Do NOT push. Do NOT merge. Do NOT switch branches.")" \
            --model "$model" $PERM_FLAGS
    ) > "$LOG_DIR/$slug.log" 2>&1 &
}

active=0
for t in $TASKS; do
    while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do
        wait -n || true
    done
    launch_task "$t"
done
wait || true

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
