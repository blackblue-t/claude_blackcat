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

### 0. 任務分級——先判要不要走全流程

不是每個改動都值得五站流程。同時滿足以下三條 = **trivial，走快車道**：

- 純視覺 / 文案 / 樣式，或單一元件的小修改
- 不動業務邏輯、不動資料結構、不動公開介面
- 預估 ≤ 3 個檔案

**快車道** = 跳過 grill / spec / plan / 跨 session 審查，但**不是
零思考**：前端/UI 改動先過 `grill-ui.md` 那張檢查卡（逐項自答，
答不出的才問使用者），非 UI 的小改自答「會不會動到邏輯、資料、
公開介面」三連問。然後直接做（照樣遵守 worklog 紀律與 DESIGN.md /
專案 rules）→ 跑相關的既有測試 → 自己看一次 diff → 照 commit.md
提交準備。回報時標明走了快車道與檢查卡結果。使用者說「快速」
「quick」「小改」一律快車道；拿不準就問一句「快車道還是完整流程？」。
檢查卡過程中發現其實會動到邏輯/資料 → 轉 standard。其餘 = standard，
從 0.1 走起。

### 0.1 需求把關（視情況）

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

### 3. 自動跨 session 審查（不用使用者開視窗）

執行告一段落後，**用 headless session 跑審查**（新 context = 獨立
session，滿足修/審分離）：

```bash
claude -p "/review-code" --dangerously-skip-permissions
```

- 模型由 review-code.md 的 frontmatter 決定，不用另指定。
- 跑完讀 `.claude/worklog.md` 最新的 `## Review (round N)` 條目取 verdict。
- claude CLI 不可用時退回手動：請使用者開新 session 跑 /review-code，
  流程在此暫停。

### 4. 修復迴圈（照 review-code.md 的分級規則）

- **pass** → 進階段 5。
- **needs-fix**（全 `fix` 級）→ 本 session 修（記 `## Fix:` 條目），
  再跑一次階段 3 的 headless 審查（限縮重審）。**上限 2 輪**，
  超過就停下交使用者裁決。
- **escalate**（有 `design`/`requirement` 級）→ 停下，帶著 findings
  回報使用者：建議回 /plan 或 /grill，不自作主張改架構。

### 5. 提交準備

照 `commit.md` 做（含並行路線的整合分支合併回 main）。**不 push。**

### 6. 收尾報告

一段話總結：做了什麼、審查幾輪抓到什麼、commit hash、
「請檢查 git log，滿意就 push」；並行路線提醒 `/dispatch --clean`。

## 鐵則

- 計畫確認前不寫任何檔案（plan.md 的規則，這裡再強調一次）。
- 審查永遠在獨立 session（headless 或手動），絕不在本 session 自審。
- 修復迴圈上限 2 輪，escalate 永遠停下——自動化不覆蓋人的裁決點。
- 全程不 push、不動使用者沒同意的範圍。
- 中途任何一站失敗（dispatcher 卡死、headless 起不來），停在原地
  說明狀況與手動續行方式，不硬闖。
