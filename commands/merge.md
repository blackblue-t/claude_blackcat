---
description: 把完成的任務分支合併進整合分支（/dispatch --merge 的薄包裝）。合併回 main 是 /commit 的事。
model: sonnet
---

# 合併任務分支（/merge）

`/dispatch --merge` 的別名，給心智模型裡有「merge 是獨立一站」的使用者。
執行 `blackcat-dispatch --merge` 並依 `/dispatch` 的規則處理（衝突停下
協助解決、完成後提醒開新 session 跑 `/review-code`）。

注意兩層合併的分工：本指令只把**任務分支合進整合分支**（main 不動）；
**合併回 main** 是 `/commit` 在 `/review-code` pass 之後做的事，本指令
不越界。
