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

**跟 `/verify` 的分工**：verify 問「跑得起來嗎」（跑指令看紅綠），
本指令問「寫得對嗎」（讀 diff 找工具報不出的錯）。所以下面第 0 步
先把 verify 的檢查當門檻跑一次。

## 流程

### 0. 機器檢查門檻（先跑，紅了就別審）

跑專案的 build / type / lint / test（等同 `/verify` 的檢查）。

- **紅的** → 停下，回報失敗內容，**不進入審查**——建置壞掉的程式碼
  不值得花貴模型逐行看，先修好再回來。
- **綠的** → 記下結果（審查結論裡要附），進入下一步。
- 剛剛才跑過 `/verify` 且之後沒有新變更 → 直接沿用那次結果，不重跑。

### 1. 決定審查範圍

- 讀 `.claude/worklog.md`，取**上次審查（或提交）之後**的所有條目，
  彙整其 `files:` 清單。
- **並行任務的紀錄**在 `.claude/worklog.d/*.md`（blackcat-dispatch 的
  worktree session 各寫一份，合併後一起出現）——全部讀進來，範圍照樣
  以各檔的 `files:` 彙整。dispatch 合併後的審查基準用
  `git diff <合併前的 base>...HEAD`。
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
- **測試品質**：拿 UI 文案當斷言（改文字就紅）、快照全包、為覆蓋率
  湊數的測試——標 `[fix]`，要求改用 role / data-testid 與行為斷言,
  或直接刪掉湊數的。

### 3. 每個 finding 標分級（判斷權在審查者，用清單不用感覺）

- **`fix`**：可直接修。必須**同時**滿足：不改公開介面/函式簽名/API 格式、
  不改資料格式或 schema、不新增依賴或檔案（測試檔除外）、不違背
  requirements 文件寫明的行為。
- **`design`**：上面任一條不滿足，但需求本身沒問題 → 回 `/plan` 調架構。
- **`requirement`**：問題出在需求矛盾或漏洞 → 回 `/grill` 補需求。

**只要有一個 `design`/`requirement` 級 finding，整輪不進入直接修流程**
——先解決高層級問題（它可能讓小修白做）。

### 4. 結論寫回 worklog

把審查結論**追加**到 `.claude/worklog.md`：

```markdown
## Review (round N)
- verdict: pass          # 或 needs-fix / escalate
- checks: build/type/lint/test 全綠   # 第 0 步的結果
- scope: <審查了哪些檔案>
- findings:
  - [fix] <檔案:行> <問題與建議>       # pass 且無發現時寫 none
  - [design] <...>
```

### 5. 收尾（依 verdict）

- **pass** → 提醒使用者跑 `/commit` 完成提交。
- **needs-fix**（全部是 `fix` 級）→ 列出待修項，指示：**由主 session
  （執行模型）修**，不是本 session——修的人與審的人分離。主 session
  每修一項在 worklog 追加 `## Fix:` 條目（含 files/did/verify）。
- **escalate**（含 `design`/`requirement` 級）→ 指路回 `/plan` 或
  `/grill`，本輪不修任何東西。

### 6. 限縮重審（第 2 輪起）

worklog 裡已有 `## Review (round N)` 和對應 `## Fix:` 條目時，本次是
限縮重審：

- **只看**上一輪每個 finding + 對應的 Fix 條目 + 修復檔案的 diff +
  驗證結果——確認真的修了、沒修出新問題。上輪已 pass 的部分不重看。
- 修復的 diff 要親自看，不是聽 Fix 條目說修好了就信。
- **上限 2 輪**：同一個 finding 第 2 輪還過不了，或累計已審 2 輪，
  寫 `verdict: escalate` 停下來交使用者裁決，不准第 3 輪自動循環。
