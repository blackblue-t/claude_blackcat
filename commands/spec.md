---
description: 文件先行：依 scope 產出 PRD（mvp）或 PRD + BDD 規格（full），規格先於任務拆解、防範疇蔓延。demo 級不需要本指令。
model: claude-fable-5
---
<!-- 模型路由：規格是規劃層工作，用 Fable 5。降級改 model: 即可。 -->

# 規格產出（/spec）

在 `/grill`（需求）和 `/plan`（任務拆解）之間的可選一站——**規格先於
WBS，防止做著做著長出需求裡沒有的東西**。取材自 GUNDAM 的文件先行流程,
瘦身為兩級。

## 流程

1. 讀 `.claude/plans/` 最新的 `*-requirements.md`,取其 `scope:`。
   沒有需求文件就請使用者先跑 `/grill`。
2. 依 scope 決定份量:
   - **demo** → 明說「demo 級不需要 spec」,建議直接 `/plan`,結束。
   - **mvp** → 產出 **PRD-lite**:目標、使用者故事（As a... I want...
     so that...）、功能清單（in/out）、驗收條件。一頁為限。
   - **full** → PRD-lite 全部,加上 **BDD 場景**（Given / When / Then,
     覆蓋主要路徑與需求文件裡的每個錯誤行為）與非功能需求
     （效能/安全/相容性,有明確要求才寫,不硬湊）。
3. 寫入 `.claude/plans/<YYYY-MM-DD>-<slug>-spec.md`,frontmatter:

   ```yaml
   ---
   scope: mvp          # 繼承自需求文件
   status: active
   requirements: <需求文件檔名>
   ---
   ```

4. 提醒:下一步 `/plan` 會以本規格為準;BDD 場景就是 full 級的驗收
   測試藍本（/tdd 直接照場景寫測試）。

## 鐵則

- 規格內容**只能來自需求文件與使用者的回答**——不自行發明功能。
  發現需求文件有漏洞,回頭問使用者或建議補跑 /grill,不擅自補洞。
- 一份規格一頁到兩頁。超過代表 scope 判斷錯了,回頭確認。
