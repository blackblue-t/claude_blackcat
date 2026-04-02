# 專案 .claude 模板

複製此目錄到新專案的 `.claude/` 即可使用 TaskMaster 工作流。

## 使用方式

```bash
cp -r /path/to/claude_blackcat/project-template /your-project/.claude
```

## 開發流程

1. `/task-init` — 初始化專案，建立 WBS
2. `/task-next` — 取得下一個任務
3. `/plan` — 規劃實作步驟（等待確認）
4. `/tdd` — 測試驅動開發
5. `/verify` — 全面驗證
6. `/task-status` — 查看進度
7. 回到步驟 2

## 目錄說明

| 目錄 | 用途 |
|:--|:--|
| hooks/ | TaskMaster 和 Agent 監控 hooks |
| coordination/ | 人機協作配置（建議模式） |
| context/ | 跨 Agent 上下文共享 |
| taskmaster-data/ | WBS 任務清單和時間追蹤 |
| logs/ | Agent 活動 log |
