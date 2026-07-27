#!/bin/bash

# claude_blackcat 全域安裝腳本
# 只安裝真正全域的東西：settings.json + statusline
# 並建立 cat（Windows）/ blackcat（macOS/Linux）指令，讓你在任何專案目錄
# 一行裝好專案工作流：cat --lean / cat --strict / cat --writing
#
# 用法: bash install.sh [--copy]
#   --copy: 使用複製而非 symlink（Windows 自動使用 copy 模式）

set -e

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
    echo "⚠️  偵測到 Windows 環境，自動切換為 copy 模式"
fi

echo "╭─────────────────────────────────────────╮"
echo "│  claude_blackcat 安裝程式               │"
echo "│  系統: $OS_TYPE / 模式: $MODE           │"
echo "╰─────────────────────────────────────────╯"
echo ""

mkdir -p "$CLAUDE_DIR"

# 備份現有設定
BACKUP_DIR="$CLAUDE_DIR/backups/$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$BACKUP_DIR"

install_file() {
    local src="$1" dest="$2" name="$3"
    if [ ! -f "$src" ]; then
        echo "  ⏭️  跳過 $name（來源不存在）"
        return
    fi
    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        cp "$dest" "$BACKUP_DIR/$name" 2>/dev/null || true
    fi
    rm -f "$dest" 2>/dev/null || true
    if [ "$MODE" = "symlink" ]; then
        ln -sf "$src" "$dest"
        echo "  🔗 $name → symlink"
    else
        cp "$src" "$dest"
        echo "  📋 $name → 複製"
    fi
}

echo "📄 安裝全域設定（只有 settings + statusline）..."
install_file "$GLOBAL_SRC/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"
install_file "$GLOBAL_SRC/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh" "statusline-command.sh"

# 清理舊版全域安裝：只移除指向本 repo 的 symlink，不動使用者自己的東西
echo ""
echo "🧹 清理舊版指向本 repo 的 symlinks..."
for target in "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/output-styles" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"/*; do
    [ -L "$target" ] || continue
    resolved=$(readlink "$target")
    case "$resolved" in
        "$SCRIPT_DIR"/*)
            rm -f "$target"
            echo "  🗑️  移除 ${target/#$HOME/\~}（原指向本 repo）"
            ;;
    esac
done

# ── cat / blackcat 指令（專案工作流一鍵安裝）──────────────
BIN_DIR="$CLAUDE_DIR/bin"
mkdir -p "$BIN_DIR"
if [ "$OS_TYPE" = "windows" ]; then
    # cmd 用：cat --lean / cat --strict（%cd% 轉正斜線給 bash）
    printf '@echo off\r\nset "P=%%cd:\\=/%%"\r\nbash "%s/install-project.sh" "%%P%%" %%*\r\n' "$SCRIPT_DIR" > "$BIN_DIR/cat.cmd"
    echo ""
    echo "✅ 已建立 cat 指令：$BIN_DIR/cat.cmd"
    echo "   （install.bat 會自動把 %USERPROFILE%\\.claude\\bin 加入 PATH）"
else
    # macOS/Linux 的 cat 是系統指令不能覆蓋，改叫 blackcat
    printf '#!/bin/bash\nexec bash "%s/install-project.sh" "$PWD" "$@"\n' "$SCRIPT_DIR" > "$BIN_DIR/blackcat"
    chmod +x "$BIN_DIR/blackcat"
    echo ""
    echo "✅ 已建立 blackcat 指令：$BIN_DIR/blackcat"
    echo "   請確認 PATH 包含 ~/.claude/bin，例如在 ~/.bashrc 或 ~/.zshrc 加："
    echo "   export PATH=\"\$HOME/.claude/bin:\$PATH\""
fi

echo ""
echo "╭─────────────────────────────────────────╮"
echo "│  ✅ 安裝完成！                          │"
echo "│  備份位置: $BACKUP_DIR"
echo "│                                         │"
echo "│  之後在專案目錄執行：                   │"
echo "│    cat --lean     （Windows cmd）       │"
echo "│    blackcat --lean（macOS/Linux）       │"
echo "╰─────────────────────────────────────────╯"

# jq 檢查（statusline 必需）
echo ""
if command -v jq >/dev/null 2>&1; then
    echo "✅ jq 已安裝 ($(jq --version))"
else
    echo "⚠️  jq 未安裝！statusline 需要 jq。"
    if [ "$OS_TYPE" = "windows" ]; then
        echo "   請執行: winget install jqlang.jq"
    elif [ "$OS_TYPE" = "macos" ]; then
        echo "   請執行: brew install jq"
    else
        echo "   請執行: sudo apt install jq  或  sudo dnf install jq"
    fi
fi
