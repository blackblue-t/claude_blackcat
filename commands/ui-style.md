---
description: 前端第一站：問答定風格，產出 DESIGN.md（色票 tokens、字體階層、間距、圓角、深淺模式）。之後所有 UI 產出都以它為準。
---

# 風格定義（/ui-style）

前端三部曲的第一站（style → site → page）。產出 `.claude/ui/DESIGN.md`
作為唯一風格依據——**先有 DESIGN.md 才准寫任何 UI 程式碼**。

## 流程

1. **偵測**：讀 package.json / CLAUDE.md 判定框架（React / Vue /
   Svelte / vanilla）與 CSS 方案（Tailwind / CSS Modules / styled）。
   已有 `.claude/ui/DESIGN.md` 時先問「覆寫還是修訂？」。
2. **問答**（一次一題，給建議選項）：
   - **品牌色優先**：先問「有品牌色嗎？」有 → 使用者給 hex（一個或
     多個），以它為錨生成整套：明暗色階（50-900）、語意 tokens
     （primary/secondary/surface/danger…）、深色模式對應色、**WCAG AA
     對比度檢查**（文字色 vs 背景不過關就提出微調建議,不硬用）。
     沒有 → 給 3 組建議色盤選。
   - 風格方向：**專案裝有 hallmark skill 時,用它的主題目錄選**
     （20 種,比四選一細得多）;沒有就極簡 / 商務 / 活潑 / 技術感四選。
   - 深色模式：要 / 不要 / 跟隨系統
   - 字體：系統字體堆疊（預設建議）/ 指定字型
   - 圓角與陰影的個性：銳利 / 柔和
3. **產出 `.claude/ui/DESIGN.md`**：
   - 色票 tokens（含深淺兩版，語意命名：`--color-primary` 而非 `--blue`）
   - 字體階層（h1-h4 / body / caption 的 size、weight、line-height）
   - 間距系統（4/8px 倍數）
   - 圓角、陰影、過渡時間的統一值
   - 每項附「怎麼用」的一行程式碼示例（對應偵測到的 CSS 方案）
4. 提醒：下一步 `/ui-site` 建站點結構,或直接 `/ui-page <路徑>` 做單頁。

## 鐵則

- pencil MCP 可用時，用它取得/同步設計稿的 tokens，DESIGN.md 與設計稿
  一致；不可用就純問答。
- 不寫任何元件程式碼——本站只定規範。
