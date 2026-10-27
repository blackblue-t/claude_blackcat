---
description: 選擇或切換專案的套件管理器（Node：bun/pnpm/npm；Python：uv/poetry/pip），寫入 .claude/package-manager.json。之後所有安裝、執行、測試指令都照它。
model: sonnet
---
<!-- 模型路由：偵測 lock 檔加一兩題問答，sonnet 就夠。 -->

# 套件管理器選擇（/pm-choose）

規則與指令對照的唯一來源是 `package-manager` skill，這裡只負責問和寫。

## 步驟 1：偵測（不問使用者）

- 有沒有 `package.json`、`pyproject.toml`、`requirements.txt`
- 現有 lock 檔：`package-lock.json`／`pnpm-lock.yaml`／`bun.lock`／`bun.lockb`／`yarn.lock`／
  `uv.lock`／`poetry.lock`
- 已有 `.claude/package-manager.json` → 這次是**切換**，先顯示目前設定

兩種語言都沒有 → 問使用者這個專案會用哪個（Node／Python／兩個都會），再往下。

## 步驟 2：問（用 `AskUserQuestion`，一個語言一題）

**Node**：

| 選項 | 說明 |
|---|---|
| pnpm | 省磁碟、依賴隔離嚴格、monorepo 友善；少數老套件會抱怨 peer 依賴 |
| bun | 安裝和執行最快、內建 TypeScript；少數原生模組要繞路 |
| npm | Node 內建、相容性最高、CI 預設；最慢、`node_modules` 最大 |

**Python**：

| 選項 | 說明 |
|---|---|
| uv | 最快、一個工具管 Python 版本＋虛擬環境＋依賴 |
| poetry | 成熟、打包發佈方便；比 uv 慢 |
| pip | 最基本，用 venv＋requirements.txt；沒有真正的 lock 檔 |

**推薦**：有 lock 檔就推它對應的那個（尊重現況）；新專案 Node 推 pnpm、Python 推 uv。
推薦的放第一個並標 (Recommended)。

## 步驟 3：選的和現有 lock 檔不同時

追問：保留現況（改選 lock 檔對應的）／遷移（刪舊 lock 與 `node_modules` 或 `.venv` 後用新的
重裝，依賴版本可能小幅變動）／先不動 lock 檔。遷移只列出要跑的指令，**使用者確認才執行**。

## 步驟 4：寫檔

寫 `.claude/package-manager.json`（格式見 `package-manager` skill），保留沒被問到的那個語言
原本的設定。`reason` 摘使用者說的理由，沒有就空字串。

## 完成訊息

列出這個專案的安裝、開發、測試三個指令，以及設定檔路徑。
