---
description: 專案管理第一站：收斂需求後拆出 WBS（里程碑、任務、依賴、預估），寫進 .claude/taskmaster-data/wbs.md。之後用 /task-next 一個一個做。
model: claude-fable-5
---
<!-- 模型路由：拆解與估時是推理工作，跟 /plan 同級。要降級改 model: 即可。 -->

# 專案初始化（/task-init）

WBS 的格式與更新規則以 `wbs` skill 為唯一來源，**寫檔前先讀它**。

已有 `.claude/taskmaster-data/wbs.md` → 不要覆蓋。問使用者要「追加里程碑」（走 `/task-add`）
還是「重建」（舊檔先改名成 `wbs.<日期>.bak.md`）。

## 步驟 1：需求來源

依序找，找到就以它為準，不重問裡面已經有的：

1. 使用者指定的文件（需求書、規格）
2. `.claude/plans/*-requirements.md`（`/grill` 的產出）、`.claude/plans/*-spec.md`（`/spec` 的產出）
3. `README.md`、`CLAUDE.md` 的專案描述

都沒有或很薄 → 用 `AskUserQuestion` 一次一題問：

1. 開發情境：demo（一天內、驗證想法）／mvp（一週內、內部工具）／full（正式產品、多人）
2. 要解決什麼問題、給誰用
3. 最重要的 3～5 個功能
4. 技術約束（語言、框架、部署環境）
5. 時程與目標日

需求還很模糊、使用者自己也說不清 → 建議先跑 `/grill`，問完再回來。

## 步驟 2：補問兩題（一定要有）

1. **這個版本明確不做什麼**（non-goals）——防範圍蔓延最有效的一題，寫進 WBS 的「不做」段。
2. **最大的未知或風險**——直接進「風險與阻塞」表。

## 步驟 3：回述確認

把理解到的需求分段唸回給使用者（問題、使用者、核心功能、不做、風險、約束、仍未釐清），
問「哪裡要修正？」。改完再回述那一段。**這一步不能跳**：誤解會在 WBS 和每份計畫裡被放大。

## 步驟 4：拆 WBS

- 依里程碑分節（demo 也至少一個 `M1`）。里程碑是**使用者看得到的成果**，不是技術層
  （「會員可以登入」，不是「後端」）。
- 任務顆粒：一個任務 0.5h～1 天，做完能單獨驗證。超過一天就再拆。
- 每個任務標優先、依賴、預估。預估拿不準就寫區間的上限，並在「仍未釐清」記一筆。
- 會互相獨立、檔案不重疊的任務，在任務名後面不用註記，`/task-next` 會自己判斷能不能並行。
- JS／TS 或 Python 專案、還沒有 `.claude/package-manager.json` → 第一個里程碑加一個任務
  「選定套件管理器」（做法就是跑 `/pm-choose`）。
- 有前端、還沒有 `.claude/ui/DESIGN.md` → 加「定義 UI 風格」任務（做法是 `/ui-style`）。

## 步驟 5：確認後寫檔

給使用者看完整 WBS（里程碑、任務表、總預估、風險），確認後才寫：

- `.claude/taskmaster-data/wbs.md`（照 `wbs` skill 第 1 節，現況區照第 4 節算好）
- 時間紀錄不進 git：`.claude/taskmaster-data/sessions/.gitignore`，內容一行 `*`

## 完成訊息

```
WBS 已建立：.claude/taskmaster-data/wbs.md
里程碑 N 個、任務 N 項、總預估 Nh

下一步：
  /task-next     取下一個任務開始做
  /task-status   看進度
  /time-log      看實際花的時間（自動記錄，不用手動打卡）
```
