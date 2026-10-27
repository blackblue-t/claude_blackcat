---
name: package-manager
description: 專案的套件管理器（Node 的 bun/pnpm/npm、Python 的 uv/poetry/pip）由使用者決定並寫入 .claude/package-manager.json，Claude 不自選。含指令對照表、lock 檔衝突偵測、原生模組退路。MUST BE USED before running any npm/pnpm/bun/npx/bunx/uv/pip/poetry command, before install/run/test/audit, or before touching package.json, pyproject.toml, node_modules, or any lockfile.
---

# 套件管理器規則

## 執行任何安裝／執行／測試指令前必檢

先讀 `.claude/package-manager.json`：

1. **存在** → 照它的 `node`／`python` 欄位用對應語法（見對照表）
2. **不存在** → 看 lock 檔：只有一種 lock 檔就照它用，並建議使用者跑 `/pm-choose` 記下來；
   沒有 lock 檔或有多種 → 停下，請使用者跑 `/pm-choose`，不要自己挑
3. **使用者這次明說**用某個（「用 pnpm 裝」）→ 照做，但提醒跟設定不符，問要不要更新設定

背景執行的 agent（ui-builder、dispatcher 的 headless session）問不了使用者：沒有設定也沒有
唯一的 lock 檔時，不要安裝任何東西，回報 `NEEDS_CONTEXT`。

## 設定檔

```json
{
  "node": "pnpm",
  "python": "uv",
  "chosen_at": "2026-10-27",
  "reason": "monorepo，要嚴格依賴隔離"
}
```

只用到一種語言就只寫那一個鍵。

## Node 指令對照

| 操作 | npm | pnpm | bun |
|---|---|---|---|
| 安裝全部依賴 | `npm install` | `pnpm install` | `bun install` |
| 新增套件 | `npm install <pkg>` | `pnpm add <pkg>` | `bun add <pkg>` |
| 新增 dev 套件 | `npm install -D <pkg>` | `pnpm add -D <pkg>` | `bun add -d <pkg>` |
| 移除套件 | `npm uninstall <pkg>` | `pnpm remove <pkg>` | `bun remove <pkg>` |
| 執行腳本 | `npm run <script>` | `pnpm <script>` | `bun run <script>` |
| 啟動開發 | `npm run dev` | `pnpm dev` | `bun run dev` |
| 測試 | `npm test` | `pnpm test` | `bun run test`（`bun test` 是 bun 自己的測試器，不是 package.json 的 test） |
| 執行 CLI（臨時） | `npx <cli>` | `pnpm dlx <cli>` | `bunx <cli>` |
| 稽核漏洞 | `npm audit` | `pnpm audit` | `bun audit` |
| lock 檔 | `package-lock.json` | `pnpm-lock.yaml` | `bun.lock`（舊版 `bun.lockb`） |

## Python 指令對照

| 操作 | uv | poetry | pip（venv） |
|---|---|---|---|
| 安裝全部依賴 | `uv sync` | `poetry install` | `pip install -r requirements.txt` |
| 新增套件 | `uv add <pkg>` | `poetry add <pkg>` | `pip install <pkg>` 後更新 requirements |
| 新增 dev 套件 | `uv add --dev <pkg>` | `poetry add -G dev <pkg>` | 寫進 `requirements-dev.txt` |
| 執行 | `uv run <cmd>` | `poetry run <cmd>` | 先啟用 `.venv` 再執行 |
| lock 檔 | `uv.lock` | `poetry.lock` | 無（`requirements.txt` 當鎖） |

## 安全閘門

- **多個 lock 檔並存**（例如 `package-lock.json` 和 `bun.lock`）→ 安裝前停下，列出來，
  問使用者要留哪一個。不要自己刪。
- **設定和 lock 檔不符**（設定 bun，卻只有 `package-lock.json`）→ 停下，給三個選擇：
  改設定配合現況（`/pm-choose`）／清掉舊的 lock 檔與 `node_modules` 改用設定的
  （依賴版本會重算）／這次先照 lock 檔做。
- **原生模組裝不起來**（`sharp`、`canvas`、node-gyp 編譯錯）→ 可以臨時用 npm 裝那一個
  套件繞過，但要在設定檔 `reason` 記一行、commit message 說明，不換整個專案的管理器。
- 刪 lock 檔、刪 `node_modules`、換管理器都要使用者確認。
