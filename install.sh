#!/bin/bash

# claude_blackcat 安裝腳本
# 將 repo 中的設定安裝到 ~/.claude/
# 用法: bash install.sh [--copy]
#   --copy: 使用複製而非 symlink（不推薦，無法自動同步）
#   Windows 環境下自動使用 copy 模式

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GLOBAL_SRC="$SCRIPT_DIR/global"
MODE="symlink"

# 自動偵測 OS
detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            echo "windows"
            ;;
        Darwin)
            echo "macos"
            ;;
        *)
            echo "linux"
            ;;
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
echo "│  系統: $OS_TYPE                         │"
echo "│  模式: $MODE                            │"
echo "╰─────────────────────────────────────────╯"
echo ""

# 確保 ~/.claude 和子目錄存在
mkdir -p "$CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR/skills"

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

    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        cp -r "$dest" "$BACKUP_DIR/$name" 2>/dev/null || true
    fi

    if [ "$MODE" = "symlink" ]; then
        rm -rf "$dest" 2>/dev/null || true
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

# settings.json：用 awk 動態替換 __CLAUDE_DIR__ 為當前機器的路徑
if [ -f "$GLOBAL_SRC/settings.json" ]; then
    if [ -f "$CLAUDE_DIR/settings.json" ] && [ ! -L "$CLAUDE_DIR/settings.json" ]; then
        cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/settings.json" 2>/dev/null || true
    fi

    awk -v dir="$CLAUDE_DIR" '{gsub(/__CLAUDE_DIR__/, dir); print}' \
        "$GLOBAL_SRC/settings.json" > "$CLAUDE_DIR/settings.json"
    echo "  ✅ settings.json → 已生成（CLAUDE_PLUGIN_ROOT: $CLAUDE_DIR）"
else
    echo "  ⏭️  跳過 settings.json（來源不存在）"
fi

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

# ── jq 檢查（statusline 必需）──────────────────────────
echo ""
if command -v jq >/dev/null 2>&1; then
    echo "✅ jq 已安裝 ($(jq --version))"
else
    echo "⚠️  jq 未安裝！statusline 需要 jq 才能正常顯示。"
    echo ""
    if [ "$OS_TYPE" = "windows" ]; then
        echo "   請執行: winget install jqlang.jq"
    elif [ "$OS_TYPE" = "macos" ]; then
        echo "   請執行: brew install jq"
    else
        echo "   請執行: sudo apt install jq  或  sudo dnf install jq"
    fi
    echo ""
    read -p "   是否現在安裝 jq？(y/N) " install_jq
    if [ "$install_jq" = "y" ] || [ "$install_jq" = "Y" ]; then
        if [ "$OS_TYPE" = "windows" ]; then
            winget install jqlang.jq --accept-package-agreements --accept-source-agreements
        elif [ "$OS_TYPE" = "macos" ]; then
            brew install jq
        else
            sudo apt install -y jq 2>/dev/null || sudo dnf install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null
        fi
        if command -v jq >/dev/null 2>&1; then
            echo "   ✅ jq 安裝成功！"
        else
            echo "   ⚠️  安裝後可能需要重開終端才能使用"
        fi
    fi
fi
