---
description: 依 worklog 提交已通過審查的變更並歸檔 worklog。輕量收尾工作，用 sonnet 就夠。
model: sonnet
---
<!-- 模型路由：提交是機械收尾，用 sonnet。總表見 README「模型路由」。 -->

# 提交（worklog 收尾）

前提：`/review-code` 已在 `.claude/worklog.md` 留下 `verdict: pass`。
這個指令做機械收尾——staging、commit message、歸檔——不做審查。

## 流程

1. **檢查前提**：讀 `.claude/worklog.md`，最新一條 `## Review` 必須是
   `verdict: pass` 且在它之後沒有新的變更條目。不符合就停下，提示先跑
   `/review-code`（needs-fix 未修完也算不符合）。
2. **Staging**：只 stage worklog 各條目 `files:` 列出的檔案（用
   `git add <file>...`，不用 `git add -A`）。`git status` 若顯示範圍外
   的變更，列出來提醒但不動它們。
3. **Commit message**：依 worklog 條目彙整，遵循該專案既有的 commit
   風格（先看 `git log --oneline -5`）；預設 Conventional Commits
   （`feat:`/`fix:`/`refactor:`…），主旨一句話，body 列要點。
4. **提交並確認**：`git commit` 後用 `git log -1 --stat` 確認內容。
   **不推送**——push 由使用者決定。
5. **歸檔 worklog**：把 `.claude/worklog.md` 移到
   `.claude/worklog-archive/<YYYY-MM-DD>-<短描述>.md`（目錄不存在就建），
   讓下一輪工作從乾淨的 worklog 開始。歸檔前在檔尾追加：

   ```markdown
   ## Commit
   - hash: <short hash>
   - message: <主旨>
   ```
