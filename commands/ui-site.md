---
description: 前端第二站：問答建立網站資訊架構（IA），產出頁面清單與路由 stubs。需先有 /ui-style 的 DESIGN.md。
---

# 站點結構（/ui-site）

前端三部曲第二站。產出 `.claude/ui/IA.md`（資訊架構契約）+ 各頁路由
stub。之後 `/ui-page` 深化單頁時照 IA 做,不用重問基本問題。

## 流程

1. **前置**：讀 `.claude/ui/DESIGN.md`（沒有先跑 /ui-style）。
2. **問答**（一次一題）：網站目的與受眾 → 需要哪些頁面（給常見組合
   multi-select：行銷站 = Home/Pricing/About/Contact；SaaS = 上述 +
   Login/Dashboard/Settings…）→ 每頁的主要 CTA → 共用元素
   （Header/Footer/Sidebar）→ 資料來源（靜態 / API / CMS）。
3. **產出**：
   - `.claude/ui/IA.md`：每頁一節——目的、受眾、CTA、區塊組成、
     資料來源、狀態（stub / 已深化）
   - 各頁路由 stub 檔（依框架慣例,只有骨架與 TODO 註記,不填內容）
   - 共用元件 stub（Header/Footer）
4. 呈現整棵站點樹給使用者確認後才寫檔。
5. 提醒：逐頁跑 `/ui-page <路徑>` 深化。

## 鐵則

- stub 只有結構,不猜內容——內容是 /ui-page 問出來的。
- IA.md 是契約:之後頁面長什麼樣以它為準,改架構要回來改它。
