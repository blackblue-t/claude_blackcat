---
description: 開發時間報表：按日、按 WBS 任務統計實際花的時間與費用。紀錄由狀態列自動寫，不用手動打卡。
model: sonnet
---
<!-- 模型路由：讀檔加總，sonnet 就夠。 -->

# 開發時間報表（/time-log）

用法：`/time-log`（最近 7 天，按日）、`--by-task`（按 WBS 任務）、`--today`、`--week`、
`--month`、`--all`。

## 資料怎麼來

全域狀態列（`~/.claude/statusline-command.sh`）在專案有 `.claude/taskmaster-data/` 時，
每次更新就寫一份分段紀錄到 `.claude/taskmaster-data/sessions/<session_id>-<段>.json`：

```json
{"session_id":"abc","seg":1,"task":"2.2","date":"2026-10-27","start":"14:07","ms":3600000,"cost_usd":1.25}
```

- 一個 session 中途換任務（`/task-next` 改了 `.current-task`）就開新的一段，時間不會算錯任務
- `ms` 是這一段的**牆上時間**（含你在看、在想的時間，不只模型在跑的時間）
- `task` 空字串＝沒有指定任務；`parallel`＝並行派工期間
- 舊版留下的 `.claude/taskmaster-data/timelog.jsonl`（`duration_ms` 欄位）一併讀進來

沒有任何紀錄 → 「尚無時間紀錄。專案要有 `.claude/taskmaster-data/`（`/task-init` 會建），
而且要用 blackcat 的全域狀態列。」

## 計算

1. 讀所有 `sessions/*.json` 與 `timelog.jsonl`，依 `--` 參數篩日期
2. 按日：每日的 session 數（不重複的 `session_id`）、時間合計、費用合計
3. 按任務：依 `task` 加總，名稱與預估從 `wbs.md` 查，查不到再查 `wbs-archive.md`；
   空字串歸「未指定」、`parallel` 歸「並行派工」
4. 時間寫成 `Xh Ym`，不到 1 分鐘寫 `<1m`；單日超過 8 小時在那一列後面標「偏長」

## 輸出

```
開發時間（最近 7 天）
日期         Sessions  時間       費用
2026-10-27   3         4h 35m     $4.28
2026-10-26   2         2h 10m     $1.85
合計         5         6h 45m     $6.13
```

```
任務時間
#      任務           預估    實際      差異      狀態
2.1    建立會員資料表  2h      1h 50m    -10m      完成 10-20
2.2    登入流程        4h      5h 10m    +1h 10m   進行中
未指定  -              -       0h 40m    -         -
```
