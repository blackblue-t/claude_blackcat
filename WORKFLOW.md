# blackcat 工作流

## 設計原則（為什麼長這樣）

- **工作流屬於專案，複製即擁有。** 裝進專案的檔案就是專案的——改了不影響別的專案，換機器 clone 下來就有；全域只放個人偏好（statusline、模型預設）。不用 plugin 發佈機制：一個人用，不需要訂閱與版本協商的複雜度。
- **同一概念只留一層。** TDD 用 skill 就不再疊 agent + command + output-style——同一件事有多層指令時，模型的行為變得不可預測。
- **最小可行是預設（lean）。** 能不寫就不寫、先復用再手寫；需要嚴格再升 strict，不反過來——預設值決定了 90% 的日常行為，預設就該是低摩擦的那個。
- **記憶進檔案，不留在對話。** 計畫、session 記錄（含失敗清單）、worklog 全部落地 `.claude/`——對話是暫存、檔案是記憶；計畫不依賴任何任務管理系統也能單獨運作。
- **零常駐 hooks。** 每次 tool call 都執行的 hook 是常駐稅——會拖慢每一步、且靜默失敗難察覺。需要的機制做成選配（`--taskmaster`），用得到才裝。
- **去 AI 味分語言。** 中文（台灣用語）與英文各一套改寫紀律，依輸出語言自動分工；不收簡體語境的版本，與台灣用語方向矛盾。

參考過的專案集中列在 README 的「參考來源」。

## 核心流程

```
研究 → /plan（存檔確認）→ 實作 → /verify → /save-session
                              │
              lean:  ponytail 階梯，最小 check
              strict: /tdd 紅綠重構，80%+ 覆蓋
```

兩種 preset 共用同一條流程，只有「實作」那一段哲學不同：

| | `--lean`（預設） | `--strict` |
|:--|:--|:--|
| 適用 | side project、原型、快速迭代 | 正式產品、多人協作 |
| 實作 | ponytail 階梯（能不寫就不寫） | tdd-workflow（先測試後實作） |
| 測試 | 非平凡邏輯留一個最小 check | 80%+ 覆蓋率，關鍵邏輯 100% |
| Review | `/ponytail-review`（抓過度工程） | `/review-code`（抓正確性） |

## 持久化機制（跨 session 的記憶）

對話會結束，檔案會留下。兩個目錄都在專案的 `.claude/` 裡，跟著專案進 git：

### `.claude/plans/` — 計畫

`/plan` 確認後寫入 `<YYYY-MM-DD>-<slug>.md`：

```yaml
---
status: active        # active → done
current_phase: 1      # 目前執行到第幾階段
files: [src/a.py]     # 會動到的檔案
updated: 2026-07-27
---
```

`/tdd`（或 lean 模式下的實作）開始時先掃 `plans/` 裡 `status: active` 的計畫，找到就從 `current_phase` 接續，每完成一階段就更新狀態。`/verify` 全過後把 status 改成 `done`。**新 session 開始不用重新解釋做到哪。**

### `.claude/sessions/` — session 記錄

`/save-session` 寫入 `<YYYY-MM-DD>-<主題>.md`，最重要的段落是**「失敗的部分（和原因）」**——沒有這段，下個 session 會盲目重試已經失敗過的方法。

## 一天的樣子

```
上午開新 session
 ├─ 有 active plan？ → 直接接續，不重新規劃
 ├─ 沒有 → 研究 → /plan → 確認 → 存檔
 ├─ 實作（preset 決定哲學）
 ├─ /verify
 └─ 下班前 /save-session（做了什麼、什麼失敗了、下一步）
```

## 原則

1. **同一概念只留一層。** TDD 用 skill 就不要再裝 agent + output-style。
2. **計畫和失敗記錄進檔案，不留在對話裡。** 對話是暫存，檔案是記憶。
3. **lean 是預設。** 需要嚴格再升級到 strict，不反過來。
4. **工作流屬於專案。** 改了不影響別的專案；換機器 clone 下來就有。
