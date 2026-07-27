#!/bin/bash

# claude_blackcat global installer
#
# Installs ONLY the global layer: settings.json + statusline-command.sh,
# plus the "blackcat" / "cat" project-installer shims.
#
# Before installing, it cleans up items that OLDER versions of this repo
# put into ~/.claude (agents, commands, output-styles, rules, hooks, and
# repo-provided skills) -- whether they are symlinks or copied directories.
# Everything removed is backed up to ~/.claude/backups/<timestamp>/ first.
#
# It NEVER touches: credentials, projects/, todos/, history, plugins,
# settings.local.json, .mcp.json, CLAUDE.md, or any skill not shipped
# by this repo.
#
# Usage: bash install.sh [--copy]
#   --copy: copy files instead of symlinking (Windows uses copy mode
#           automatically since symlinks need admin rights there)

set -e

# When bash.exe is launched directly (non-login, e.g. from install.bat or
# the blackcat.cmd shim), Git Bash does not put /usr/bin on PATH, so
# coreutils like dirname, cp and sed are all missing. Re-add them here
# using bash builtins only -- this must run before any external command.
for _d in /usr/bin /mingw64/bin /bin; do
    if [ -d "$_d" ]; then
        case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH" ;; esac
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GLOBAL_SRC="$SCRIPT_DIR/global"
MODE="symlink"

detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT) echo "windows" ;;
        Darwin) echo "macos" ;;
        *) echo "linux" ;;
    esac
}

OS_TYPE=$(detect_os)

if [ "$1" = "--copy" ]; then
    MODE="copy"
elif [ "$OS_TYPE" = "windows" ]; then
    MODE="copy"
    echo "[info] Windows detected, using copy mode"
fi

echo "=============================================="
echo "  claude_blackcat installer"
echo "  OS: $OS_TYPE / mode: $MODE"
echo "=============================================="
echo ""

mkdir -p "$CLAUDE_DIR"

BACKUP_DIR="$CLAUDE_DIR/backups/$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$BACKUP_DIR"

# Back up a path into BACKUP_DIR, then remove it.
# Symlinks are just removed (their target is this repo, nothing to lose).
backup_and_remove() {
    local target="$1" name="$2"
    if [ -L "$target" ]; then
        rm -f "$target"
        echo "  [clean] removed symlink: $name"
    elif [ -d "$target" ]; then
        cp -r "$target" "$BACKUP_DIR/$name" 2>/dev/null || true
        rm -rf "$target"
        echo "  [clean] moved to backup: $name"
    elif [ -f "$target" ]; then
        cp "$target" "$BACKUP_DIR/$name" 2>/dev/null || true
        rm -f "$target"
        echo "  [clean] moved to backup: $name"
    fi
}

echo "[1/3] Cleaning items managed by this repo (backup first)..."
# Directories that old versions of this repo installed globally.
for name in agents commands output-styles rules hooks; do
    backup_and_remove "$CLAUDE_DIR/$name" "$name"
done
# Skills: only remove names that this repo ships. Skills installed by
# anything else (e.g. the ECC plugin) are left alone.
if [ -d "$CLAUDE_DIR/skills" ] && [ -d "$SCRIPT_DIR/skills" ]; then
    mkdir -p "$BACKUP_DIR/skills"
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        backup_and_remove "$CLAUDE_DIR/skills/$skill_name" "skills/$skill_name"
    done
fi

echo ""
echo "[2/3] Installing global files (settings + statusline only)..."
install_file() {
    local src="$1" dest="$2" name="$3"
    if [ ! -f "$src" ]; then
        echo "  [skip] $name (source missing)"
        return
    fi
    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        cp "$dest" "$BACKUP_DIR/$name" 2>/dev/null || true
    fi
    rm -f "$dest" 2>/dev/null || true
    if [ "$MODE" = "symlink" ]; then
        ln -sf "$src" "$dest"
        echo "  [link] $name"
    else
        cp "$src" "$dest"
        echo "  [copy] $name"
    fi
}

install_file "$GLOBAL_SRC/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"
install_file "$GLOBAL_SRC/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh" "statusline-command.sh"

echo ""
echo "[3/3] Creating project-installer command..."
BIN_DIR="$CLAUDE_DIR/bin"
mkdir -p "$BIN_DIR"
if [ "$OS_TYPE" = "windows" ]; then
    # Hardcode the full Git Bash path: a bare "bash" resolves to the
    # System32 WSL stub on many machines and fails without a WSL distro.
    BASH_EXE="bash"
    REPO_WIN="$SCRIPT_DIR"
    if command -v cygpath >/dev/null 2>&1; then
        [ -f /usr/bin/bash.exe ] && BASH_EXE="$(cygpath -w /usr/bin/bash.exe)"
        REPO_WIN="$(cygpath -m "$SCRIPT_DIR")"
    fi
    printf '@echo off\r\nset "P=%%cd:\\=/%%"\r\n"%s" "%s/install-project.sh" "%%P%%" %%*\r\n' "$BASH_EXE" "$REPO_WIN" > "$BIN_DIR/blackcat.cmd"
    # "cat" shorthand works in cmd only: PowerShell aliases cat to Get-Content.
    cp "$BIN_DIR/blackcat.cmd" "$BIN_DIR/cat.cmd"
    # dispatcher runs against the current directory, no path argument needed;
    # "bcd" is the short alias for terminal use (inside Claude Code use /dispatch)
    printf '@echo off\r\n"%s" "%s/dispatch.sh" %%*\r\n' "$BASH_EXE" "$REPO_WIN" > "$BIN_DIR/blackcat-dispatch.cmd"
    cp "$BIN_DIR/blackcat-dispatch.cmd" "$BIN_DIR/bcd.cmd"
    echo "  [ok] blackcat (cmd + PowerShell) and cat (cmd only) -> $BIN_DIR"
    echo "  [ok] blackcat-dispatch (alias: bcd) -> $BIN_DIR"
    echo "       install.bat adds this folder to your user PATH"
else
    # "cat" is a system command on macOS/Linux, so the command is blackcat.
    printf '#!/bin/bash\nexec bash "%s/install-project.sh" "$PWD" "$@"\n' "$SCRIPT_DIR" > "$BIN_DIR/blackcat"
    chmod +x "$BIN_DIR/blackcat"
    printf '#!/bin/bash\nexec bash "%s/dispatch.sh" "$@"\n' "$SCRIPT_DIR" > "$BIN_DIR/blackcat-dispatch"
    chmod +x "$BIN_DIR/blackcat-dispatch"
    cp "$BIN_DIR/blackcat-dispatch" "$BIN_DIR/bcd"
    echo "  [ok] blackcat, blackcat-dispatch (alias: bcd) -> $BIN_DIR"
    echo "       make sure ~/.claude/bin is on PATH, e.g. add to ~/.bashrc:"
    echo "       export PATH=\"\$HOME/.claude/bin:\$PATH\""
fi

echo ""
echo "=============================================="
echo "  Install complete."
echo "  Backup: $BACKUP_DIR"
echo ""
echo "  Next, in any project folder run:"
echo "    blackcat --lean     (fast iteration)"
echo "    blackcat --strict   (production TDD)"
echo "    blackcat --list     (all options)"
echo "=============================================="

echo ""
if command -v jq >/dev/null 2>&1; then
    echo "[ok] jq installed ($(jq --version))"
else
    echo "[warn] jq NOT installed -- the statusline needs it."
    if [ "$OS_TYPE" = "windows" ]; then
        echo "       run: winget install jqlang.jq"
    elif [ "$OS_TYPE" = "macos" ]; then
        echo "       run: brew install jq"
    else
        echo "       run: sudo apt install jq   (or dnf/yum)"
    fi
fi
