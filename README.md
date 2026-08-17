# claude_blackcat

**版本：v26.7.38**（版號規則：`v年.月.當月第幾版`，年取西元後兩碼）

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
blackcat --rules python  :: 直接指定編碼規範（common 全部 + 指定語言，不經選單）
blackcat --no-rules   :: 跳過規範選單（CI / 腳本用；非互動環境本來就會自動跳過）
blackcat --taskmaster :: 加裝 TaskMaster
blackcat --update     :: 純更新模式：blackcat repo 更新後，刷新專案裡已裝且有變動的項目
blackcat --usage      :: 用量統計：這個專案的 skills/commands/agents 各用過幾次、哪些裝了沒用過（別名 --skill-freq）
blackcat --graphify   :: 加裝 Graphify 知識圖譜（省 token；需先裝 graphify CLI）
bcd                   :: 並行任務調度（blackcat-dispatch 的短別名；Claude Code 裡用 /dispatch）
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
>
> **切換 preset**：直接在專案裡跑另一個 preset 即可——安裝器會偵測衝突並詢問「Switch to strict? [y/N]」，`y` 就把舊 preset 的 skills 移到 `.claude/backups/preset-switch-<時間戳>/` 再裝新的（留下的舊指令檔如 /tdd 無害，只有被呼叫才作用）。非互動環境只警告不動手。

裝完把專案的 `.claude/` 提交進該專案的 git。

### 模型路由

三段分工：**規劃/審查用 Fable 5、執行用 Opus、機械收尾用 Sonnet**。

**初始化精靈**：專案**第一次**安裝時（模型路由指令剛被複製進去），安裝器會自動跑模型設定精靈——先用 claude CLI 探測 `claude-fable-5` 是否可用（一次極小的 API 呼叫；不可用時 plan/review 預設自動降為 opus），然後逐階段詢問 plan / review / commit / 主迴圈各用哪個模型（Enter 保留預設、可輸入 1-4 或完整模型 ID）。選擇寫進**該專案的**指令副本與 `.claude/settings.json`，所以每個專案可以路由不同。重跑不會再問；想改用 `blackcat --models` 重開精靈。專案自選的模型受更新機制保護：比對時忽略 model 行、更新時保留專案的選擇。

**什麼可以指定模型**（常見誤會：skill 不行）：

| 對象 | 能不能指定 | 怎麼設 |
|:--|:--|:--|
| **Commands**（/plan、/review-code…） | ✅ | 檔案 frontmatter 的 `model:` |
| **Agents**（ui-builder、code-reviewer…） | ✅ | 同上 |
| **Skills**（tdd-workflow、worklog…） | ❌ **沒有這個欄位** | 跟著當下執行的模型跑 |
| 主迴圈 | ✅ | 專案 `.claude/settings.json` → 沒有就用全域 |

**改單一專案**（最常用）：`blackcat --models` 會列出這個專案所有帶模型的指令與現值，輸入編號挑要改的，其餘 Enter 不動：

```
  Current routing:
    1) /clean-plan   sonnet          6) /learn        sonnet
    2) /commit       sonnet          7) /merge        sonnet
    3) /dispatch     sonnet          8) /plan         claude-fable-5
    4) /grill-doc    claude-fable-5  9) /review-code  claude-fable-5
    5) /grill        claude-fable-5 10) main loop     (inherits global)
  Change which? (numbers separated by spaces, Enter = keep all): 8 10
```

也可以直接編輯專案裡的 `.claude/commands/<指令>.md`，改第一行 `model:` 即可——**專案自選的模型受更新機制保護**，`blackcat --update` 會保留不覆蓋。

**改所有未來專案**：改 repo 端的預設值再 `blackcat --update` 同步——`global/settings.json` 的 `"model"`（主迴圈，現為 `opus`）、各 `commands/*.md` 的 frontmatter、各 `agents/*.md` 的 frontmatter。

**臨時換**：session 裡打 `/model` 換整個 session 的主迴圈模型（不影響指令自己的路由）。

執行 → 審查 → 提交靠 **worklog 接力**：執行時 worklog skill 把每個變更（動了哪些檔、做了什麼、驗證結果）追加到專案的 `.claude/worklog.md`；`/review-code` **只讀 worklog + 列出檔案的 git diff**（不掃全專案，Fable 的錢花在刀口上），結論寫回 worklog；`verdict: pass` 後 `/commit` 用 Sonnet 只 stage 紀錄過的檔案、寫 commit message、提交並歸檔 worklog。worklog skill 與 `/commit` 已加入 lean/strict 兩個 preset。

> Fable 5 是 Opus 之上的模型級別、單價較高，所以只配給規劃與審查；用之前先在 CLI 打 `/model` 確認你的方案看得到 `claude-fable-5`，看不到就把兩個 frontmatter 降回 `opus`。
>
> **驗證路由是否生效**：別問模型「你是誰」——session 系統提示詞不隨斜線指令的 `model:` 更新，自報不可靠（實測結論）。要驗就用外部觀測：`/status`、API 用量紀錄，或 dispatcher stdout 的模型回顯（任務層 `model:` 已實測確證生效）。

### 一條龍：`/go`（日常建議入口）

不想站站手打指令，就用 `/go <你的需求>`——它把整條流程串起來，**唯一必停的人工關卡是計畫確認**（業界共識的關卡位置：計畫錯全錯，其他站都可自動）：

```
/go 幫我加上匯出 CSV 功能
  → （需求模糊才問 2-3 題關鍵問題）
  → 計畫呈現 ⏸ 你確認 ← 唯一必停
  → 自動執行（有並行任務走 dispatcher，一般任務直接做，strict 走 TDD）
  → 自動開 headless session 跨 session 審查（不用你開視窗）
  → needs-fix 自動修 + 限縮重審（上限 2 輪）；escalate 停下找你
  → 提交準備完成 → 你看 git log、決定 push
```

`/grill`、`/plan`、`/review-code` 等單站指令保留——要精細控制或補跑某站時用。

**心智模型：「站」和「紀律」是兩種東西。** 站 = 流程走到哪（grill → plan → 執行 → review → commit）；紀律 = 做的時候怎麼做（tdd-workflow、worklog、ponytail、rules），跟著執行走、不是獨立的站。`/tdd` 屬於紀律——不是「拿去 dispatch」，而是 worktree 是專案完整副本、`.claude/` 的 skills 跟著 checkout 過去，**每個並行 session 自己帶著 TDD 紀律做事**（dispatcher 提示詞明確要求遵守專案 skills/rules）。用 /go 之後紀律自動套用，單站指令只在想插手時存在。

### 完整開發流程（v26.7.22 定版）

```
user 提需求（日常直接 /go，以下是它串起來的全圖）
  │
  ▼
/grill（Fable）第一題永遠是範疇分級 scope: demo / mvp / full
  │   拷問深度隨 scope 縮放 → requirements 文件（含交接指紋 3-5 條）
  ▼
/spec（Fable，依 scope）demo 跳過｜mvp 可選 PRD-lite｜full 建議 PRD+BDD
  │   規格先於任務拆解，防範疇蔓延
  ▼
/plan（Fable）架構 + 拆階段；回報指紋命中數
  │   獨立且檔案不重疊的任務 → 匯出 .claude/tasks/（含「完成程序」固定段落）
  │   ⏸ 計畫確認 = /go 全程唯一必停的人工關卡
  ▼
執行（Opus）──兩種形態，/go 自動選：
  │   序列：主 session 直接做（strict 走 TDD 紀律；worklog 記錄每步）
  │   並行：/dispatch 每任務一個 worktree + 分支 + 獨立 session
  │         從 main 出發自動開 integrate/* 整合分支（main 審查前不動）
  │         --windows 開實體終端視窗（標題 bc-<任務>，不搞混、可即時盯）
  │         → /dispatch --merge 合進整合分支（衝突停下協助解）
  ▼
/review-code（Fable，獨立 session——/go 用 headless 自動開）
  │   只讀 worklog(.d) + 列出檔案的 diff，不掃全庫
  │   finding 分級：[fix] 主 session 修（修/審分離）→ 限縮重審，上限 2 輪
  │              [design] 回 /plan｜[requirement] 回 /grill（escalate 必停）
  ▼
/commit（Sonnet）驗 pass 才動：審查修復先在整合分支 commit
  │   → merge --no-ff 回 main → 歸檔 worklog 與完成的計畫/spec（strict 由 /verify 做）
  ▼
user check：git log 確認、push 由你決定 → /dispatch --clean 收 worktree
  └─ 收尾可跑 /learn：把本次教訓蒸餾進 CLAUDE.md（下個 session 不再踩）
     `.claude/` 堆亂了跑 /clean-plan：完成的計畫/任務整包歸檔、爛尾的問你續作或棄置
```

**前端專案**另有三部曲（初始化時選裝或 `blackcat --ui` 隨時加）：`/ui-style`（問答定風格 → DESIGN.md tokens，**品牌色優先**——給 hex 就生成整套色階、語意 tokens、深色版與 WCAG 對比檢查）→ `/ui-site`（IA 契約 + 路由 stubs）→ `/ui-page <路徑>`（單頁深化，委派 ui-builder agent，附風格合規自檢）。裝 UI pack 時會自動抓兩個 skill 進專案 `.claude/skills/`，分工明確：[Hallmark](https://github.com/nutlope/hallmark)（MIT）是**視覺個性層**——20 種主題 + 57 道 slop-test 檢查關，專殺紫漸層和模板臉，另有 `audit`／`study`；[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) 是 **UX 知識庫層**——可查詢的設計資料庫（50+ 風格、97 色盤、57 字體配對、99 條 UX 準則、a11y 檢查），用腳本查詢、context 成本低。優先序：**DESIGN.md 契約永遠最大**，pro-max 是選型時的查詢來源、hallmark 是產出時的反 slop 關卡，查詢結果不得推翻已定案的契約。這兩個外抓 skill 版本停在安裝當下，`blackcat --update` 刻意不碰它們（不是本 repo 的檔案）——要追新版跑 **`blackcat --ui-refresh`**（舊版先備份再重抓）。

**`/verify` vs `/review-code`**（最容易搞混的一對）：verify 問「**跑得起來嗎**」——跑 build/type/lint/test 看紅綠，機械活、用 sonnet、隨時可跑；review-code 問「**寫得對嗎**」——讀 diff 找工具報不出的錯（邏輯漏洞、安全、爛測試），用 Fable、一段工作完成才跑。兩者是**門檻與判斷**的關係：`/review-code` 第 0 步會自己先跑機器檢查，**紅的就停下不審**（建置壞掉的程式碼不值得花貴模型逐行看）。所以你平常不必特地跑 `/verify`，它是給「我只想知道現在有沒有壞」的時刻用的。

**拷問三兄弟**：`/grill`（從零問出需求）、**`/grill-doc <檔案>`**（拿你現成的需求書/規格來拷問——逐條追問模糊、矛盾、缺口，**每談定一題就直接改進文件裡**，不是最後才生一份新的；能自己查證的先查不問你，未決的進文件末尾的清單）、`/grill-ui`（前端小改的八項檢查卡）。三者同一套訪談機制：一次一題、附建議答案、能自答的不打擾你。

**小改動不裸奔**：/go 快車道遇到前端改動會自動過 `/grill-ui` 檢查卡——共用元件波及、元件狀態（hover/empty/loading…）、RWD 爆版、深色對應、tokens 合規、文案與測試、a11y 八項。機制與 /grill 同源：能從 codebase/DESIGN.md 自答的自己查證，真正的決策才問你（一次一題附建議答案，通常 ≤3 題）。也可手動單跑：`/grill-ui 把價格卡改三欄`。**Pencil** 兩種裝法：桌面 app（[pencil.dev](https://pencil.dev)，開 `.pen` 檔自動接上 Claude Code，畫布上直接拖拉調整）或 **pen CLI**（`npm install -g @pencil.dev/cli`，Node 18+，`pen login` 認證）——CLI 是 headless 的同款引擎，能跑 agent、呼叫 MCP 工具、**匯出 PNG/JPEG/WEBP/PDF**，沒有 GUI 也能走「AI 畫 → 出圖給你看 → 文字回饋修改 → 迭代到確認」的畫布先行流程；`blackcat --ui` 會偵測 pen CLI 並給安裝指引。MCP 接線細節見 [pen CLI 文件](https://docs.pencil.dev/for-developers/pen-cli)。**動線驗證**（Figma prototype 的替代）：/ui-site 可產出灰框 HTML 原型——頁面連結真的可點、彈窗真的會開，瀏覽器直接走完整個流程。

**MCP 快速設定**：`templates/mcp.json.windows.example` / `mcp.json.linux-macos.example` 複製到專案根改名 `.mcp.json`、刪掉不用的、填 key 即可（機器特定，勿 commit）。

**為什麼是 worktree 而不是 sub-agent**：sub-agent 的產出全部回堆到主 session 的 context，任務一多就炸，而且每個 sub-agent 要重新讀一遍專案背景。worktree + headless session 是**完全獨立的 context**——互不污染、各自省流，程式碼隔離在各自分支，最後才合併。

**dispatcher 用法**——兩個入口，同一個引擎（`dispatch.sh`）：

- **Claude Code 裡**（推薦）：`/dispatch`。無參數會先 dry-run 給你確認才執行，執行中背景跑並定期回報進度、失敗任務自動摘 log 重點、合併衝突幫你解。參數直通：`/dispatch --max 3`、`/dispatch --merge`。
- **終端機**：短別名 `bcd`（`blackcat-dispatch` 的縮寫，全平台同名）。

```bash
bcd --dry-run       # 預覽會跑哪些任務
bcd                 # 執行全部 pending 任務
bcd --max 3 --save  # 最大同時 session 數，--save 存進 .claude/dispatch.conf
bcd --status        # 看任務/分支狀態
bcd --merge         # 合併完成的任務分支（衝突會停下指路）
bcd --clean         # 移除 worktree、刪已合併分支
```

**併發上限**三個層級：`--max N` 單次生效 → 加 `--save` 寫入專案 `.claude/dispatch.conf`（`MAX_PARALLEL=N`，之後預設沿用）→ 都沒設預設 2。實際執行參數記錄在 `--status` 的 `last run actual values`（設定值與執行值分開顯示）。conf 還可設 `DISPATCH_MODEL`（任務預設模型，個別任務檔 `model:` 可覆蓋）與 `DISPATCH_PERMISSIONS`：

- **`skip`（預設）**= `--dangerously-skip-permissions`，worktree 內全自動。端到端實測的結論：`acceptEdits` 會擋掉驗證指令、`git commit` 和 `.claude/` 寫入，誠實的 agent 全數卡死在 pending、dispatcher 永不返回。真正的安全閘門在流程裡——任務檔案範圍鐵則、review gate、永不 push——不在權限模式。
- `acceptEdits`：只給不信任的場景,並預期任務會卡住,除非專案 permissions 放行驗證指令。

**審查修復迴圈**（needs-fix 之後）：審查者（Fable）給每個 finding 標級——`fix`（不動介面/資料格式/依賴/需求 → **主 session 修**,修的人與審的人分離）、`design`（回 /plan）、`requirement`（回 /grill）；有高層級 finding 整輪不修小的。修完做**限縮重審**（只看 finding + Fix 條目 + 修復 diff）,上限 2 輪,過不了就升級給使用者裁決。修復由 `/commit` 在整合分支上先行提交再合併回 main。

**安全設計**：任務由 /plan 匯出時強制檔案不重疊、內容自足（headless session 沒有對話上下文）；每個 session 只寫自己的 `.claude/worklog.d/<slug>.md`（合併不衝突）；只 commit 不 push 不 merge；失敗的任務留 log 在 `.claude/dispatch-logs/`。

### Graphify（省 token 選配）

[Graphify](https://github.com/Graphify-Labs/graphify) 用 tree-sitter 在本地把程式碼解析成可查詢的知識圖譜（不打 API），之後 Claude 沿圖找到相關檔案再精準讀取，不用大範圍翻檔案定位——**大型專案（約 500+ 檔案）省最多，小專案建圖成本反而高於節省**，所以是選配不進 preset。

- 前置：`uv tool install graphifyy`（或 `pipx install graphifyy`；PyPI 套件名是雙 y）。
- 裝法：專案**首次**安裝的互動流程會問一次要不要裝；或隨時 `blackcat --graphify`。
- **關鍵：完整接線有三層，只裝 skill 是不會省到 token 的**（Claude 不會自動查圖，照樣翻檔案）。blackcat 會三層都裝：

| 層 | 指令 | 作用 |
|:--|:--|:--|
| skill | `graphify install --project` | 手動 `/graphify` 查詢能力 |
| **graph-first** | `graphify claude install` | CLAUDE.md 指示 + PreToolUse hook，在搜尋類工具呼叫前把 Claude 推向圖查詢——**這層才是自動省 token 的來源**（還有 strict 模式可強制） |
| 自動重建 | `graphify hook install` | git post-commit/checkout hook 增量重建（只重解析變動檔案），**不用手動更新圖** |

- 裝完在 Claude Code 裡跑一次 `/graphify .` 建圖（產出 `graph.json` / `GRAPH_REPORT.md` / `graph.html`）。之後圖靠 git hook 在每次 commit 自動增量更新；沒裝 hook 的話手動 `graphify update .`。
- 它建立的 `.claude/skills/graphify` 歸 graphify CLI 管——blackcat 的清理與更新機制**刻意不碰**非本 repo 的 skills，互不干擾。

### 更新機制

裝進專案的檔案**永遠不會被靜默覆蓋**（重跑會顯示 `[keep]`）。當你更新了 blackcat repo（`git pull` 或自己改），已裝的專案這樣同步：

- **每次跑 `blackcat`**（任何 preset）結尾都會做更新檢查：比對專案已裝項目與 repo 版本，列出有差異的（skills / rules / commands / agents / output-styles），互動模式下**詢問要更新哪些**（`a` 全更、Enter 跳過、輸入編號挑選）。
- **`blackcat --update`**：純更新模式——不裝任何新東西，直接刷新所有有差異的項目、不逐項詢問。這是「更新 blackcat repo → 到各專案跑一次」的標準流程。
- 更新會**覆蓋該項目的本地修改**（提示訊息會先警告），所以專案的 `.claude/` 記得先 commit；非互動環境（CI）只列差異不動手。
- 小提醒：rules 組合若新增了「新檔案」，更新會複製進來但 CLAUDE.md 的 `@import` 區塊不會自動加行（那是你挑選過的清單），輸出會提示手動補。

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

**Statusline**：多行彩色（模型 │ context │ 目錄+branch │ 時長 │ 花費 + rate limit 進度條）——把「現在燒多快」常駐在眼前，才會記得省。需要 `jq`，install.sh 會檢查。

**Hooks**：v26.7.3 起全域**零 hooks**。agent-monitor 移至 project-template（`--taskmaster` 時隨專案安裝）；舊版 25+ 個 ECC hooks 已於 v26.7.1 移除。回滾看 git history。

**Rules**：24 個編碼規範文件（common 9 + python/typescript/rust 各 5）。注意 **Claude Code 不會自動載入 rules 目錄**——安裝器會把規範複製進專案 `.claude/rules/` 並在專案 CLAUDE.md 附加一段帶標記的 `@import` 區塊（原生 memory import 機制），這才是規範真正進入 startup prompt 的接線。重跑不會重複附加；每個 import 的檔案都吃 context，按專案需要選裝。

裝法有兩種：跑 `blackcat --lean`（或任何 preset）結尾會出現**互動選單**，先問要不要裝（Enter = 不裝），要裝的話列出語言組合與 9 條 common 規範各附一句說明，輸入編號挑選（common 直接 Enter = 全裝、`n` = 不裝）；或用 `--rules python` 直接指定跳過選單。選單只在互動終端機出現，CI / 管線自動靜默跳過，也可用 `--no-rules` 強制關閉：

```
Add coding rules to CLAUDE.md? [y/N] y
Language sets (a set imports all 5 of its files):
  1) python       Python set: style/testing/patterns/hooks/security
  2) rust         Rust set: style/testing/patterns/hooks/security
  3) typescript   TypeScript/JS set: style/testing/patterns/hooks/security
Select sets (numbers separated by spaces, Enter for none): 1
Common rules (language-agnostic):
  1) agents.md                when/how to design subagents and delegate work
  2) coding-style.md          naming, function size, immutability defaults
  3) development-workflow.md  plan -> implement -> verify working loop
  4) git-workflow.md          branching, commit messages, PR conventions
  5) hooks.md                 auto-run formatters/linters via PostToolUse hooks
  6) patterns.md              preferred design patterns and anti-patterns
  7) performance.md           measure-before-optimize guidelines
  8) security.md              secrets, input validation, dependency hygiene
  9) testing.md               test structure and coverage expectations
Select common rules (Enter for all, n for none, numbers to pick): 2 9
```

**環境變數**：

| 變數 | 值 | 用途 |
|:--|:--|:--|
| `MAX_THINKING_TOKENS` | 10000 | 延伸思考 token 上限 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 50 | 自動壓縮觸發閾值 |

---

## 參考來源

設計過程中參考過的專案（含直接收錄的 MIT 授權內容）：

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)（MIT，已收錄）
- [bheadwei/claude-GUNDAM-zh-tw](https://github.com/bheadwei/claude-GUNDAM-zh-tw)
- [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code)
- [nutlope/hallmark](https://github.com/nutlope/hallmark)（MIT，`--ui` 時抓進專案）
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)（`--ui` 時抓進專案）
- [Raymondhou0917/speak-human-tw](https://github.com/Raymondhou0917/speak-human-tw)（MIT，已收錄）
- [blader/humanizer](https://github.com/blader/humanizer)（MIT，已收錄）
- [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify)（選配整合）
- [pencil.dev](https://pencil.dev)（選配整合）

---

## 版本歷史

| 版本 | 日期 | 內容 |
|:--|:--|:--|
| **v26.7.38** | 2026-08-07 | 切清 `/verify` 與 `/review-code` 的邊界：verify 定位為純機器檢查（改 sonnet、拿掉計畫歸檔兼差），review-code 第 0 步先跑機器檢查當門檻、紅了不審不燒貴模型 |
| **v26.7.37** | 2026-08-07 | 模型精靈改為列出**所有**帶 `model:` 的指令現值供挑選（原本只管 3 個）；修 sed 誤改檔案內範例 model 行的 bug；README 說明 skill 無模型欄位 |
| **v26.7.36** | 2026-08-07 | 新增 `/grill-doc <檔案>`：對既有文件逐條拷問並**邊談邊就地改寫**（一題一改、能自查的不問人、未決入清單、只改文件不碰程式碼、未受版控先問過才動） |
| **v26.7.35** | 2026-08-07 | 整理指令定名 `/clean-plan`（`/plans`、`/tidy` 兩個舊名皆自動遷移），職責擴及整個 `.claude/` 工作區（含孤兒 worklog） |
| **v26.7.33** | 2026-08-07 | 修 skill 不觸發的根因：verification-loop 與 tdd-workflow 的 description 重寫為明確觸發條件（MUST BE USED + 時機/反例），speak-human-tw 擴及技術文件與 README；--usage 補偵測「經 Bash 使用」的 skill（修 graphify 的假陰性）並分離內建項目 |
| **v26.7.32** | 2026-08-07 | --usage 分離 Claude Code 內建 commands/agents/skills、加判讀指引 |
| **v26.7.31** | 2026-08-07 | 新增 `blackcat --usage`（--skill-freq）：掃 Claude Code session transcripts 統計 skills/commands/agents 使用次數、列出裝了沒用過的——零常駐成本的回溯分析，供裁汰決策 |
| **v26.7.30** | 2026-08-07 | 新增 /grill-ui（grill 的前端分支：八項檢查卡 + 同源訪談機制，/go 快車道自動走）；`--ui-refresh` 重抓外部 skills（hallmark/ui-ux-pro-max 追新版，舊版備份） |
| **v26.7.29** | 2026-07-30 | 實戰修正四項：/go 快車道（trivial 小改跳過 grill/plan/跨 session 審查）；測試品質規則（禁 UI 文案斷言、禁湊覆蓋率，review 會抓）；元件/icon 統一（DESIGN.md 指定唯一 icon 集、複用優先）；UI pack 加裝 ui-ux-pro-max（UX 知識庫層，DESIGN.md 契約優先） |
| **v26.7.28** | 2026-07-29 | 新增 `/plans` 計畫整理：done 整包歸檔（計畫+requirements+spec 同 slug 一起搬）、爛尾計畫逐個問續作/棄置、絕不刪檔；/verify /commit 歸檔改整包制；任務檔歸檔到 tasks/archive/ |
| **v26.7.27** | 2026-07-29 | 文件整理：設計說明改為只講設計理由，來源標註集中到「參考來源」一節（含 claw-code、Hallmark、Graphify、pencil）；WORKFLOW.md 開頭改為六條設計原則 |
| **v26.7.26** | 2026-07-29 | 定前端檔案落點約定：`.pen` 設計稿放 `design/`（進 git、與碼同步），DESIGN.md/IA.md 留 `.claude/ui/`（流程契約），灰框原型即棄 |
| **v26.7.25** | 2026-07-29 | 接上 pen CLI（@pencil.dev/cli，headless 畫布引擎）：--ui 偵測與安裝指引、/ui-page 新增 CLI 出圖迭代路線（無 GUI 也能畫布先行）、MCP 範本註記更新 |
| **v26.7.24** | 2026-07-29 | UI 補動線層：/ui-site 可產灰框 HTML 可點擊原型（Figma prototype 替代，連結真可點、彈窗真會開）；pencil 畫布先行流程寫進 ui-site/ui-page（AI 畫、人調、碼隨稿走） |
| **v26.7.23** | 2026-07-29 | UI pack 整合 Hallmark（去 AI 味設計 skill，裝 --ui 時自動 clone 進專案）；/ui-style 改品牌色優先（hex → 色階/語意 tokens/深色版/WCAG 檢查）；ui-page 與 ui-builder 接 slop-test 檢查關 |
| **v26.7.22** | 2026-07-29 | 吸收 GUNDAM 精華五項：/grill 範疇分級（demo/mvp/full）、/spec 文件先行（PRD/BDD）、/learn 持續學習、/verify 與 /commit 計畫歸檔、.mcp.json 分平台範本；dispatcher `--windows` 實體視窗模式（標題 bc-<任務>）；UI 前端三部曲選裝（--ui + 首裝詢問，pencil MCP 配套）；README 工作流全圖定版 |
| **v26.7.21** | 2026-07-29 | preset 切換偵測：在專案上跑另一個 preset 會偵測互斥 skills、詢問後移到 backups 再裝新的（修 lean/strict 並存的矛盾風險） |
| **v26.7.20** | 2026-07-28 | dispatcher 任務提示詞明確要求遵守專案 skills/rules（strict 專案的並行 session 明確走 TDD）；README 補「站 vs 紀律」心智模型 |
| **v26.7.19** | 2026-07-28 | 新增 `/go` 一條龍：計畫確認為唯一人工關卡，之後自動執行、headless 跨 session 審查、修復迴圈（≤2 輪）、提交準備；單站指令保留供精細控制 |
| **v26.7.18** | 2026-07-28 | 依端到端實測修正：dispatcher 權限預設改 skip（acceptEdits 實測卡死）、dry-run 真唯讀、--status 增列實際執行值；新增審查修復迴圈（finding 分級 fix/design/requirement、主 session 修、限縮重審、2 輪上限）；任務模板加完成程序與 Windows 注意事項；/merge 薄包裝；grill 交接指紋 |
| **v26.7.17** | 2026-07-27 | 修並行路線收尾：dispatch 從 main 出發自動開 `integrate/*` 整合分支（main 審查前保持乾淨）；/commit 增加並行模式——驗 pass 後把整合分支 merge --no-ff 回 main |
| **v26.7.16** | 2026-07-27 | 調度改雙入口：新增 `/dispatch` slash command（Claude Code 內用，dry-run 確認、背景執行定期回報、衝突協助）與終端短別名 `bcd`；/dispatch 進 preset |
| **v26.7.15** | 2026-07-27 | 完整流程落地：新增 /grill（Fable 需求拷問）、/plan 並行任務匯出、`blackcat-dispatch`（worktree 隔離 + headless 並行執行，`--max` 控併發、merge/clean/status 子模式）；worklog.d 並行紀錄機制 |
| **v26.7.14** | 2026-07-27 | Graphify 改三層完整接線：skill + graph-first（CLAUDE.md 指示與 PreToolUse hook，自動省 token 的來源）+ git hook 自動增量重建；README 說明只裝 skill 沒效果的原因 |
| **v26.7.13** | 2026-07-27 | 整合 Graphify（選配省 token）：`--graphify` 編排其官方安裝器、首裝互動流程詢問一次；其 skill 歸 graphify CLI 管、不受本 repo 清理/更新機制影響 |
| **v26.7.12** | 2026-07-27 | 專案初始化模型精靈：首裝自動探測 Fable 5 可用性（不可用降回 opus）並逐階段詢問 plan/review/commit/主迴圈模型；`--models` 重開精靈；更新機制忽略並保留專案自選 model |
| **v26.7.11** | 2026-07-27 | 模型路由：/plan 與 /review-code 用 Fable 5、主迴圈 Opus、/commit（新指令）用 Sonnet；新增 worklog skill 讓執行紀錄接力給審查（review 只看 worklog 範圍不掃全庫）；兩者進 lean/strict preset |
| **v26.7.10** | 2026-07-27 | 新增更新機制：每次 `blackcat` 結尾比對已裝項目與 repo 版本、互動詢問要更新哪些；`blackcat --update` 純更新模式一次刷新全部差異 |
| **v26.7.9** | 2026-07-27 | 規範改互動選裝：`blackcat` 安裝結尾跳出規範選單（語言組合 + 9 條 common 各附一句說明，可逐條挑）；新增 `--no-rules`；非互動環境自動跳過 |
| **v26.7.8** | 2026-07-27 | rules 正式接線：新增 `--rules` 選項（複製進專案 `.claude/rules/` + CLAUDE.md 帶標記 `@import` 區塊，冪等）；修正 rules/README.md 過時安裝說明（參考 claw-code 的 rules 自動載入設計，改用 Claude Code 原生 memory import 實現） |
| **v26.7.7** | 2026-07-27 | 修 Windows shim 執行失敗：非 login 啟動的 Git Bash 沒有 /usr/bin，安裝腳本開頭改用純 builtin 自補 PATH |
| **v26.7.6** | 2026-07-27 | 安裝改為「先清後裝」：舊版裝入 `~/.claude` 的管理項目（含 copy 模式的實體目錄）備份後移除，非本 repo 內容不動；install.sh / install-project.sh 全面英文化（避免 cmd 的 UTF-8 解析 bug） |
| **v26.7.5** | 2026-07-27 | 修復 install.bat 中文字元導致 cmd 解析錯位（改純 ASCII，PATH 才能正確寫入）；Windows 增設 `blackcat.cmd` 供 PowerShell 使用（`cat` 被 Get-Content 別名佔用） |
| **v26.7.4** | 2026-07-27 | 修復 Windows 安裝：install.bat 與 cat.cmd 明確使用 Git Bash 完整路徑（避免抓到 System32 的 WSL bash 而報「沒有已安裝的發佈」） |
| **v26.7.3** | 2026-07-27 | 一鍵化：新增 `install.bat`（Windows 雙擊安裝 + 自動加 PATH）與 `cat`/`blackcat` 專案安裝指令；全域縮到只剩 settings + statusline（零 hooks）；rules 移為根目錄參考庫 |
| **v26.7.2** | 2026-07-27 | 新增寫作組合：speak-human-tw v1.4.0 + humanizer v2.9.1、`--writing` 疊加選項；README 全面改寫並導入版號制 |
| **v26.7.1** | 2026-07-27 | 大重構：工作流全域→專案級、install-project.sh 與 lean/strict presets、引入 ponytail、計畫持久化 + /save-session（融合 bheadwei GUNDAM）、移除全部 ECC hooks（settings.json 313→40 行）、WORKFLOW.md |
| v1 | 2026-07 之前 | ECC + GUNDAM 整包疊加時期 |
