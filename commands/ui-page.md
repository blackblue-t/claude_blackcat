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
   驗證方案、動畫程度（無/微/中/強）。
3. **骨架確認**:展示 component tree 與將新增的檔案清單,
   **使用者確認才生成**。
4. **委派 `ui-builder` agent** 產出程式碼（傳入:頁面路徑、IA 資訊、
   DESIGN.md 關鍵規範、響應式需求）。
5. **回寫**:非 adhoc 模式把本次確定的資訊 append 回 IA.md 該頁區段,
   狀態改「已深化」。
6. 頁面預估跨多檔或超過一小時 → 建議走 /plan 建計畫再實作。

## 風格合規自檢（產出後必附）

```
- [ ] 色票:全用 DESIGN.md tokens,零裸色值
- [ ] 字體:遵循字體階層
- [ ] 間距:4/8px 倍數
- [ ] 深色模式:已處理（DESIGN.md 有定義時）
- [ ] 響應式:mobile / tablet / desktop
- [ ] 語意化 HTML
```

缺項要說明原因。pencil MCP 可用時,以設計稿為視覺基準核對。
