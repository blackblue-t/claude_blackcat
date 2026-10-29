# 命名規則

適用於 Claude 新建或改名的檔案、類別、函式、變數、jar、腳本、資料夾。使用者英文不熟，名稱要讓他看單字就猜得到用途。專案已有不同的命名慣例時照專案的，並在回報裡說明。

## 1. 先列命名表，再寫程式

要新增檔案、類別或對外函式時，先在計畫（或回覆）列一張表，使用者看過再寫：

| 名稱 | 角色 | 中文說明 |
|:--|:--|:--|
| `SingleXmlParser` | 解析器 | 解析單一個 XML 檔，回傳節點清單 |
| `XmlParsingBenchmark` | 效能測試 | 開多個執行緒批次呼叫解析器，量時間與資源 |

多個檔案一起設計時，先分清楚誰是核心、誰是外殼（例如一個解析、一個批次測速），再取名，名稱要看得出兩者的關係。

## 2. 詞性固定

- 類別、檔案、jar：名詞（角色），不用動詞開頭。`XmlParser`，不是 `ParseXml`
- 函式：動詞＋對象。`parseFile`、`exportReportToCsv`
- 回傳真假：`is`／`has`／`can`／`should` 開頭。`isExpired`、`hasPermission`
- 轉換：`convertXToY`、`fromX`／`toY`
- 大小寫照語言慣例：Java／C#／TS 類別 PascalCase、函式 camelCase；Python 函式 snake_case；常數全大寫

## 3. 角色後綴

| 角色 | 後綴 |
|:--|:--|
| 讀一個輸入、轉成結構 | `Parser`、`Reader` |
| 批次派工、多執行緒、排程 | `Runner`、`Executor`、`Scheduler` |
| 量速度、量資源 | `Benchmark`、`SpeedTest` |
| 寫到外部系統或檔案 | `Uploader`、`Writer`、`Exporter` |
| 呼叫外部 API | `Client` |
| 讀寫資料庫 | `Repository` |
| 檢查資料對不對 | `Validator` |
| 一種格式轉另一種 | `Converter`、`Mapper` |
| 組合多個步驟的業務邏輯 | `Service` |

範圍有分別時寫進名稱：`Single`／`Batch`、`Daily`／`Monthly`、`From`／`To`。

## 4. 不准用的字

- 含糊動詞：`process`、`handle`、`manage`、`do`、`run`（單獨使用時）、`deal`
- 含糊名詞：`data`、`info`、`item`、`obj`、`temp`、`result`（單獨使用時）
- 雜物類別：`Util`、`Helper`、`Misc`、`Common`、`Manager`
- 自創縮寫與工程黑話：`Bench`、`Mgr`、`Proc`、`Cfg`、`tmp2`。通用縮寫可以用：`id`、`url`、`xml`、`csv`、`api`、`db`、`io`

名稱最多 4 個英文單字。寫不短就代表職責太多，要拆。

## 5. 名稱和行為一致

- 一個函式做超過一件事（又驗證、又呼叫 API、又寫資料庫）就拆開，各自取名
- 函式名寫 `get` 就不准有副作用；寫 `validate` 就要在不通過時報錯
- 類別與對外函式上方寫一行繁中說明用途（說明介面，不是解釋每一行，不違反註記寫法第 3 條）

## 6. 改名時

- 先 grep 找出所有引用：程式、建置設定、腳本、說明文件、log 檔名、資料夾，一次改完
- 改完重新編譯並實際跑一次
- `.bat`／`.cmd` 保持 CRLF 換行，不要用 sed 改（會變成 LF，雙擊時可能出錯）

## 7. 回報時

第一次提到某個名稱時附中文：`SingleXmlParser`（單一 XML 解析器）。
