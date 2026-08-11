---
description: 計畫目錄整理：列出所有計畫的狀態、把完成的整包歸檔、揪出爛尾的問你要續作還是棄置。.claude/plans/ 亂了就跑。
model: sonnet
---
<!-- 模型路由：目錄整理是機械活，sonnet 就夠。 -->

# 計畫整理（/plans）

`.claude/plans/` 的維護原則：**根目錄只放進行中的東西**，完成與棄置的
全部進 `archive/`。本指令隨時可跑，重複跑無害。

## 流程

### 1. 盤點

掃描並分組列出（一行一檔，含 status 與最後更新日）：

- `.claude/plans/*.md`（計畫、requirements、spec）
- `.claude/tasks/*.md`（並行任務檔）

### 2. 歸檔完成的（不用問）

- 計畫 `status: done` → **整包搬**進 `.claude/plans/archive/`：
  計畫本體 + 同 slug 的 `*-requirements.md`、`*-spec.md` 一起走，
  不留孤兒。
- 任務檔 `status: done` 且分支已合併 → 搬進 `.claude/tasks/archive/`。

### 3. 處理爛尾的（要問）

`status: active` 但 `updated` 超過 14 天，或計畫的階段全勾完卻沒標
done——逐個問使用者：

- **續作** → 不動，提示下次直接接續。
- **棄置** → status 改 `abandoned`，整包搬進 archive/（棄置也要歸檔，
  刪掉會失去「為什麼放棄」的記錄）。
- **已完成忘了標** → status 改 `done`，走第 2 步歸檔。

### 4. 報告

```
[plans] 進行中 2 / 本次歸檔 5（done 4、abandoned 1）/ 待你決定 0
根目錄現況：<留下的檔案清單>
```

## 鐵則

- 只搬檔案與改 frontmatter status，**絕不刪除**任何計畫。
- 不動 `archive/` 裡的東西。
- 爛尾判定永遠問使用者，不自作主張棄置。
