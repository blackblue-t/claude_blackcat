# claude_blackcat

個人 Claude Code 設定同步 repo。Clone 後執行 install 即可在任何電腦同步設定。

## 快速安裝

```bash
git clone https://github.com/blackblue-t/claude_blackcat.git
cd claude_blackcat
bash install.sh          # 自動偵測 OS，Windows 自動使用 copy 模式
# bash install.sh --copy # 強制使用複製模式
```

安裝腳本會自動：
- **偵測作業系統**（Windows / macOS / Linux）
- **Windows 自動切換 copy 模式**（symlink 需管理員權限）
- **動態替換路徑**（`CLAUDE_PLUGIN_ROOT` 自動設為當前機器的 `~/.claude`）
- **檢查 jq 是否安裝**（statusline 必需，未安裝會提示並可一鍵安裝）

### 安裝後手動設定

| 項目 | 說明 |
|:--|:--|
| `settings.local.json` | MCP API keys 等敏感設定（不入 git） |
| `.mcp.json` | MCP server 配置（每台機器不同） |
| ECC plugin | 需另外安裝 [everything-claude-code](https://github.com/affaan-m/everything-claude-code) |

### ECC Plugin 安裝

```bash
cd /tmp
git clone https://github.com/affaan-m/everything-claude-code.git
cd everything-claude-code
bash install.sh python typescript rust   # 依需求選擇語言
```

支援語言：python, typescript, javascript, go, rust, java, kotlin, swift, cpp, csharp, php, perl

## 目錄結構

```
claude_blackcat/
├── install.sh                  # 安裝腳本（自動偵測 OS + 動態路徑替換）
├── global/                     # → ~/.claude/ 的內容
│   ├── settings.json           # 全域設定模板（__CLAUDE_DIR__ placeholder）
│   ├── statusline-command.sh   # 多行彩色 statusline（GUNDAM 版）
│   ├── agents/                 # 17 個 Agent 定義
│   ├── commands/               # 12 個繁體中文 Slash Commands
│   ├── hooks/                  # Agent 監控 hooks
│   ├── output-styles/          # 15 個結構化輸出模板
│   ├── rules/                  # 編碼規範（common + python + typescript + rust）
│   └── skills/                 # 11 個精選 Skills
│
└── project-template/           # 新專案的 .claude/ 模板
    ├── settings.json           # 專案設定（權限 + TaskMaster hooks）
    ├── hooks/                  # TaskMaster hooks（session/prompt/agent/write）
    ├── coordination/           # 人機協作配置（建議模式）
    ├── context/                # 跨 Agent 上下文共享目錄
    ├── taskmaster-data/        # WBS 任務清單和時間追蹤
    └── logs/                   # Agent 活動 log
```

## 多機器同步

`settings.json` 使用 `__CLAUDE_DIR__` 作為路徑 placeholder，安裝時由 `install.sh` 自動替換為當前機器的實際路徑。不再需要手動修改任何路徑。

```
新電腦設定流程：
1. git clone → bash install.sh      （blackcat 設定）
2. git clone → bash install.sh ...  （ECC plugin）
3. 手動設定 settings.local.json + .mcp.json
```

## 核心工作流：TaskMaster

```
/task-init → /task-next → /plan → /tdd → /verify → /task-next（循環）
```

### Slash Commands

| 指令 | 用途 |
|:--|:--|
| `/task-init` | 專案初始化，建立 WBS 任務清單 |
| `/task-next` | 取得下一個優先任務 |
| `/task-status` | 查看 WBS 進度和時間追蹤 |
| `/plan` | 規劃實作步驟（等待確認後才動工） |
| `/tdd` | 測試驅動開發（RED → GREEN → IMPROVE） |
| `/verify` | 全面驗證（建置 + 型別 + lint + 測試 + 安全） |
| `/build-fix` | 建置錯誤快速修復 |
| `/review-code` | 程式碼審查 |
| `/e2e` | 端到端測試 |
| `/hub-delegate` | 自動匹配最佳 Agent 委派任務 |
| `/suggest-mode` | 調整 Agent 建議密度（HIGH/MEDIUM/LOW/OFF） |
| `/time-log` | 開發時間記錄 |

### 新專案使用 TaskMaster

```bash
cd your-project
cp -r /path/to/claude_blackcat/project-template .claude
# 開始：/task-init my-project
```

## Agents（17 個）

| Agent | 用途 |
|:--|:--|
| planner | 功能規劃，建立實作計畫 |
| architect | 系統架構設計，技術決策 |
| tdd-guide | 測試驅動開發，強制先寫測試 |
| code-reviewer | 程式碼審查，品質檢查 |
| security-reviewer | 安全漏洞檢測，OWASP Top 10 |
| build-error-resolver | 建置錯誤快速修復 |
| e2e-runner | 端到端測試（Playwright） |
| refactor-cleaner | 死碼清理，程式碼重構 |
| doc-updater | 文檔和 codemap 更新 |
| docs-lookup | Context7 文檔查詢 |
| database-reviewer | PostgreSQL / Supabase 最佳實踐 |
| python-reviewer | Python 程式碼審查（PEP 8 + 型別） |
| typescript-reviewer | TypeScript 程式碼審查（型別安全） |
| rust-reviewer | Rust 程式碼審查（ownership + lifetime） |
| rust-build-resolver | Rust 建置錯誤修復 |
| pytorch-build-resolver | PyTorch / CUDA 錯誤修復 |
| chief-of-staff | 多頻道通訊分流（email/Slack/LINE） |

## Output Styles（15 個結構化輸出模板）

| # | 模板 | 用途 |
|:--|:--|:--|
| 01 | PRD 產品規格 | 需求文件 |
| 02 | BDD 場景規格 | 行為驅動測試場景 |
| 03 | 架構設計文件 | 系統架構 |
| 04 | DDD 聚合規格 | 領域驅動設計 |
| 05 | API 契約規格 | RESTful API 設計 |
| 06 | TDD 單元規格 | 測試規格 |
| 07 | Code Review 檢查清單 | 程式碼審查 |
| 08 | 安全檢查清單 | OWASP 安全稽核 |
| 09 | 資料庫 Schema 規格 | DB 設計 |
| 10 | Python 後端實作 | Python 開發範本 |
| 11 | 前端元件 BDD | 前端測試 |
| 12 | 整合契約測試 | 微服務契約 |
| 13 | 資料契約演進 | Schema 版本管理 |
| 14 | CI 品質門檻 | CI/CD pipeline |
| 15 | Vision 輸出 | 圖表 / 視覺化描述 |

## Skills（11 個）

| Skill | 用途 |
|:--|:--|
| api-design | RESTful API 設計模式 |
| coding-standards | 編碼規範和命名慣例 |
| e2e-testing | Playwright E2E 測試 |
| frontend-patterns | 前端元件模式 |
| python-patterns | Python 設計模式 |
| python-testing | pytest 測試模式 |
| rust-patterns | Rust 設計模式 |
| rust-testing | Rust 測試模式 |
| strategic-compact | Context window 管理策略 |
| tdd-workflow | TDD 紅綠重構流程 |
| verification-loop | 建置 + 測試驗證迴圈 |

## Rules（編碼規範）

```
rules/
├── common/          # 通用規範（所有語言）
│   ├── agents.md        # Agent 編排策略
│   ├── coding-style.md  # 不可變性、檔案組織、錯誤處理
│   ├── development-workflow.md  # 研究 → 規劃 → TDD → 審查 → 提交
│   ├── git-workflow.md  # Commit 格式、PR 流程
│   ├── hooks.md         # Hook 系統使用
│   ├── patterns.md      # Repository Pattern、API 格式
│   ├── performance.md   # 模型選擇、context 管理
│   ├── security.md      # 安全檢查清單
│   └── testing.md       # 80%+ 覆蓋率、TDD 強制
├── python/          # Python 專屬（PEP 8、pytest、bandit）
├── typescript/      # TypeScript 專屬（strict mode、ESLint）
└── rust/            # Rust 專屬（clippy、ownership patterns）
```

## Statusline

GUNDAM 版多行彩色 statusline，顯示：

```
Opus 4.6 (1M context) │ 43% (439k/1.0m) │ project (main*) │ 4h35m │ $42.84
current ●●●○○○○○○○  28% ⟳ 19:00
weekly  ●●●●●●●●○○  79% ⟳ 03/23 10:00
```

- **第一行**：模型 │ context 使用率 │ 目錄 (git branch) │ session 時長 │ 花費
- **第二行**：5 小時 rate limit 進度條 + 重置時間
- **第三行**：7 天 rate limit 進度條 + 重置時間
- **第四行**（如有）：extra usage 進度條

特色：RGB 彩色、60 秒 API 快取、跨平台 jq 自動搜尋、OAuth token 自動解析

> **注意**：statusline 需要 `jq`。安裝腳本會自動檢查並提示安裝。

## Hooks 系統

### 全域 Hooks（settings.json）

| Hook | 觸發時機 | 用途 |
|:--|:--|:--|
| block-no-verify | PreToolUse:Bash | 禁止 `--no-verify` 跳過 git hooks |
| agent-monitor | PreToolUse/PostToolUse:Agent | 記錄 subagent 啟動和完成 |
| suggest-compact | PreToolUse:Edit/Write | context 接近上限時建議 compact |
| insaits-security | PreToolUse:Bash/Write/Edit | 安全掃描 |
| governance-capture | Pre/PostToolUse | 治理記錄 |
| config-protection | PreToolUse:Write/Edit | 保護設定檔 |
| quality-gate | PostToolUse:Edit/Write | 品質門檻檢查 |
| observe | Pre/PostToolUse:* | 持續學習觀察 |

### 專案 Hooks（project-template）

| Hook | 用途 |
|:--|:--|
| session-start.sh | 恢復 WBS 狀態、歸檔上次 session 時間 |
| user-prompt-submit.sh | 攔截 `/task-*` 指令、提醒 WBS |
| agent-monitor.sh | 記錄 subagent 活動到 logs/ |
| pre-tool-use.sh | 檔案操作前檢查 |
| post-write.sh | 寫入後觸發 WBS 審查提醒 |

## 設定來源

| 來源 | 內容 |
|:--|:--|
| [ECC](https://github.com/affaan-m/everything-claude-code) v1.10.0 | agents, hooks, ECC skills, session lifecycle |
| [GUNDAM](https://github.com/kuanweic/claude-GUNDAM-zh-tw) | TaskMaster 工作流, commands, output-styles, statusline, 人機協作 |
| 個人調整 | MAX_THINKING_TOKENS=25000, Python 優先, SUGGEST_HIGH 預設 |

## 環境變數

| 變數 | 值 | 用途 |
|:--|:--|:--|
| `MAX_THINKING_TOKENS` | 25000 | 延伸思考 token 上限（最大 31999） |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 50 | 自動壓縮觸發閾值 |
| `CLAUDE_PLUGIN_ROOT` | ~/.claude（安裝時自動設定） | ECC plugin 根目錄 |

## 依賴

| 工具 | 用途 | 安裝方式 |
|:--|:--|:--|
| `jq` | statusline JSON 解析 | Windows: `winget install jqlang.jq`、macOS: `brew install jq`、Linux: `apt install jq` |
| `node` | ECC hooks 執行 | https://nodejs.org |
