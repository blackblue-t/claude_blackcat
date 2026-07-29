---
description: 持續學習：把本次 session 學到的可重用教訓蒸餾進專案 CLAUDE.md，讓下個 session 不再踩同樣的坑。session 收尾時跑。
model: sonnet
---
<!-- 模型路由：蒸餾與去重是整理工作，sonnet 就夠。 -->

# 持續學習（/learn）

`/save-session` 存的是「這次做到哪」；`/learn` 存的是「以後都適用的
教訓」。兩者互補，session 收尾時可以連著跑。

## 什麼算教訓（嚴格篩選）

只收**下個 session 不知道就會再踩一次**的東西：

- 專案的隱藏約束（「這個 API 回 UTC 但存檔是本地時區」）
- 被修正過的錯誤假設（「以為 X 其實是 Y」）
- 環境的坑（「這台機器的 PowerShell 5.1 寫檔會帶 BOM」）
- 有效的作法（「跑測試前要先起 docker compose，否則假失敗」）

**不收**：一次性的事實、本次任務的進度（那是 /save-session 的事）、
通用常識、情緒感想。

## 流程

1. 回顧本次 session，列出候選教訓（通常 0-3 條；沒有就老實說沒有，
   不硬湊）。
2. 讀專案 CLAUDE.md 的 `<!-- blackcat:lessons -->` 區塊（沒有就準備
   建立），**去重**：已有等價教訓就跳過或合併改寫。
3. 向使用者列出「準備寫入的教訓」，確認後寫入：

   ```markdown
   <!-- blackcat:lessons -->
   ## 專案教訓（/learn 維護）
   - <一行一條，寫成指令句：「X 時要 Y，因為 Z」>
   <!-- /blackcat:lessons -->
   ```

4. 區塊保持精簡（上限 15 條）——超過時提議把最舊或已過時的淘汰。
   CLAUDE.md 每個 session 都會載入，這裡的每一行都是常駐 context，
   寧缺勿濫。

## 鐵則

- 只動標記區塊內的內容，CLAUDE.md 其他部分一字不碰。
- 寫入前必經使用者確認——教訓寫錯比沒寫更糟。
