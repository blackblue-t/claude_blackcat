#!/bin/bash

# claude_blackcat 安裝腳本
# 將 repo 中的設定 symlink 到 ~/.claude/
# 用法: bash install.sh [--copy]
#   --copy: 使用複製而非 symlink（不推薦，無法自動同步）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GLOBAL_SRC="$SCRIPT_DIR/global"
MODE="symlink"

if [ "$1" = "--copy" ]; then
    MODE="copy"
fi

echo "╭─────────────────────────────────────────╮"
echo "│  claude_blackcat 安裝程式               │"
echo "│  模式: $MODE                            │"
echo "╰─────────────────────────────────────────╯"
echo ""

# 確保 ~/.claude 存在
mkdir -p "$CLAUDE_DIR"

# 備份現有設定
BACKUP_DIR="$CLAUDE_DIR/backups/$(date '+%Y%m%d_%H%M%S')"
echo "📦 備份現有設定到 $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"

# 安裝函數
install_dir() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -d "$src" ]; then
        echo "  ⏭️  跳過 $name（來源不存在）"
        return
    fi

    # 備份現有目錄
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        cp -r "$dest" "$BACKUP_DIR/$name" 2>/dev/null || true
    fi

    if [ "$MODE" = "symlink" ]; then
        # 移除現有目錄/symlink
        rm -rf "$dest" 2>/dev/null || true
        # 建立 symlink
        ln -sf "$src" "$dest"
        echo "  🔗 $name → symlink"
    else
        rm -rf "$dest" 2>/dev/null || true
        cp -r "$src" "$dest"
        echo "  📋 $name → 複製"
    fi
}

install_file() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -f "$src" ]; then
        echo "  ⏭️  跳過 $name（來源不存在）"
        return
    fi

    # 備份
    if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        cp "$dest" "$BACKUP_DIR/$name" 2>/dev/null || true
    fi

    if [ "$MODE" = "symlink" ]; then
        rm -f "$dest" 2>/dev/null || true
        ln -sf "$src" "$dest"
        echo "  🔗 $name → symlink"
    else
        cp "$src" "$dest"
        echo "  📋 $name → 複製"
    fi
}

echo ""
echo "📂 安裝目錄..."
install_dir "$GLOBAL_SRC/rules" "$CLAUDE_DIR/rules" "rules"
install_dir "$GLOBAL_SRC/agents" "$CLAUDE_DIR/agents" "agents"
install_dir "$GLOBAL_SRC/commands" "$CLAUDE_DIR/commands" "commands"
install_dir "$GLOBAL_SRC/hooks" "$CLAUDE_DIR/hooks" "hooks"
install_dir "$GLOBAL_SRC/output-styles" "$CLAUDE_DIR/output-styles" "output-styles"

echo ""
echo "📂 安裝 skills（合併模式，不覆蓋 ECC skills）..."
if [ -d "$GLOBAL_SRC/skills" ]; then
    for skill_dir in "$GLOBAL_SRC/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        dest_dir="$CLAUDE_DIR/skills/$skill_name"
        if [ ! -d "$dest_dir" ]; then
            if [ "$MODE" = "symlink" ]; then
                ln -sf "$skill_dir" "$dest_dir"
                echo "  🔗 skills/$skill_name → symlink（新增）"
            else
                cp -r "$skill_dir" "$dest_dir"
                echo "  📋 skills/$skill_name → 複製（新增）"
            fi
        else
            echo "  ✅ skills/$skill_name（已存在，保留）"
        fi
    done
fi

echo ""
echo "📄 安裝設定檔..."
install_file "$GLOBAL_SRC/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"
install_file "$GLOBAL_SRC/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh" "statusline-command.sh"

echo ""
echo "╭─────────────────────────────────────────╮"
echo "│  ✅ 安裝完成！                          │"
echo "│                                         │"
echo "│  備份位置: $BACKUP_DIR                  │"
echo "│                                         │"
echo "│  注意事項:                               │"
echo "│  - settings.local.json 需手動設定       │"
echo "│  - MCP API keys 需手動填入 .mcp.json    │"
echo "│  - ECC plugin 需另外安裝                │"
echo "╰─────────────────────────────────────────╯"
