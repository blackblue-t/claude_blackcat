---
name: writing-extensions
description: Use when adding or changing anything under .claude/ (or the blackcat repo itself) -- deciding whether it should be a hook, CLAUDE.md rule, skill, command or agent; writing a skill description that actually gets recalled; checking the model really complies. Load before creating a new skill, command, hook or rule, or when an existing rule or skill keeps being ignored.
---

# 擴充決策表

要加東西進 `.claude/` 之前先讀。它處理的是**選錯層**：該用程式擋的事寫成文字，
該按需載入的事做成常駐。

## 1. 該做成哪一層

依序問，第一個「是」就決定：

| 問 | 是 → 放這裡 | 為什麼 |
|---|---|---|
| 工具呼叫**當下**能用程式判斷對錯？ | Hook（PreToolUse，`exit 2` 擋下、stderr 回給模型） | 唯一擋得住的地方。判斷得出來就別靠自律 |
| 某個事件**當下**要把資訊塞進對話？ | Hook（SessionStart／UserPromptSubmit／PostToolUse 的 `additionalContext`） | PreToolUse 不支援 `additionalContext` |
| **每個**任務都適用，而且不長？ | CLAUDE.md（或它 `@import` 的檔） | 常駐的成本是稀釋其他規則的注意力，不只 token |
| 只在特定情境適用？ | Skill | 代價是要被想起來，`description` 決定生死 |
| 使用者會主動叫它？ | Command | 指令內文提到 agent 就等於授權派它 |
| 需要獨立 context、專屬流程？ | Agent | 價值是不讓人跳步、不污染主 context，不是比較聰明 |

**判準：這件事有沒有機器判斷得出來的時機？** 有就用 hook。不要問「寫清楚一點會不會有用」。

### blackcat 實際選錯又改掉的例子

| 原本 | 為什麼失效 | 改成 |
|---|---|---|
| 筆記風格做成 skill | 每則筆記都適用，skill 的自動觸發不可靠 | 全域 CLAUDE.md `@import` notes-style.md（v26.9.1） |
| 檔案相關的教訓寫進 CLAUDE.md | 常駐佔位，而且要改那個檔時不一定想得起來 | `.claude/learned/` ＋ pitfall-gate hook，改到那個檔才貼出來 |
| 審查自己寫一份流程 | 跟內建 `/code-review` 重疊、品質較差 | `/review-code` 只當外殼，核心呼叫內建（v26.10.1） |
| 並行任務做完沒有統一回報 | 主 session 只能猜誰成功 | 任務檔固定段落要求 `result:` 回報碼，dispatcher 照碼分流 |

## 2. 同一份知識存在幾個地方

答案是 1 就沒問題。是 2 → 指定唯一來源，其他改成一句指標：

```markdown
清單以 `ui-style-compliance` 階段 3 為唯一來源，這裡不重述。
```

多層架構最常見的壞法不是層多，是同一張表放兩處然後漂開。

## 3. 寫 skill 的 description

skill 只有被喚起才載入，喚起的唯一依據是 `description`。

**寫觸發條件，不寫內容摘要。**

| 不好（內容摘要） | 好（觸發條件） |
|---|---|
| `PostgreSQL 索引知識` | `Use when 設計 schema、寫 SQL 或查詢變慢時` |
| `測試覆蓋率標準` | `Use when writing or fixing tests, running /tdd, deciding coverage targets` |

- 開頭用 `Use when …`，逼自己寫情境
- 放使用者實際會說的話（「說人話」「這段好 AI」）
- 用錯代價立即可見的，用 `MUST BE USED before …`（`package-manager`、`ui-style-compliance`）

## 4. 加進 CLAUDE.md 之前的三道判準

| 問 | 答「否」就別寫 |
|---|---|
| 任何任務都適用嗎？ | 只在特定情境成立 → 做成 skill |
| 模型本來就不會這樣做嗎？ | 模型預設就會做 → 寫進來只是稀釋注意力 |
| 別處還沒有唯一來源嗎？ | 已經有 → 寫指標，不要抄 |

## 5. 怎麼知道它真的生效

hook 可以用腳本測（餵 JSON、看 exit code）。skill、command、CLAUDE.md 是給模型讀的文字，
只能看模型在有它和沒它時行為差多少：

1. 先在**沒有**這份擴充時，用真實的開場 prompt 讓模型做那件事，逐字記下它跳過的理由
2. 針對那些理由寫擴充（不是針對想像中的理由）
3. 同一個 prompt 再跑，確認行為變了
4. 找新的理由，補進去，再驗

可以用 `claude -p "<prompt>"` 批次跑。

## 6. 改完的連帶檢查（blackcat repo）

- 新增或刪除 skill、command、agent、output style → 跑 `bash scripts/check-counts.sh`，
  它會列出 README 計數、安裝器 preset 名單、README 沒提到的項目
- 改安裝腳本 → 確認是純 ASCII（cmd 讀 UTF-8 有 bug）
- 改到使用者看得到的行為 → README 版本表加一列

## 反模式

- 判斷得出來的事寫成文字規則
- 同一張表放兩處
- `description` 寫內容摘要
- 沒問「每個任務都適用嗎」就加進 CLAUDE.md
- 加了擴充就當它生效，沒有驗證
