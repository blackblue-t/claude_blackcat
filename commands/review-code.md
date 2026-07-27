---
description: 審查 worklog 記錄的變更範圍（不掃全專案），結論寫回 worklog，通過後交給 /commit。
model: claude-fable-5
---
<!-- 模型路由：審查用 Fable 5。要降級改這裡的 model: 即可，例如 model: opus。
     總表見 README「模型路由」。 -->

# 程式碼審查（worklog 範圍）

審查範圍**只來自紀錄，不掃全專案**——這是刻意設計：執行階段
（worklog skill）已把動過的檔案與意圖記在 `.claude/worklog.md`，
審查只需要「紀錄 + 這些檔案的 diff」。

## 流程

### 1. 決定審查範圍

- 讀 `.claude/worklog.md`，取**上次審查（或提交）之後**的所有條目，
  彙整其 `files:` 清單。
- worklog 不存在或沒有新條目時退回 git 範圍：`git status` +
  `git diff`（含 staged 與未 staged）的變更檔案。兩者都空就回報
  「沒有可審查的變更」並結束。
- `$ARGUMENTS` 有給路徑時，把範圍再縮小到該路徑之下。

### 2. 審查

對範圍內每個檔案：讀 worklog 的 did/why 了解意圖，看 `git diff
<file>` 的實際變更，必要時才打開整個檔案。檢查：

- **正確性**：變更是否達成 worklog 宣稱的意圖？有沒有邊界條件、錯誤處理漏洞？
- **安全**：秘密硬編碼、注入、未驗證輸入。
- **一致性**：命名、風格是否貼合周邊程式碼；有沒有多餘的複雜度。
- **驗證缺口**：worklog 標了 `verify: 未驗證` 的條目，指出該補什麼驗證。

### 3. 結論寫回 worklog

把審查結論**追加**到 `.claude/worklog.md`：

```markdown
## Review
- verdict: pass          # 或 needs-fix
- scope: <審查了哪些檔案>
- findings:
  - <嚴重度> <檔案:行> <問題與建議>   # pass 且無發現時寫 none
```

### 4. 收尾

- **pass** → 提醒使用者跑 `/commit` 完成提交。
- **needs-fix** → 列出待修項；修完後重跑 `/review-code`，新一輪結論
  會再追加一條 Review 條目。
