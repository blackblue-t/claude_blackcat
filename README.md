# claude_blackcat

個人 Claude Code 設定同步 repo。

## 設計原則（v2 重構）

參考 [mattpocock/skills](https://github.com/mattpocock/skills) 的做法：

- **全域（`~/.claude/`）只放「偏好」**：settings、statusline、hooks、編碼規範。跟著人走，每台機器一樣。
- **工作流放「專案」**：skills / commands / agents / output-styles 用 `install-project.sh` **複製**進各專案的 `.claude/`，跟著專案走、可以針對專案客製、隨專案進 git。
- 複製而非 symlink：進了專案就屬於專案，改了不會污染其他專案。

## 目錄結構

```
claude_blackcat/
├── install.sh              # 全域安裝：settings + statusline + hooks + rules
├── install-project.sh      # 專案安裝：挑選 skills/commands/agents 複製進專案
├── global/                 # → ~/.claude/（只有真正全域的東西）
│   ├── settings.json       # 全域設定模板（__CLAUDE_DIR__ placeholder）
│   ├── statusline-command.sh
│   ├── hooks/              # agent-monitor 等
│   └── rules/              # 編碼規範（common + python + typescript + rust）
├── skills/                 # 專案級 skill 庫（20 個）
├── commands/               # 專案級 slash commands 庫（12 個，繁中）
├── agents/                 # 專案級 agents 庫（17 個）
├── output-styles/          # 專案級輸出模板庫（15 個）
└── project-template/       # TaskMaster 工作流模板（--taskmaster 時安裝）
```

## 安裝

### 全域（每台機器一次）

```bash
git clone https://github.com/blackblue-t/claude_blackcat.git
cd claude_blackcat
bash install.sh          # 自動偵測 OS，Windows 自動使用 copy 模式
```

會自動：偵測 OS、動態替換路徑（`CLAUDE_PLUGIN_ROOT` → 當前機器的 `~/.claude`）、檢查 jq、**清掉舊版指向本 repo 的全域工作流 symlinks**。

安裝後手動設定：`settings.local.json`（API keys）、`.mcp.json`（每台機器不同）、[ECC plugin](https://github.com/affaan-m/everything-claude-code)（settings.json 的多數 hooks 依賴它）。

### 專案（每個專案挑需要的）

```bash
cd claude_blackcat
bash install-project.sh --list                      # 看有什麼可裝
bash install-project.sh ~/code/my-project           # 預設 --lean
bash install-project.sh ~/code/my-project --lean    # 快速迭代：ponytail + ponytail-review + /plan /review-code
bash install-project.sh ~/code/my-project --strict  # 正式產品：tdd-workflow + verification-loop + /plan /tdd /verify /review-code
bash install-project.sh ~/code/my-project --all     # 全部
bash install-project.sh ~/code/my-project --skills django-tdd,django-patterns --agents python-reviewer
bash install-project.sh ~/code/my-project --taskmaster   # 加裝 TaskMaster 工作流
```

> `--lean` 和 `--strict` 刻意分開：ponytail 的「測試留最小 check」和 tdd-workflow 的「強制 80% 覆蓋率」都在任何 coding 任務觸發，同裝會互相矛盾。要混用請自行 `--skills` 指定。

裝完把專案的 `.claude/` 提交進該專案的 git。之後要客製直接改專案內的檔案。

## Skills（20 個）

新增兩個程式碼精簡 skill（來自 [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)，MIT）：

| Skill | 用途 |
|:--|:--|
| **ponytail** | 強制最懶可行解：YAGNI 決策階梯（先問需不需要 → 復用 → stdlib → 平台原生 → 既有依賴 → 一行 → 最後才寫最小實作）。`/ponytail lite\|full\|ultra` |
| **ponytail-review** | 只抓過度工程的 code review：該刪什麼、stdlib 取代什麼、哪個抽象只有一個實作。每個發現一行，結尾給 `net: -N lines possible.` |

既有：api-design、backend-patterns、coding-standards、e2e-testing、frontend-patterns、frontend-slides、mcp-server-patterns、python-patterns、python-testing、rust-patterns、rust-testing、django-patterns、django-tdd、django-verification、ai-regression-testing、strategic-compact、tdd-workflow、verification-loop

## Commands / Agents / Output Styles

皆為**專案級選裝庫**，內容同 v1（GUNDAM TaskMaster 工作流 + ECC agents）：

- **Commands（12）**：`/task-init` `/task-next` `/task-status` `/plan` `/tdd` `/verify` `/build-fix` `/review-code` `/e2e` `/hub-delegate` `/suggest-mode` `/time-log`
- **Agents（17）**：planner、architect、tdd-guide、code-reviewer、security-reviewer、build-error-resolver、e2e-runner、refactor-cleaner、doc-updater、docs-lookup、database-reviewer、python/typescript/rust-reviewer、rust/pytorch-build-resolver、chief-of-staff
- **Output Styles（15）**：PRD、BDD、架構、DDD、API 契約、TDD 規格、審查清單、安全清單、DB Schema、Python 實作、前端 BDD、整合契約、資料契約、CI 門檻、Vision

> 注意：這四層彼此高度重疊（例如 TDD 同時存在於 agent、command、output-style、skill）。專案裝的時候挑**一層**用就好，不要全裝。

## TaskMaster 工作流（選裝）

```
/task-init → /task-next → /plan → /tdd → /verify → /task-next（循環）
```

`install-project.sh <專案> --taskmaster` 會安裝 project-template 的 hooks（session-start / user-prompt-submit / agent-monitor / pre-tool-use / post-write）、coordination、taskmaster-data 與專案 settings.json。

## Statusline

GUNDAM 版多行彩色 statusline（模型 │ context │ 目錄+branch │ 時長 │ 花費 + rate limit 進度條）。需要 `jq`，install.sh 會檢查並提示安裝。

## 全域 Hooks（settings.json）

多數 hooks 依賴 ECC plugin（`CLAUDE_PLUGIN_ROOT`），未裝 ECC 時會靜默失敗或報錯。主要包含：block-no-verify、agent-monitor、suggest-compact、insaits-security、governance-capture、config-protection、quality-gate、observe。

## 環境變數

| 變數 | 值 | 用途 |
|:--|:--|:--|
| `MAX_THINKING_TOKENS` | 10000 | 延伸思考 token 上限 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 50 | 自動壓縮觸發閾值 |
| `CLAUDE_PLUGIN_ROOT` | ~/.claude（安裝時自動設定） | ECC plugin 根目錄 |

## 設定來源

| 來源 | 內容 |
|:--|:--|
| [ECC](https://github.com/affaan-m/everything-claude-code) | agents、hooks、部分 skills |
| [GUNDAM](https://github.com/kuanweic/claude-GUNDAM-zh-tw) | TaskMaster、commands、output-styles、statusline |
| [ponytail](https://github.com/DietrichGebert/ponytail)（MIT） | ponytail、ponytail-review skills |
| [mattpocock/skills](https://github.com/mattpocock/skills) | 「工作流進專案、複製可客製」的架構理念 |
