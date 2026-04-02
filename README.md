# claude_blackcat

個人 Claude Code 設定同步 repo。Clone 後執行 install 即可在任何電腦同步設定。

## 快速安裝

```bash
git clone https://github.com/blackblue-t/claude_blackcat.git
cd claude_blackcat
bash install.sh          # symlink 模式（推薦，改一處全同步）
# bash install.sh --copy # 複製模式（各機獨立）
```

## 結構

```
claude_blackcat/
├── install.sh              # 安裝腳本
├── global/                 # → ~/.claude/ 的內容
│   ├── agents/             # 17 個 Agent 定義
│   ├── rules/              # common + python/typescript/rust 規則
│   ├── skills/             # 11 個精選 Skills
│   ├── commands/           # 12 個繁體中文 Slash Commands
│   ├── hooks/              # Agent 監控 hooks
│   ├── output-styles/      # 15 個結構化輸出模板
│   └── settings.json       # 全域設定
│
└── project-template/       # 新專案的 .claude/ 模板
    ├── settings.json       # 專案設定（含權限和 hooks）
    ├── hooks/              # TaskMaster hooks
    ├── coordination/       # 人機協作配置
    ├── context/            # 跨 Agent 上下文目錄
    ├── taskmaster-data/    # WBS 任務追蹤
    └── logs/               # Agent 活動 log
```

## 新專案使用 project-template

```bash
cd your-project
cp -r /path/to/claude_blackcat/project-template .claude
```

## 安裝後手動設定

1. **settings.local.json** — MCP API keys 等敏感設定（不入 git）
2. **.mcp.json** — MCP server 配置（每台機器不同）
3. **ECC plugin** — 需另外安裝 everything-claude-code

## 核心工作流

```
/task-init → /task-next → /plan → /tdd → /verify → /task-next（循環）
```

| 指令 | 用途 |
|:--|:--|
| `/plan` | 規劃實作步驟 |
| `/tdd` | 測試驅動開發 |
| `/verify` | 全面驗證（建置+型別+lint+測試） |
| `/hub-delegate` | 自動匹配 Agent 委派任務 |
| `/task-init` | 專案初始化（建立 WBS） |
| `/task-next` | 取得下一個任務 |
| `/task-status` | 查看進度 |
| `/suggest-mode` | 調整 Agent 建議密度 |

## 設定來源

- **ECC** (Everything Claude Code) v1.9.0 — agents, hooks, ECC skills
- **GUNDAM** 參考 — TaskMaster 工作流, commands, output-styles, 人機協作
- **個人調整** — MAX_THINKING_TOKENS=25000, Python 優先
