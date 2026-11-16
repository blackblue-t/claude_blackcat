---
description: 一條龍指令：需求 → 計畫（唯一人工關卡）→ 執行 → 自動跨 session 審查 → 修復迴圈 → 提交準備。計畫確認後不需要再打任何指令。
---
<!-- 不設 model:（繼承主迴圈=執行模型）。規劃與審查階段的模型路由由
     被呼叫的環節自帶：headless 審查走 review-code.md 的 frontmatter。 -->

# 一條龍（/go）

把 grill → plan → 執行 → review → 修復 → commit 串成一次流程。
**唯一的強制人工關卡是計畫確認**；之後全自動，直到最後的 user check。
各站的規則不在這裡重複——本指令只負責**銜接**，每站進入時讀對應的
指令檔（plan.md、review-code.md、commit.md）照它的規則做。

## 階段

### -1. 開工前同步

照 `sync.md` 的步驟 1、2 做一次（沒有遠端就跳過）。落後就先拉下來再開工；分岔或有衝突
先處理完。這一步不做，做完才發現遠端早就有人改過同一個檔。

### 0. 任務分級——先判等級，再決定走多重的流程

等級決定流程多重、審查用多貴的模型。**判完用一句話告訴使用者**（「這是一般任務，
審查用 /review-code」），使用者可以改。

| 等級 | 判定 | 計畫 | 審查 |
|:--|:--|:--|:--|
| 快車道 | 下面三條同時滿足 | 不出計畫 | 自己看一次 diff，不開審查 session |
| 一般（預設） | 其他都是 | 階段 1 | `/review-code`（opus，effort medium） |
| 關鍵 | 動到任何一項：登入／權限、金流或金額計算、資料庫 schema 或資料遷移、刪除或覆寫使用者資料、對外 API 或檔案格式、加密與機密、並行與鎖；或使用者說「重要」「仔細審」 | 階段 1，計畫要寫回復方式 | `/review-deep`（fable，effort high） |

拿不準是一般還是關鍵 → 當關鍵。等級只升不降：做到一半發現動到上面那些項目，升成關鍵。

同時滿足以下三條 = **快車道**：

- 純視覺 / 文案 / 樣式，或單一元件的小修改
- 不動業務邏輯、不動資料結構、不動公開介面
- 預估 ≤ 3 個檔案

**快車道** = 跳過 grill / spec / plan / 跨 session 審查，但**不是
零思考**：前端/UI 改動先過 `grill-ui.md` 那張檢查卡（逐項自答，
答不出的才問使用者），非 UI 的小改自答「會不會動到邏輯、資料、
公開介面」三連問。然後直接做（照樣遵守 worklog 紀律與 DESIGN.md /
專案 rules）→ 跑相關的既有測試 → 自己看一次 diff → 照 commit.md
提交準備。回報時標明走了快車道與檢查卡結果；有新增檔案、類別或函式就附命名表（名稱＋中文說明）。使用者說「快速」
「quick」「小改」一律快車道；拿不準就問一句「快車道還是完整流程？」。
檢查卡過程中發現其實會動到邏輯/資料 → 轉 standard。其餘 = standard，
從 0.1 走起。

### 0.05 WBS 對應（有 `.claude/taskmaster-data/wbs.md` 時）

需求對應到 WBS 某一列 → 照 `wbs` skill 改 `進行中`、寫 `.current-task`，計畫帶 `wbs:`。
對不到 → 問一句「要先加進 WBS 嗎？」（`/task-add`），使用者說不用就照做、不記任務。
快車道的小改不用問。

### 0.1 需求把關（視情況）

- 使用者**指定了一份既有文件**（需求書、規格）→ 照 `grill-doc.md`
  逐條拷問並就地改進它，改完再進下一階段。
- `.claude/plans/` 已有本任務的 requirements 文件 → 直接進下一階段。
- 需求清楚簡單 → 直接進下一階段。
- 需求有明顯模糊地帶 → 先照 `grill.md` 的方式問**最關鍵的 2-3 題**
  （不做完整拷問；使用者要完整版會自己跑 /grill），問完進下一階段。

### 0.5 規格（依 scope，可選站）

需求文件的 `scope:` 是 **full** → 照 `spec.md` 產 PRD + BDD 再進計畫
（strict 專案建議必走）；**mvp** → 問使用者要不要 PRD-lite；
**demo** → 跳過。

### 1. 計畫（= 唯一人工關卡）

照 `plan.md` 的全部規則做（含並行任務匯出判斷、交接指紋回報）。
呈現計畫後**停下等使用者確認——這是整條龍唯一必停的地方**。
確認後寫計畫檔，繼續。

### 2. 執行

- **有匯出並行任務** → 照 `dispatch.md`：dry-run 給使用者看一眼後
  執行 `blackcat-dispatch`，背景盯進度，完成後 `--merge`（衝突停下
  協助解決）。
- **一般任務** → 主 session 直接實作；strict preset（裝了
  tdd-workflow）就照 TDD 紀律走。全程遵守 worklog 紀律。

實作告一段落先跑 `/verify` 的機器檢查（build/type/lint/test）——紅的
就地修完再進審查，不要把壞掉的東西送去審。

### 3. 自動跨 session 審查（不用使用者開視窗）

執行告一段落後，**用 headless session 跑審查**（新 context = 獨立
session，滿足修/審分離）：

```bash
claude -p "/review-code" --dangerously-skip-permissions     # 一般任務
claude -p "/review-deep" --dangerously-skip-permissions     # 關鍵任務
```

- 照階段 0 判的等級選指令。模型由各自的 frontmatter 決定，不用另指定。
- 專案沒裝 `/review-deep`（舊安裝）→ 關鍵任務也用 `/review-code`，並在收尾報告提醒
  跑 `blackcat --update` 補裝。
- 跑完讀 `.claude/worklog.md` 最新的 `## Review (round N)` 條目取 verdict。
- claude CLI 不可用時退回手動：請使用者開新 session 跑 /review-code，
  流程在此暫停。

### 4. 修復迴圈（照 review-code.md 的分級規則）

- **pass** → 進階段 5。
- **needs-fix**（全 `fix` 級）→ 本 session 修（記 `## Fix:` 條目），
  再跑一次階段 3 的 headless 審查（限縮重審，跟第 1 輪同一個指令）。**上限 2 輪**，
  超過就停下交使用者裁決。
- **escalate**（有 `design`/`requirement` 級）→ 停下，帶著 findings
  回報使用者：建議回 /plan 或 /grill，不自作主張改架構。

### 5. 提交準備

照 `commit.md` 做（含並行路線的整合分支合併回 main），最後照 `commit.md` 的
「同步與推送」處理：預設問一句要不要推，`.claude/blackcat.conf` 設 `PUSH=auto` 才直接推。

### 6. 收尾報告

一段話總結：任務等級、做了什麼、審查幾輪抓到什麼、commit hash、推了沒有（沒推就寫
還有幾個提交在本地）；並行路線提醒 `/dispatch --clean`。

最後提醒一句：**下一個任務前先 `/clear`**。進度都在檔案裡（WBS、計畫、worklog 歸檔），
不靠對話記憶；帶著上一個任務的整段對話做下一個，每一步都在為用不到的內容付費。

## 鐵則

- 計畫確認前不寫任何檔案（plan.md 的規則，這裡再強調一次）。
- 審查永遠在獨立 session（headless 或手動），絕不在本 session 自審。
- 修復迴圈上限 2 輪，escalate 永遠停下——自動化不覆蓋人的裁決點。
- 沒問過不 push（`PUSH=auto` 例外）、不動使用者沒同意的範圍。
- 中途任何一站失敗（dispatcher 卡死、headless 起不來），停在原地
  說明狀況與手動續行方式，不硬闖。
