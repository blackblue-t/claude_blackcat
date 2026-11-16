---
description: 不知道現在該打哪個指令時用。讀專案目前的狀態（有沒有 WBS、進行中的計畫、沒審查或沒提交的變更、跟遠端差多少），只告訴你「下一步打什麼、為什麼」，不動任何檔案。
model: sonnet
---
<!-- 模型路由：讀幾個小檔加判斷，sonnet 就夠。建議在新 session 或 /clear 後用，context 小才省。 -->

# 下一步（/next）

只讀、不改檔、不開始做事。輸出固定三段：**現況**（最多 5 行）、**下一步**（一個指令＋
一句理由）、**之後**（接下來一兩步，各一行）。

## 步驟 1：收集狀態（只讀這些，不掃程式碼）

| 看什麼 | 怎麼看 |
|:--|:--|
| git | `git status --short`、目前分支、`git rev-list --left-right --count @{u}...HEAD`（用上次 fetch 的結果，不連網） |
| 並行殘留 | `git worktree list`、有沒有 `integrate/*`、`task/*` 分支 |
| WBS | `.claude/taskmaster-data/wbs.md` 的「現況」區（只讀那一區）與 `.current-task` |
| 計畫 | `.claude/plans/*.md` 裡 `status: active` 的檔名與 `current_phase`（只讀 frontmatter） |
| 並行任務 | `.claude/tasks/*.md` 的 `status:` |
| worklog | `.claude/worklog.md` 最後一個 `## Review` 的 verdict，以及它之後有沒有新條目 |
| 交接 | `.claude/sessions/` 最新一份的「下一步」段落（只讀那一段） |
| 風格 | 有前端檔案時，`.claude/ui/DESIGN.md` 在不在 |

## 步驟 2：照順序判斷，第一個成立的就是下一步

| # | 狀況 | 下一步 |
|:--|:--|:--|
| 1 | 合併或 rebase 做到一半（`git status` 顯示 unmerged、rebase in progress） | 先解衝突，照 `/sync` 的衝突處理 |
| 2 | 落後遠端，或跟遠端分岔 | `/sync` |
| 3 | worklog 最新審查是 needs-fix | 修 findings（主 session 修），修完 `/review-code` |
| 4 | worklog 最新審查是 escalate | 回 `/plan`（design）或 `/grill`（requirement），說明是哪一條 finding |
| 5 | worklog 有新條目還沒審查 | `/review-code`（這個任務是關鍵等級就 `/review-deep`） |
| 6 | 最新審查 pass、變更還沒提交 | `/commit` |
| 7 | 有任務分支做完還沒合併（`.claude/tasks/` 有 done、整合分支沒合回主分支） | `/dispatch --merge`，再 `/review-code` |
| 8 | 有 `status: active` 的計畫 | 「接著做 `<計畫檔名>` 的第 N 階段」，用 `/go 接續 <計畫標題>` |
| 9 | `.current-task` 有值、那一列還是進行中、沒有計畫 | `/task-next`（它會問要接續還是換一個） |
| 10 | 有 WBS、有待處理的任務 | `/task-next`；有好幾個互不相干的任務就建議 `/task-next --parallel`；想放著自己跑就提 `bcd --loop` |
| 11 | 有 WBS、全部完成 | `/task-status`（歸檔里程碑），再問下一個里程碑要做什麼 |
| 12 | 本地有提交還沒推 | `/sync push` |
| 13 | 都沒有 | 看「步驟 3」的規模表，建議 `/go <需求>` 或 `/task-init` |

同時成立好幾條時只講第一條，其餘放「之後」。

## 步驟 3：什麼都還沒開始時，用規模決定走哪條路

問使用者一句：「這次要做的事大概多大？」（已經說了就不問）

| 規模 | 判斷 | 走法 |
|:--|:--|:--|
| 小改 | 一兩個檔、不動邏輯 | `/go <需求>`，會自動走快車道 |
| 一個功能 | 一次做得完（半天到一兩天） | `/go <需求>`：計畫你確認一次，之後自動做完 |
| 幾個相關功能 | 一週內、可以列出 3～10 件事 | `/grill`（問清楚）→ `/task-init`（選 mvp，拆成一張小 WBS）→ `/task-next` 一件一件做 |
| 整個專案 | 超過一週、多個里程碑、要交付文件 | `/grill` → `/spec` → `/task-init`（選 full）→ `/task-next`；每個里程碑做完 `/task-status` 歸檔 |

## 輸出範例

```
現況
- 分支 main，跟遠端一樣新，2 個檔案沒提交
- WBS：M2 會員系統 3/8，進行中 2.2 登入流程
- worklog 有 3 條新紀錄還沒審查

下一步：/review-code
理由：2.2 的實作已經記在 worklog，還沒審查，審查通過才能提交。

之後：/commit → /clear → /task-next
```
