# claude_blackcat

**版本：v26.7.6**（版號規則：`v年.月.當月第幾版`，年取西元後兩碼）

個人 Claude Code 設定同步 repo。全域偏好跟人走（只有 settings + statusline），工作流跟專案走。思想來源與取捨見 [WORKFLOW.md](WORKFLOW.md)。

```
全域（~/.claude/）：settings + statusline + cat 指令        ← 偏好，跟人走
專案（.claude/）  ：1-4 個 skills + 3-5 個 commands         ← 工作流，跟專案走
產出（.claude/）  ：plans/ + sessions/                      ← 記憶，跟專案進 git
```

---

## 安裝

### 全域（每台機器一次）

**Windows**：clone 後直接雙擊 `install.bat`（或在 cmd 執行）。會自動裝 settings + statusline、建立 `cat` 指令並加入 PATH。需要先裝 [Git for Windows](https://git-scm.com/download/win)。

```bat
git clone https://github.com/blackblue-t/claude_blackcat.git
cd claude_blackcat
install.bat
```

**macOS / Linux**：

```bash
git clone https://github.com/blackblue-t/claude_blackcat.git
cd claude_blackcat
bash install.sh     # 建立 blackcat 指令；把 ~/.claude/bin 加進 PATH
```

安裝前會**先清後裝**：把舊版本 repo 裝進 `~/.claude` 的項目（agents、commands、output-styles、rules、hooks、repo 提供的 skills——不論 symlink 或複製的實體目錄）備份到 `~/.claude/backups/<時間戳>/` 後移除。**不會動到**：credentials、projects/、settings.local.json、`.mcp.json`、CLAUDE.md、非本 repo 的 skills（如 ECC 裝的）。安裝腳本輸出全為英文（cmd 對 UTF-8 中文的解析有已知 bug）。

安裝後手動設定：`settings.local.json`（API keys）、`.mcp.json`（每台機器不同）。**不需要安裝 ECC plugin**。

### 專案（在專案目錄一行搞定）

全域裝完後，`cd` 到任何專案目錄：

主指令是 **`blackcat`**，四個環境（cmd / PowerShell / macOS / Linux）打同一個字：

```bat
blackcat --lean       :: 快速迭代工作流
blackcat --strict     :: 正式產品工作流
blackcat --writing    :: 疊加寫作組合（可配任一 preset）
blackcat --taskmaster :: 加裝 TaskMaster
blackcat --list       :: 看全部選項
blackcat --skills django-tdd --agents python-reviewer   :: 手動指定
```

`cat --lean` 是 **cmd 限定**的縮寫（PowerShell 的 `cat` 被內建 Get-Content 別名佔用、macOS/Linux 的 `cat` 是系統指令，都搶不過——`blackcat` 和 `claude` 一樣是沒人佔用的名字，所以到處都通）。

（都是 `install-project.sh` 的捷徑，把當前目錄當目標專案；直接跑 `bash install-project.sh <專案路徑> ...` 效果相同）

| Preset | 適用 | Skills | Commands |
|:--|:--|:--|:--|
| `--lean`（預設） | side project、原型、快速迭代 | ponytail、ponytail-review | /plan /review-code /save-session |
| `--strict` | 正式產品、多人協作 | tdd-workflow、verification-loop | /plan /tdd /verify /review-code /save-session |
| `--writing`（疊加） | 會產出對外文字的專案 | speak-human-tw、humanizer | — |

> lean 和 strict **刻意互斥**：ponytail 的「測試留最小 check」和 tdd-workflow 的「強制 80% 覆蓋率」觸發條件相同、指令互相矛盾，同裝會讓行為不可預測。要混用請自行 `--skills` 指定。`--writing` 則跟兩者都不衝突（不同場域）。

裝完把專案的 `.claude/` 提交進該專案的 git。

---

## 核心工作流

```
研究 → /plan（確認後存檔）→ 實作 → /verify → /save-session
                              │
              lean:  ponytail 階梯（能不寫就不寫）
              strict: /tdd 紅綠重構（80%+ 覆蓋）
```

### 各階段做什麼

**`/plan` — 規劃並存檔。** planner 重述需求、評估風險、拆階段（小任務一兩個 phase 就好）。你確認前不寫任何檔案；確認後寫入 `.claude/plans/<日期>-<slug>.md`，frontmatter 記 `status: active`、`current_phase`、`files`。已有 active 計畫時會先問要不要接續，不疊新計畫。

**實作 — preset 決定哲學。**
- lean：`ponytail` skill 常駐，每個決定過一次階梯（需要存在嗎 → 專案裡有了嗎 → stdlib → 平台原生 → 既有依賴 → 一行 → 最後才寫）
- strict：`/tdd` 開始前自動掃 active 計畫、從 `current_phase` 接續；該階段驗收條件就是 RED 測試目標；每完成一階段更新計畫狀態

**`/verify` — 驗證與歸檔。** 依序跑建置 → 型別 → lint → 測試 → console.log 稽核 → git 狀態，產出 PASS/FAIL 報告。PASS 且計畫全階段完成 → 把計畫 `status` 改 `done`。

**`/save-session` — 收工存檔。** 寫入 `.claude/sessions/<日期>-<主題>.md`：做了什麼、確認可用的（附證據）、**失敗的部分和原因（最重要——沒這段，下個 session 會盲目重試失敗過的路）**、決策理由、具體下一步。

### 跨 session 接續

明天開新 session：Claude 掃到 `plans/` 的 active 計畫和 `sessions/` 昨天的記錄，直接從斷點繼續，不用重新解釋做到哪。

---

## Skills 詳解（22 個）

### 常駐哲學（lean preset）

| Skill | 觸發 | 功能 |
|:--|:--|:--|
| **ponytail** | 任何 coding 任務自動生效；`/ponytail lite\|full\|ultra` 調力度 | 強制最懶可行解。七層 YAGNI 決策階梯，停在第一個成立的層級。修 bug 找 root cause 不貼症狀補丁。信任邊界驗證、資安、資料安全永不簡化。出處：[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) v2.x（MIT） |
| **ponytail-review** | 說「review 過度工程」「能刪什麼」或 `/ponytail-review` | 只抓複雜度的 code review：`delete:`（死碼）`stdlib:`（重造輪子）`native:`（平台原生能做）`yagni:`（單實作抽象）`shrink:`（同邏輯更短）。一行一發現，結尾 `net: -N lines possible.`。正確性 bug 不歸它管，用 `/review-code` |

### 寫作組合（`--writing`）

| Skill | 觸發 | 功能 |
|:--|:--|:--|
| **speak-human-tw** | 說「去 AI 味」「說人話」「這段好 AI」「幫我潤稿」，或檢查電子報/社群貼文/銷售頁/客服回信等對外中文 | 繁中去 AI 味改寫：38 種 AI 痕跡偵測 + **中國用語→台灣用語校正**（60+ 組對照）+ 半形轉全形標點。先列編號清單（原句/原因/建議）等你勾選才動筆，不會直接覆寫檔案。分五種內容情境調整力度。出處：[Raymondhou0917/speak-human-tw](https://github.com/Raymondhou0917/speak-human-tw) v1.4.0（MIT），含 6 個 reference 檔（台灣在地化對照表、保護清單、情境力度表等） |
| **humanizer** | 編修**英文**文字時 | 英文去 AI 味：33 種痕跡（inflated symbolism、em dash 濫用、rule of three、AI 詞彙…），源自 Wikipedia「Signs of AI writing」。絕不添加原文沒有的事實。出處：[blader/humanizer](https://github.com/blader/humanizer) v2.9.1（MIT） |

兩者依語言自動分工：中文找 speak-human-tw，英文找 humanizer，不會打架。

### 工作流（strict preset）

| Skill | 觸發 | 功能 |
|:--|:--|:--|
| **tdd-workflow** | 寫新功能、修 bug、重構時 | 強制先測試後實作，RED→GREEN→REFACTOR，80%+ 覆蓋率（關鍵邏輯 100%） |
| **verification-loop** | 要求驗證、完成階段時 | 建置+型別+lint+測試+安全的完整驗證迴圈 |
| **strategic-compact** | context 快滿時 | 建議在邏輯段落手動 compact，而非任意時點自動壓縮 |

### 語言 / 框架（依專案 `--skills` 選裝）

| 領域 | Skills |
|:--|:--|
| Python | python-patterns（PEP 8、型別）、python-testing（pytest、fixtures） |
| Django | django-patterns（DRF、ORM）、django-tdd、django-verification |
| Rust | rust-patterns（ownership、traits）、rust-testing |
| 前端 | frontend-patterns（React/Next.js）、frontend-slides（HTML 簡報）、e2e-testing（Playwright） |
| 後端 | backend-patterns（Node/Express）、api-design（REST 設計）、mcp-server-patterns（MCP server 開發） |
| 通用 | coding-standards（TS/JS 規範）、ai-regression-testing（AI 輔助開發的回歸測試） |

---

## Commands 詳解（13 個）

### 核心五個（presets 內含）

| 指令 | 用法 |
|:--|:--|
| `/plan` | 規劃並持久化（見上）。`--adhoc` 建立不綁任務的臨時計畫 |
| `/tdd` | 讀取 active 計畫接續 TDD；無計畫且任務不小（≥2 檔或 ≥1h）會建議先 `/plan` |
| `/verify` | 全面驗證。參數：`quick`（建置+型別）/ `full`（預設）/ `pre-commit` / `pre-pr` |
| `/review-code` | 正確性導向的程式碼審查（品質、安全、架構）；跟 `/ponytail-review` 互補 |
| `/save-session` | session 存檔（見上） |

### TaskMaster 系（`--taskmaster` 時）

| 指令 | 用法 |
|:--|:--|
| `/task-init` | 專案初始化，建 WBS 任務清單 |
| `/task-next` | 取下一個優先任務 |
| `/task-status` | 看 WBS 進度與時間追蹤 |
| `/time-log` | 開發時間記錄 |

### 其他（手動 `--commands` 選裝）

| 指令 | 用法 |
|:--|:--|
| `/build-fix` | 建置錯誤快速修復 |
| `/e2e` | Playwright 端到端測試 |
| `/hub-delegate` | 自動匹配最佳 agent 委派任務 |
| `/suggest-mode` | 調整建議密度（HIGH/MEDIUM/LOW/OFF） |

---

## Agents（17）與 Output Styles（15）

皆為選裝庫，預設 preset **不裝**（與 skills 同概念重疊，遵守「同一概念只留一層」）。真的需要再 `--agents` / `--output-styles` 指定：

- **Agents**：planner、architect、tdd-guide、code-reviewer、security-reviewer、build-error-resolver、e2e-runner、refactor-cleaner、doc-updater、docs-lookup、database-reviewer、python/typescript/rust-reviewer、rust/pytorch-build-resolver、chief-of-staff
- **Output Styles**：PRD、BDD、架構、DDD、API 契約、TDD 規格、審查清單、安全清單、DB Schema、Python 實作、前端 BDD、整合契約、資料契約、CI 門檻、Vision（適合要產出規格文件的場合）

---

## TaskMaster 工作流（選裝）

```
/task-init → /task-next → /plan → /tdd → /verify → /task-next（循環）
```

`--taskmaster` 安裝 project-template 的 hooks（session-start / user-prompt-submit / agent-monitor / pre-tool-use / post-write）、coordination（人機協作配置）與專案 settings.json。適合需要 WBS 級任務管理的大專案；小專案用核心工作流就夠。

---

## 全域層細節

**Statusline**：GUNDAM 版多行彩色（模型 │ context │ 目錄+branch │ 時長 │ 花費 + rate limit 進度條）。需要 `jq`，install.sh 會檢查。

**Hooks**：v26.7.3 起全域**零 hooks**。agent-monitor 移至 project-template（`--taskmaster` 時隨專案安裝）；舊版 25+ 個 ECC hooks 已於 v26.7.1 移除。回滾看 git history。

**Rules**：22 個編碼規範文件（common 9 + python/typescript/rust）移到 repo 根目錄 `rules/` 當參考文件庫，不再自動安裝。

**環境變數**：

| 變數 | 值 | 用途 |
|:--|:--|:--|
| `MAX_THINKING_TOKENS` | 10000 | 延伸思考 token 上限 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 50 | 自動壓縮觸發閾值 |

---

## 設定來源

| 來源 | 取了什麼 |
|:--|:--|
| [mattpocock/skills](https://github.com/mattpocock/skills) | 「工作流進專案、複製可客製」架構理念 |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)（MIT） | ponytail、ponytail-review |
| [Raymondhou0917/speak-human-tw](https://github.com/Raymondhou0917/speak-human-tw)（MIT） | speak-human-tw（繁中去 AI 味） |
| [blader/humanizer](https://github.com/blader/humanizer)（MIT） | humanizer（英文去 AI 味） |
| [bheadwei/claude-GUNDAM-zh-tw](https://github.com/bheadwei/claude-GUNDAM-zh-tw) | 計畫持久化、session 記錄機制 |
| [GUNDAM](https://github.com/kuanweic/claude-GUNDAM-zh-tw) | TaskMaster、commands、output-styles、statusline |
| [ECC](https://github.com/affaan-m/everything-claude-code) | agents、部分 skills（已複製進本 repo，不需安裝 plugin） |

---

## 版本歷史

| 版本 | 日期 | 內容 |
|:--|:--|:--|
| **v26.7.6** | 2026-07-27 | 安裝改為「先清後裝」：舊版裝入 `~/.claude` 的管理項目（含 copy 模式的實體目錄）備份後移除，非本 repo 內容不動；install.sh / install-project.sh 全面英文化（避免 cmd 的 UTF-8 解析 bug） |
| **v26.7.5** | 2026-07-27 | 修復 install.bat 中文字元導致 cmd 解析錯位（改純 ASCII，PATH 才能正確寫入）；Windows 增設 `blackcat.cmd` 供 PowerShell 使用（`cat` 被 Get-Content 別名佔用） |
| **v26.7.4** | 2026-07-27 | 修復 Windows 安裝：install.bat 與 cat.cmd 明確使用 Git Bash 完整路徑（避免抓到 System32 的 WSL bash 而報「沒有已安裝的發佈」） |
| **v26.7.3** | 2026-07-27 | 一鍵化：新增 `install.bat`（Windows 雙擊安裝 + 自動加 PATH）與 `cat`/`blackcat` 專案安裝指令；全域縮到只剩 settings + statusline（零 hooks）；rules 移為根目錄參考庫 |
| **v26.7.2** | 2026-07-27 | 新增寫作組合：speak-human-tw v1.4.0 + humanizer v2.9.1、`--writing` 疊加選項；README 全面改寫並導入版號制 |
| **v26.7.1** | 2026-07-27 | 大重構：工作流全域→專案級、install-project.sh 與 lean/strict presets、引入 ponytail、計畫持久化 + /save-session（融合 bheadwei GUNDAM）、移除全部 ECC hooks（settings.json 313→40 行）、WORKFLOW.md |
| v1 | 2026-07 之前 | ECC + GUNDAM 整包疊加時期 |
