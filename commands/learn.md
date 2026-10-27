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

## 寫到哪裡：先分流

- **跟特定檔案有關**（「改 `src/report/*.java` 的日期要先轉 UTC」）→
  寫成 `.claude/learned/<YYYY-MM-DD>-<slug>.md`，格式照同目錄的
  `_TEMPLATE.md`，`files:` 填會觸發這個坑的檔案樣式。之後只有在 Claude
  要改到那些檔案時，pitfall-gate hook 才會把它貼出來，平常不佔 context。
  `files:` 一定要填對：填錯或空著，這條教訓永遠不會出現。
- **跟整個專案有關、不綁特定檔案**（「跑測試前要先起 docker compose」）→
  寫進 CLAUDE.md 的標記區塊（見下方流程第 3 步）。這裡每個 session 都會
  載入，所以只收真正全域的。

拿不準時優先寫進 learned：綁得到檔案的教訓，綁檔案比常駐有效。

## 流程

1. 回顧本次 session，列出候選教訓（通常 0-3 條；沒有就老實說沒有，
   不硬湊），每條標明要寫進 learned 還是 CLAUDE.md。
2. **去重**：讀 `.claude/learned/` 與 CLAUDE.md 的 `<!-- blackcat:lessons -->`
   區塊，已有等價教訓就跳過或合併改寫。
3. 向使用者列出「準備寫入的教訓」與各自的去處，確認後寫入。CLAUDE.md 的
   區塊格式：

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
