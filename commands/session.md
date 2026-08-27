---
description: 多 session 分工看板：宣告這個 session 的角色（主責/審查）、看誰在做什麼、釋放角色。用法 /session own|review|who|free [說明]。
model: sonnet
---
<!-- 模型路由：讀寫看板是機械活，sonnet 就夠。 -->

# Session 分工看板（/session）

多個 Claude session 同時開在一個專案時，用一份**檔案看板**協調誰負責
什麼——`.claude/session-board.md`。檔案為主是刻意的：Claude Code 的
跨 session 訊息（ListAgents / SendMessage）**不支援原生 Windows**，
看板檔在哪個平台都能用；有訊息工具時再拿來即時通知。

用法：`/session own 我負責主線開發` / `/session review` /
`/session who` / `/session free`。

## own — 宣告主責

這個 session 是專案的主責：**其他 session 要動這個專案，先問過它**。

1. 取得識別資訊：`git branch --show-current`、當前工作目錄、
   `date` 時間戳。有 `ListAgents` 工具就一併記下自己的 agent 名稱。
2. 寫入/更新 `.claude/session-board.md` 的 owner 段落：

   ```markdown
   <!-- blackcat:session-board -->
   ## owner
   - who: <agent 名稱或「主 session」>
   - branch: <分支>
   - since: <時間>
   - doing: <$ARGUMENTS 的說明，沒給就寫「主線開發」>
   - files: <目前主要動的檔案或目錄，可留空>
   ```

3. **硬接線**（第一次登記主責時做一次）：問使用者要不要在專案
   `CLAUDE.md` 加一行——skill 的自動觸發是機率性的，CLAUDE.md 每個
   session 必載入，才擋得住別的 session 亂動：

   ```markdown
   <!-- blackcat:session-board -->
   本專案可能有多個 Claude session 同時工作。改任何檔案前先看
   `.claude/session-board.md`，落在別人 `files:` 範圍內的先協調過再動。
   <!-- /blackcat:session-board -->
   ```

   已有這個標記就跳過。使用者說不要就不加。
4. 告知使用者：已登記為主責，其他 session 跑 `/session who` 就看得到。

## review — 宣告審查站

這個 session 專職審查，**不主動改程式碼**（修復由主責 session 做——
修/審分離是流程的核心）。同樣寫入看板的 `## reviewer` 段落，並附一句
「有東西要審就叫我，或直接跑 /review-code」。

## who — 看目前分工

1. 讀 `.claude/session-board.md` 印出 owner / reviewer / 其他登記者。
2. 有 `ListAgents` 工具 → 一併列出目前可連線的 session，標明哪些
   有在看板上、哪些沒登記。
3. 看板不存在 → 說明「還沒有人登記」，並提示可以用 `/session own`。
4. **偵測過期**：登記超過 8 小時沒更新 → 標「可能已結束」，提醒
   使用者確認後可用 `/session free` 清掉。

## free — 釋放角色

把自己的段落從看板移除（只移除自己那段，不動別人的），回報現況。

## 其他 session 該遵守的規矩

看板存在且 owner 不是自己時，**動手改檔案之前**：

- 要改的檔案落在 owner 的 `files:` 範圍內 → 先協調：
  有 `SendMessage` 就直接發訊息問；沒有（Windows）就**停下來告訴
  使用者**「這些檔案由 <owner> 負責，要我繼續嗎」，得到同意才動。
- 範圍外的檔案 → 直接做，但在看板加一行自己的登記（避免下一個人重複）。
- 只讀不寫（查資料、看程式碼）→ 不用問，直接做。

## 鐵則

- 看板只記「誰在做什麼」，**不是鎖**——它擋不住任何人，作用是讓
  你和其他 session 知道現況，避免撞車。真正的隔離用
  `/dispatch`（worktree + 分支）。
- 只動 `<!-- blackcat:session-board -->` 標記區塊，檔案其他內容不碰。
- 這份看板是本機協調用的暫時狀態，建議加進 `.gitignore`。
