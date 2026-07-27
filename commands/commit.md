---
description: 依 worklog 提交已通過審查的變更並歸檔 worklog。輕量收尾工作，用 sonnet 就夠。
model: sonnet
---
<!-- 模型路由：提交是機械收尾，用 sonnet。總表見 README「模型路由」。 -->

# 提交（worklog 收尾）

前提：`/review-code` 已留下 `verdict: pass`。這個指令做機械收尾——
staging、commit message、合併回主分支（並行路線）、歸檔——不做審查。

兩種情境，先判斷再走對應流程：

- **一般路線**：主 session 直接實作，變更還在 working tree 未提交
  → 走完整流程（步驟 1-5），若在分支上最後做步驟 6。
- **並行路線**（blackcat-dispatch）：工作**已經**在任務分支 commit 並
  合進整合分支（`integrate/*` 或 feature 分支）。若 working tree 乾淨
  → 跳過步驟 2-4，直接步驟 6 **合併回 main**。若有**審查修復**
  （worklog 有 `## Fix:` 條目、tree 不乾淨）→ 先做步驟 5.5 把修復
  commit 在整合分支上，再走步驟 6。

## 流程

1. **檢查前提**：讀 `.claude/worklog.md` 與 `.claude/worklog.d/*.md`，
   最新一條 `## Review` 必須是 `verdict: pass` 且在它之後沒有新的變更
   條目。不符合就停下，提示先跑 `/review-code`（needs-fix 未修完也算
   不符合）。
2. **Staging**：只 stage worklog 各條目 `files:` 列出的檔案（用
   `git add <file>...`，不用 `git add -A`）。`git status` 若顯示範圍外
   的變更，列出來提醒但不動它們。
3. **Commit message**：依 worklog 條目彙整，遵循該專案既有的 commit
   風格（先看 `git log --oneline -5`）；預設 Conventional Commits
   （`feat:`/`fix:`/`refactor:`…），主旨一句話，body 列要點。
4. **提交並確認**：`git commit` 後用 `git log -1 --stat` 確認內容。
   **不推送**——push 由使用者決定。
5. **歸檔 worklog**：把 `.claude/worklog.md` 與 `.claude/worklog.d/*.md`
   （並行任務的紀錄，如果有）合併移到
   `.claude/worklog-archive/<YYYY-MM-DD>-<短描述>.md`（目錄不存在就建），
   讓下一輪工作從乾淨的 worklog 開始。歸檔前在檔尾追加：

   ```markdown
   ## Commit
   - hash: <short hash>
   - message: <主旨>
   ```

5.5 **提交審查修復**（並行路線、有 `## Fix:` 條目時）：只 stage Fix
   條目 `files:` 列出的檔案，在整合分支上 commit（訊息如
   `fix: review round N fixes`）——修復歷史留在整合分支，main 拿到
   完整的一包。

6. **合併回主分支**（在整合分支或 feature 分支上時）：
   - 確認主分支名（`main` 或 `master`，看 `git branch`）。
   - `git switch <主分支>` → `git merge --no-ff <整合分支>`
     （--no-ff 保留「這批工作是一個整體」的歷史）。
   - 合併訊息引用計畫標題。衝突理論上不會有（整合分支從主分支出發），
     真遇到就停下請使用者裁決。
   - 收尾提醒使用者：檢查 `git log` 沒問題就自行 push；並行路線再跑
     `/dispatch --clean` 收掉 worktree 與任務分支。**不代替使用者 push。**
