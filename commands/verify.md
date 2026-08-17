---
description: 機器檢查：跑建置、型別、lint、測試，回報紅綠。純執行指令看結果，不讀程式碼、不做判斷。想要「有沒有壞掉」的答案就跑這個。
model: sonnet
---
<!-- 模型路由：跑指令看輸出是機械活，sonnet 就夠。判斷性的審查交給
     /review-code（Fable）。 -->

# 機器檢查（/verify）

**跟 `/review-code` 的分工**（兩者常被搞混）：

| | `/verify`（本指令） | `/review-code` |
|:--|:--|:--|
| 做什麼 | **跑指令**：build / type / lint / test | **讀程式碼**：diff 逐行看 |
| 找什麼 | 工具會報的錯（編譯失敗、測試紅） | 工具報不出的錯（邏輯漏洞、安全、爛測試） |
| 答案 | PASS / FAIL | verdict: pass / needs-fix + findings |
| 模型 | sonnet（便宜） | Fable（貴） |
| 何時 | 隨時想確認沒壞掉 | 一段工作完成、要提交之前 |

一句話：**verify 問「跑得起來嗎」，review-code 問「寫得對嗎」。**
`/review-code` 會先自己跑一次本指令的檢查當作門檻——建置都紅了不值得
花錢審查。

## 說明

依以下確切順序執行驗證：

### 1. 建置檢查
- 執行專案的建置指令
- 如失敗則報告錯誤並停止

### 2. 型別檢查
- 執行 TypeScript/型別檢查器
- 報告所有錯誤含檔案:行號

### 3. Lint 檢查
- 執行 linter
- 報告警告和錯誤

### 4. 測試套件
- 執行所有測試
- 報告通過/失敗數量
- 報告覆蓋率百分比

### 5. Console.log 稽核
- 搜尋原始碼中的 console.log
- 報告位置

### 6. Git 狀態
- 顯示未提交的變更
- 顯示自上次 commit 以來修改的檔案

## 輸出

產出簡潔的驗證報告：

```
VERIFICATION: [PASS/FAIL]

Build:    [OK/FAIL]
Types:    [OK/X errors]
Lint:     [OK/X issues]
Tests:    [X/Y passed, Z% coverage]
Secrets:  [OK/X found]
Logs:     [OK/X console.logs]

Ready for PR: [YES/NO]
```

如有任何關鍵問題，列出並附修復建議。

## 邊界

- **只跑指令、只回報結果**——不改程式碼、不修測試、不做程式碼判斷。
  發現問題就列出來，修不修由使用者或後續流程決定。
- 計畫歸檔不是本指令的事（那是 `/commit` 與 `/clean-plan` 的職責）。

## 參數

$ARGUMENTS 可以是：
- `quick` - 僅建置 + 型別
- `full` - 所有檢查（預設）
- `pre-commit` - 與 commit 相關的檢查
- `pre-pr` - 完整檢查加安全掃描
