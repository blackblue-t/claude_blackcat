---
description: 跟遠端同步：開工前把遠端的新進度拉下來、收工後把本地提交推上去。處理落後、超前、分岔三種狀況，遇到衝突停下來協助解。/go、/task-next、/dispatch 開工前與 /commit 收尾時會照這份做。
model: sonnet
---
<!-- 模型路由：跑幾個 git 指令加判斷，sonnet 就夠。 -->

# 同步（/sync）

用法：`/sync`（看狀況並處理）、`/sync push`（收工推送）、`/sync status`（只看不動）。

多台電腦或多人開發同一個專案時，問題幾乎都來自「開工前沒拉、收工後沒推」。這個指令把
兩件事固定下來。

## 步驟 1：看狀況（一律先做，不改任何東西）

```bash
git remote                                   # 沒有遠端 → 回報「沒有遠端，不需要同步」，結束
git fetch --prune
git status --short                           # 有沒有未提交的變更
git rev-parse --abbrev-ref --symbolic-full-name @{u}   # 目前分支有沒有對應的遠端分支
git rev-list --left-right --count @{u}...HEAD          # 左＝落後幾個、右＝超前幾個
```

用一句白話回報，例如「main 落後遠端 3 個提交，本地有 2 個檔案沒提交」。

目前分支沒有對應的遠端分支（剛開的新分支）→ 不用拉；`/sync push` 時用
`git push -u origin <分支>` 建立。

## 步驟 2：依狀況處理

| 狀況 | 做法 |
|:--|:--|
| 一樣新 | 回報「已是最新」 |
| 只落後、工作區乾淨 | `git pull --ff-only` |
| 只落後、工作區有未提交變更 | 先說明有哪些檔案沒提交。變更和遠端新提交動到的檔案不重疊 → `git pull --ff-only`（git 會保留本地變更）；有重疊 → 停下，請使用者選：先提交（走 `/commit`）或先放一邊（`git stash`，拉完 `git stash pop`）。**不要自己 stash** |
| 只超前 | 不用拉。`/sync push` 才推 |
| 分岔（兩邊都有新提交） | 本地這幾個提交**都還沒推過** → `git pull --rebase`（把本地提交接到遠端後面，歷史保持一直線）。已經推過 → `git pull --no-rebase`（合併），不要 rebase 已公開的提交 |

**衝突時**（rebase 或 merge 停下來）：

1. 列出衝突的檔案，每個檔案用一句話說明兩邊各改了什麼。
2. 兩邊改的是不同的東西 → 兩邊都保留，解完跑專案的測試。
3. 兩邊改的是同一段邏輯、保留一邊會丟掉另一邊的行為 → **停下問使用者**，不要猜。
4. 解完 `git add` 後 `git rebase --continue`（或 `git commit`）。想放棄就
   `git rebase --abort`／`git merge --abort`，回到同步前的狀態。

## /sync push（收工推送）

1. 先做步驟 1、2（遠端有新東西要先拉，不然推不上去）。
2. 工作區有未提交變更 → 提醒，問要不要先 `/commit`；不替使用者提交。
3. `git push`（新分支用 `git push -u origin <分支>`）。
4. 被拒絕（遠端又有人推了）→ 回步驟 1 再來一次，最多兩次，還不行就回報。

## 專案的推送設定

`.claude/blackcat.conf` 的 `PUSH`（沒有這個檔或沒設＝`ask`）：

| 值 | `/commit`、`/go` 收尾時 |
|:--|:--|
| `ask` | 問一句「要推上遠端嗎？」 |
| `auto` | 直接照「/sync push」推 |
| `never` | 不推也不問，只提醒有幾個提交還沒推 |

## 鐵則

- 不用 `git push --force`、不用 `git reset --hard`、不刪分支。真的需要時說明原因，請使用者自己下指令。
- 不替使用者 stash、不替使用者丟棄任何變更。
- 主分支（`main`／`master`）一律 fast-forward 或 rebase 本地未推的提交，不在主分支上製造多餘的合併提交（`/commit` 把整合分支用 `--no-ff` 合回來的那一個除外）。
