---
name: session-etiquette
description: MUST BE USED before modifying files in a project that has a .claude/session-board.md, i.e. when several Claude sessions may be working on the same repo at once. Checks who owns what, coordinates before touching another session's files, and keeps the board current. Triggers on the first file edit of a session and whenever the user mentions another session, parallel work, or asks who is doing what. Do not trigger for read-only work or projects with no session board.
---

# Session 禮儀

多個 session 同時開在一個專案時，避免撞車的最小紀律。看板是
`.claude/session-board.md`（由 `/session` 指令維護）。

## 動手改檔案之前

1. 看板不存在 → 這個專案沒在多開，照常做事，不用管本 skill。
2. 看板存在：
   - **自己就是 owner** → 照常做，工作範圍變了就順手更新 `files:`。
   - **owner 是別人，且要改的檔案在他的 `files:` 範圍內** → 先協調：
     - 有 `SendMessage` 工具（macOS / Linux）→ 直接發訊息說明你要改
       什麼、為什麼，等回覆。
     - 沒有（原生 Windows）→ **停下來問使用者**：「這些檔案由
       <owner> 負責中，要我繼續嗎？」得到同意才動。
   - **範圍外** → 直接做，並在看板加一行自己的登記。
3. 只讀不寫 → 永遠不用問。

## 回報

因為協調而等待或改變做法時，明講「因為 <owner> 正在動這些檔案」，
不要默默繞路，也不要默默硬幹。

## 界線

- 看板是**告示牌不是鎖**：它讓大家知道現況，不強制阻擋。需要真正
  隔離就用 `/dispatch`（每個任務獨立 worktree 與分支）。
- 不要為了「先搶」而登記不打算做的範圍。
- 自己的工作結束時把登記清掉（`/session free`），別留過期資訊。
