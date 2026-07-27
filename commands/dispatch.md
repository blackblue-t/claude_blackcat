---
description: 在 Claude Code 內操作並行任務調度：預覽、執行、盯進度、合併、清理。包裝 blackcat-dispatch 終端指令。
model: sonnet
---
<!-- 模型路由：調度是機械操作（跑指令、盯狀態、報結果），sonnet 就夠。
     真正花腦的執行發生在各 worktree 的 headless session 裡。 -->

# 並行任務調度（/dispatch）

把 `/plan` 匯出的 `.claude/tasks/*.md` 交給 `blackcat-dispatch` 並行執行。
你（Claude）負責跑指令、盯進度、把結果整理給使用者。

參數直通：`$ARGUMENTS` 原樣傳給 `blackcat-dispatch`
（例：`/dispatch --dry-run`、`/dispatch --max 3`、`/dispatch --merge`、
`/dispatch --status`、`/dispatch --clean`）。

## 流程

1. **前置檢查**：
   - `command -v blackcat-dispatch`——找不到就請使用者重跑全域安裝
     （blackcat repo 的 `install.bat` / `install.sh`），不要自己找路徑硬跑。
   - 無參數（= 要執行任務）時先跑一次 `blackcat-dispatch --dry-run`
     給使用者看會啟動哪些任務、預設併發數，**確認後才真正執行**。
2. **執行**：`blackcat-dispatch $ARGUMENTS`。
   - 執行模式（無參數或只有 --max）耗時較長：用背景執行，期間每
     30-60 秒跑 `blackcat-dispatch --status` 回報一次進度，不要傻等。
   - `--dry-run` / `--status` / `--merge` / `--clean` 都很快，直接前景跑。
3. **報告**：
   - 執行完成：整理每個任務 done/FAIL；FAIL 的把
     `.claude/dispatch-logs/<slug>.log` 的關鍵錯誤摘出來（不要整份貼）。
   - 合併完成：提醒「開**新** session 跑 /review-code，然後 /commit」。
     不要在本 session 直接接著 review——跨 session 審查是流程的刻意設計。
   - 合併衝突：dispatcher 會停下。幫使用者看衝突檔案並提出解法，
     解完 commit 後再跑 `/dispatch --merge` 續行。

## 邊界

- 不改任務檔內容（那是 /plan 的產出）；任務不對就回去改計畫重新匯出。
- 不代替使用者做「要不要執行」的決定；dry-run 確認是必經步驟。
- 不 push、不動 worktree 內部——一切透過 blackcat-dispatch 操作。
