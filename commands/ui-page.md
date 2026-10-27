---
description: 前端第三站：深化單一頁面——讀 IA 契約補實作細節問答，委派 ui-builder 產出符合 DESIGN.md 的完整頁面，附風格合規自檢。
---

# 單頁深化（/ui-page）

用法：`/ui-page /pricing`、`/ui-page /`（首頁）、`/ui-page /x --adhoc`
（跳過 IA,快速原型不留檔）。

## 流程

1. **前置**：讀 `.claude/ui/DESIGN.md`（必要,沒有先跑 /ui-style）。
   讀 `.claude/ui/IA.md`:
   - **有該頁區段** → 直接取目的/CTA/區塊/資料,只補問實作細節。
   - **沒有 IA**（或 `--adhoc`）→ 給三選項:先跑 /ui-site（建議）/
     只為這頁建最小 IA（5 題）/ adhoc 不留檔。
2. **實作細節問答**（一次一題,只問頁面用得到的）:狀態管理、表單
   驗證方案、這一頁的動畫等級（預設沿用 `style.json` 的 `motion`；要調就照
   `ui-style-compliance/motion.md` 第 1 節出題,結果寫進 IA 該頁的「動畫等級」）。
3. **骨架確認**:展示 component tree 與將新增的檔案清單,
   **使用者確認才生成**。
3.5 **pencil 畫布先行（pencil MCP 或 pen CLI 可用時）**:先用
   batch_design 把頁面畫成 .pen 設計稿（落點約定:`design/site.pen`,
   見 ui-style.md 的表;設計稿進 git）,請使用者調整後確認,以設計稿
   為準實作——「AI 畫、人調、碼隨稿走」。兩種調整方式:
   - 有桌面 app / IDE 擴充 → 使用者直接在畫布上拖拉修改。
   - 只有 pen CLI（headless）→ 用它把 .pen **匯出 PNG** 給使用者看,
     使用者用文字回饋修改點,改稿再出圖,迭代到確認。
   都不可用就跳過,直接從骨架進實作。
4. **委派 `ui-builder` agent** 產出程式碼並截圖驗收（傳入:頁面路徑、IA 資訊、
   .pen 設計稿（若有）、響應式需求）。依它最後的狀態碼決定下一步:
   - `DONE` → 回寫 IA
   - `DONE_WITH_CONCERNS` → 把疑慮（含「截圖未驗證」）原文轉告使用者,問要不要處理
   - `NEEDS_CONTEXT` → 問使用者補資訊,再派一次
   - `BLOCKED` → 停下,說明卡在哪
5. **回寫**:非 adhoc 模式把本次確定的資訊 append 回 IA.md 該頁區段,
   狀態改「已深化」。
6. 頁面預估跨多檔或超過一小時 → 建議走 /plan 建計畫再實作。

## 風格合規自檢（產出後必附）

清單、斷點規則、反 AI 感對照都以 `.claude/skills/ui-style-compliance/` 為唯一來源
（SKILL.md 階段 3、`anti-ai.md`），ui-builder 的回報裡會附上。這裡只檢查它有沒有附:
沒附自檢、沒有「截圖驗收」與「開放問題」兩節 → 退回請它補,不要自己替它勾。
pencil 設計稿存在時,以設計稿為視覺基準核對。
