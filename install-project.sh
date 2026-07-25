#!/bin/bash

# claude_blackcat 專案級安裝腳本
# 把選定的 skills / commands / agents / output-styles 「複製」進目標專案的 .claude/
# （複製而非 symlink：進了專案就屬於專案，可以針對專案自行修改 — 參考 mattpocock/skills 的做法）
#
# 用法:
#   bash install-project.sh <專案路徑>                        # 安裝精選核心組合
#   bash install-project.sh <專案路徑> --all                  # 安裝全部
#   bash install-project.sh <專案路徑> --skills a,b --commands x,y --agents m,n
#   bash install-project.sh <專案路徑> --taskmaster           # 加裝 TaskMaster 工作流（project-template）
#   bash install-project.sh --list                            # 列出可安裝項目

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 精選核心組合（不帶參數時的預設）
CORE_SKILLS="ponytail ponytail-review tdd-workflow verification-loop"
CORE_COMMANDS="plan tdd verify review-code"
CORE_AGENTS=""

list_items() {
    local kind
    for kind in skills commands agents output-styles; do
        echo "── $kind ──"
        if [ "$kind" = "skills" ]; then
            ls "$SCRIPT_DIR/$kind"
        else
            ls "$SCRIPT_DIR/$kind" | sed 's/\.md$//'
        fi
        echo ""
    done
    echo "── 其他 ──"
    echo "--taskmaster  (project-template：TaskMaster hooks + settings + coordination)"
}

if [ "$1" = "--list" ] || [ -z "$1" ]; then
    echo "用法: bash install-project.sh <專案路徑> [--all|--taskmaster|--skills a,b|--commands x,y|--agents m,n|--output-styles p,q]"
    echo ""
    list_items
    exit 0
fi

TARGET="$1"; shift
if [ ! -d "$TARGET" ]; then
    echo "❌ 專案路徑不存在: $TARGET"
    exit 1
fi
DEST="$TARGET/.claude"

ALL=false
TASKMASTER=false
SKILLS="$CORE_SKILLS"
COMMANDS="$CORE_COMMANDS"
AGENTS="$CORE_AGENTS"
STYLES=""

while [ $# -gt 0 ]; do
    case "$1" in
        --all) ALL=true ;;
        --taskmaster) TASKMASTER=true ;;
        --skills) SKILLS="${2//,/ }"; shift ;;
        --commands) COMMANDS="${2//,/ }"; shift ;;
        --agents) AGENTS="${2//,/ }"; shift ;;
        --output-styles) STYLES="${2//,/ }"; shift ;;
        *) echo "❌ 未知參數: $1"; exit 1 ;;
    esac
    shift
done

if [ "$ALL" = true ]; then
    SKILLS=$(ls "$SCRIPT_DIR/skills")
    COMMANDS=$(ls "$SCRIPT_DIR/commands" | sed 's/\.md$//')
    AGENTS=$(ls "$SCRIPT_DIR/agents" | sed 's/\.md$//')
    STYLES=$(ls "$SCRIPT_DIR/output-styles" | grep '\.md$' | sed 's/\.md$//')
fi

mkdir -p "$DEST"
echo "📂 安裝到 $DEST"

# skill 目錄整個複製；已存在則保留（專案可能已客製）
for s in $SKILLS; do
    src="$SCRIPT_DIR/skills/$s"
    if [ ! -d "$src" ]; then echo "  ⏭️  skills/$s（不存在）"; continue; fi
    if [ -d "$DEST/skills/$s" ]; then echo "  ✅ skills/$s（已存在，保留）"; continue; fi
    mkdir -p "$DEST/skills"
    cp -r "$src" "$DEST/skills/$s"
    echo "  📋 skills/$s"
done

install_md() {
    local kind="$1" name="$2"
    local src="$SCRIPT_DIR/$kind/$name.md"
    if [ ! -f "$src" ]; then echo "  ⏭️  $kind/$name（不存在）"; return; fi
    if [ -f "$DEST/$kind/$name.md" ]; then echo "  ✅ $kind/$name（已存在，保留）"; return; fi
    mkdir -p "$DEST/$kind"
    cp "$src" "$DEST/$kind/$name.md"
    echo "  📋 $kind/$name"
}

for c in $COMMANDS; do install_md commands "$c"; done
for a in $AGENTS; do install_md agents "$a"; done
for o in $STYLES; do install_md output-styles "$o"; done

if [ "$TASKMASTER" = true ]; then
    echo ""
    echo "📂 安裝 TaskMaster 工作流（project-template）..."
    for item in hooks coordination context taskmaster-data logs; do
        src="$SCRIPT_DIR/project-template/$item"
        [ -d "$src" ] || continue
        if [ -d "$DEST/$item" ]; then echo "  ✅ $item（已存在，保留）"; continue; fi
        cp -r "$src" "$DEST/$item"
        echo "  📋 $item"
    done
    if [ ! -f "$DEST/settings.json" ]; then
        cp "$SCRIPT_DIR/project-template/settings.json" "$DEST/settings.json"
        echo "  📋 settings.json"
    else
        echo "  ✅ settings.json（已存在，保留 — TaskMaster hooks 需自行合併）"
    fi
fi

echo ""
echo "✅ 完成。建議把 .claude/ 提交進該專案的 git，之後針對專案客製直接改專案內的檔案。"
