---
description: 無人值守做「一個」WBS 任務：自己選任務、寫計畫、實作、驗證、審查、提交，最後回報狀態碼。給 bcd --loop 在全新 session 裡呼叫用，不是給人手動打的（手動請用 /task-next）。
---
<!-- 不設 model:：由 bcd --loop 的 --model 決定（預設 opus）。 -->

# 自動任務（/task-auto）

你在一個**沒有人看著**的全新 session 裡，由 `bcd --loop` 啟動。這次只做**一個** WBS 任務，
做完就結束；下一個任務會由迴圈另開一個全新的 session。不能問使用者任何問題。

**結束前一定要寫狀態檔** `.claude/dispatch-logs/loop-status`（一行），迴圈靠它決定要不要繼續。
任何情況下都要寫，包含失敗：

| 內容 | 意思 |
|:--|:--|
| `DONE <編號>` | 任務完成並已提交，迴圈繼續 |
| `COMPLETE` | WBS 沒有可做的任務了 |
| `BLOCKED <編號> <一句原因>` | 做不下去，迴圈停下等人處理 |
| `NEEDS_HUMAN <編號> <一句原因>` | 關鍵等級的任務，計畫要人確認，迴圈停下 |

## 步驟

1. **讀狀態**：`.claude/taskmaster-data/wbs.md`（格式照 `wbs` skill）。有任務是「進行中」→
   它是上一個 session 沒做完的，先看 `git log -5` 和 `.claude/plans/` 裡帶同一個 `wbs:` 的計畫，
   從計畫的 `current_phase` 接著做；沒有計畫就當新任務重做。
2. **選任務**：照 `task-next.md` 步驟 2 的排序選一個（待處理、依賴都完成、優先最高）。
   沒有候選：全部完成寫 `COMPLETE`；只剩阻塞的寫 `BLOCKED - 剩下的任務都被阻塞`。結束。
3. **判等級**（照 `go.md` 階段 0 的表）：
   - 關鍵 → 不做。寫 `NEEDS_HUMAN <編號> 關鍵任務：<碰到哪一項>`，結束。
   - WBS 那一列加上需求文件還是看不出要做什麼、或驗收條件不明 → 不要猜。把那一列改「阻塞」，
     在風險表記「需求不明：<缺什麼>」，提交這個 WBS 變更，寫 `BLOCKED <編號> 需求不明`，結束。
4. **標進行中**：WBS 那一列改「進行中」、重算現況區。不寫 `.current-task`（headless 沒有狀態列，
   記不到時間）。
5. **計畫**：照 `plan.md` 的格式寫 `.claude/plans/<日期>-<slug>.md`（帶 `wbs:`、命名表），
   **不等確認**——使用者在 `/task-init` 確認過這一列，就是授權。計畫只做這一列寫的事，
   碰到 WBS「不做」清單的東西一律不做。
6. **實作與驗證**：照專案的 skills 與 rules 做（lean 是 ponytail，strict 是 TDD），worklog 照記。
   做完跑專案的 build／type／lint／test。紅的就修，**同一個錯修三次還是紅** → 第 9 步的失敗處理。
7. **審查**：`claude -p "/review-code" --dangerously-skip-permissions`，讀 worklog 的 verdict。
   needs-fix 就修完再審，最多 2 輪；escalate 或 2 輪後還沒過 → 第 9 步的失敗處理。
8. **提交**：照 `commit.md` 步驟 1～6（含 WBS 同步：那一列改「完成 MM-DD」）。**不推送、
   不問推送**（跳過步驟 7 的推送）。確認 `git status` 乾淨後寫 `DONE <編號>`，結束。
9. **失敗處理**：`git stash -u -m "task-auto <編號> 失敗的嘗試"` 把沒做完的變更收起來（不丟），
   WBS 那一列改「阻塞」、風險表記原因與 stash 名稱，提交這個 WBS 變更，寫
   `BLOCKED <編號> <原因>`，結束。

## 鐵則

- 一個 session 一個任務。做完不要順手做下一個。
- 不 push、不 merge 到別的分支、不切分支、不刪分支、不 `reset --hard`。
- 不改 WBS 的範圍：不新增任務、不改別列的預估與優先。發現漏掉的工作，寫在這一列計畫檔的
  「後續建議」，讓人決定要不要 `/task-add`。
- 不安裝新的全域工具、不改 `.claude/` 底下的指令與設定、不碰 `.env`。
- 狀態檔只寫一行，寫在最後。
