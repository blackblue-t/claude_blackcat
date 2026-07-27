---
name: worklog
description: 執行程式碼修改任務時，把每個有意義的變更即時記錄到 .claude/worklog.md，作為 /review-code 的審查範圍與 /commit 的提交依據。觸發時機：任何會新增或修改程式碼檔案的實作任務（寫功能、修 bug、重構）。不要觸發：純問答、讀碼分析、規劃討論。
---

# Worklog：執行紀錄

執行模型（通常是 Opus）在實作過程中維護 `.claude/worklog.md`，讓後續的
`/review-code`（Fable）**只需讀這份紀錄和列出檔案的 diff**，不必掃整個
專案；`/commit`（Sonnet）也依這份紀錄提交。這是三段模型分工的接力棒。

## 規則

1. **每完成一個有意義的變更就追加一條**（不是每次存檔都寫；以「一個可驗證的小段落」為單位）。
2. **只追加、不改寫**歷史條目。
3. 條目要短——review 靠的是 diff，worklog 只負責「範圍與意圖」。
4. 檔案不存在就建立（含 `# Worklog` 標題）。

## 條目格式

```markdown
## <任務簡述>
- files: src/auth.py, tests/test_auth.py
- did: 新增 token 過期檢查與對應測試
- why: 修 #123 過期 token 仍可通過驗證
- verify: pytest tests/test_auth.py 8 passed
```

- `files:` 一定要列全這條變更動到的檔案——這就是 /review-code 的審查範圍。
- `verify:` 寫實際跑過的驗證指令與結果；沒驗證就寫 `verify: 未驗證` 並說明原因。

## 並行模式（blackcat-dispatch 的 worktree session）

如果你正在 dispatcher 派發的獨立 worktree 裡執行單一任務（dispatch 的
提示詞會明說），紀錄寫到 `.claude/worklog.d/<任務slug>.md` 而不是
`worklog.md`——每個任務一份檔案，合併分支時才不會衝突。格式相同。

## 與 /review-code、/commit 的接力

- 告一段落後提醒使用者跑 `/review-code`（或使用者主動呼叫）。
- `/review-code` 會把審查結論追加進 worklog；`/commit` 只在最新一輪
  審查為 pass 時提交，提交後歸檔 worklog 並重置。
