---
description: 前端第一站：從 104 種風格庫挑（看預覽、自己挑、混搭、貼網址、從現有程式碼反推），決定網站類型與動畫等級，組出專案的 .claude/ui/DESIGN.md。之後所有 UI 產出都以它為準。
---

# 風格定義（/ui-style）

前端三部曲的第一站（style → site → page）。產出兩個檔：

- `.claude/ui/DESIGN.md`：唯一風格契約（**先有它才准寫任何 UI 程式碼**）
- `.claude/ui/style.json`：選擇紀錄（來源、主風格、覆蓋、動畫等級、icon 集）

風格庫在 `~/.claude/ui-library/`（全域安裝，`CATALOG.md` 是目錄）。找不到就請使用者
在 blackcat repo 重跑 `install.bat`／`install.sh`；在那之前只能走路徑 H、E 或純問答。

用法：`/ui-style`（互動）、`/ui-style apple`（直接指定）、`/ui-style linear.app+stripe`
（混搭，`+` 後面的逐項問要覆蓋哪幾項）、`/ui-style --preview`（不改設定，只依現有
DESIGN.md 重產樣張並打開，直接跳到步驟 6）。帶 codename 時跳過步驟 1、3。

## 互動原則

- 用 `AskUserQuestion`，一次一題，建議的選項放第一個並標 (Recommended)
- 一題最多 4 個選項，超過就拆兩層
- **題目和選項一律白話**：使用者不一定懂前端，不寫 token、easing、函式庫名

## 步驟 0：已經有設定時

`.claude/ui/style.json` 或 `.claude/ui/DESIGN.md` 存在 → 先顯示目前設定，再問：
重新選風格（建議）／只看樣張（跳到步驟 6）／只補網站類型和動畫等級／取消。

## 步驟 1：入口

第一層「要怎麼決定網站的樣子？」：

| 選項 | 路徑 |
|---|---|
| 讓我推薦，看預覽選（建議） | F |
| 我自己挑（單一品牌、混搭、先看目錄、直接打 codename） | A／B／C／D |
| 我有參考來源（貼網址、照專案現在的樣子） | H／E |

使用者直接打 codename → 路徑 D。

**專案已經有前端樣式**（有 `tailwind.config.*`、CSS `:root` 自訂屬性、`components.json`，
或 `src/` 下有 `.css`／元件檔）→ 把「照專案現在的樣子」（路徑 E）提到第一個並標建議。
把品牌風格硬套到已有樣式的專案，新舊元件會越寫越不一致。

## 步驟 2：網站類型（`site_type`）

先從 `.claude/ui/IA.md`、`README.md`、`CLAUDE.md` 推斷，推得出來就一句話告知「判斷這是
<類型>，要改請說」；推不出來才問。值（`/ui-site` 共用，唯一來源）：

| 值 | 白話 |
|---|---|
| `admin` | 管理後台、內部工具 |
| `docs` | 文件站、知識庫 |
| `saas` | 產品官網、SaaS |
| `brand` | 品牌形象頁、活動頁 |
| `local` | 在地店家、餐廳、工作室 |
| `portfolio` | 作品集 |
| `ecommerce` | 電商 |
| `other` | 其他 |

## 步驟 3：依路徑選風格

**每個 codename 都要 `ls ~/.claude/ui-library/<codename>/DESIGN.md` 確認存在**，不存在就換。

### 路徑 F：看預覽選

1. 先讀 `.claude/skills/ui-style-compliance/anti-ai.md` 的「產出前」與「例外」裡「看預覽選
   提方向時」（提方向的規則以那裡為準）、`~/.claude/ui-library/CATALOG.md`、專案描述。
   都沒有描述就先問一題：「這個網站在介紹什麼、給誰看？一句話就好」。
2. 想 3 個**真的不一樣**的方向，每個對應一個 codename，或「主風格＋1～2 項覆蓋」。方向從
   專案題材長出來（產業、地方、客群），不是從「溫暖」「質感」這種形容詞。「暖紙感」
   （米白底、襯線、陶土色）最多一個。
3. 色票**從那份 DESIGN.md 讀**，不要自己配。
4. 用 `AskUserQuestion` 的 `preview` 呈現：`label` 是白話方向名，`preview` 至少 4 個
   `#RRGGBB` 色票＋至少 3 行 ASCII 版面示意，並寫「對應風格：attio（單一）」或
   「linear.app（主）＋ 配色 stripe」。
5. 問題最後加一個選項「先看實際畫面再選」。選了就照下方「步驟 6」的作法，把三個方向
   並排做成一頁 `.claude/tmp/ui-preview/directions.html`（每個方向一欄：色票、標題與內文、
   按鈕、一張卡片、一小段版面），用瀏覽器打開，再問一次同一題（不含這個選項）。
6. 都不喜歡 → 依回饋再提一輪；兩輪都不中就建議改走「我自己挑」或「貼網址」。

### 路徑 A：單一風格

先問分類角度（按設計哲學／按產業），再列該分類下 3～5 個 codename（清單照 CATALOG.md）。

### 路徑 B：混搭

先照路徑 A 選主風格，再對配色、字體、元件、版面各問一題「沿用主風格／從另一個風格取」，
選後者就接著問從哪個。全部沿用就降級成單一。

### 路徑 C：先看目錄

讀 CATALOG.md，條列分類摘要給使用者，回到步驟 1。

### 路徑 D：直接指定

驗證 codename 存在（一律轉小寫），不存在就列相近的幾個讓使用者挑。

### 路徑 H：貼網址抽風格

只取色票、字型、字級、圓角、陰影、間距。**不搬 logo、圖片、文案**（別人的品牌資產）。

1. 收 1～3 個 `http(s)://` 網址。
2. 逐一抽取，前一個成功就不往下：
   - firecrawl MCP 的 scrape，`formats` 帶 `branding` 與 `screenshot`（參數以工具 schema
     為準）。忽略 `logo`、`images`；色彩角色（誰是 primary）標「推斷」
   - 沒有 firecrawl 或失敗 → Playwright MCP 開網址，`browser_evaluate` 讀 `body`、`h1`、
     `h2`、`a`、`button`、`input` 的 computed style，再截一張圖
   - 都不行 → 請使用者貼那個網站的截圖，Read 看圖，全部標「目測，低信心」
3. 每個網址給使用者看截圖確認「是這種感覺嗎」，確認才收下。
4. 多個網址時對配色、字體、元件、版面各問一題「照哪個網站」。
5. 照下方「自己寫 DESIGN.md」寫，寫完 `grep -nE 'https?://[^ )]+\.(png|jpe?g|svg|webp|gif|ico)|logo' .claude/ui/DESIGN.md`，
   搬進來的 logo、圖片網址一律拿掉。

### 路徑 E：照專案現在的樣子

依序找：`tailwind.config.*` 的 theme、CSS `:root`／`@theme` 自訂屬性、`components.json`、
theme 檔、`Button`／`Card`／`Input` 元件。沒有集中設定就統計：

```bash
rg -o '#[0-9a-fA-F]{3,8}|rgb\([^)]+\)' --no-filename | sort | uniq -c | sort -rn | head -20
rg -o 'rounded-[a-z0-9]+|border-radius:[^;]+|shadow-[a-z0-9]+|box-shadow:[^;]+' --no-filename | sort | uniq -c | sort -rn | head -20
rg -o 'font-family:[^;]+' --no-filename | sort | uniq -c | sort -rn | head -10
```

設計**意圖**推不出來就問三題：給誰用、在什麼情境；要資訊密集還是留白克制；有沒有想像中的
參考品牌。掃到的不一致（三種圓角、五個相近的灰）寫進 DESIGN.md 末尾的「待收斂項目」。

## 步驟 4：專案補充（每條路徑都問）

1. **品牌色**：「有品牌色嗎？」有 → 收 hex，覆蓋主色並由它生成色階（50～900）、深色模式
   對應色，做 **WCAG AA 對比檢查**（不過關就提微調建議，不硬用）。沒有 → 沿用風格的色票。
2. **深色模式**：要／不要／跟隨系統。
3. **Icon 集**（擇一，防混用）：lucide／heroicons／Material Symbols／專案自有 SVG。
4. **元件策略**：用哪套元件庫，或自建（自建時記共用元件清單的位置，新元件先查清單複用）。
5. **動畫等級**：選項文字照 `.claude/skills/ui-style-compliance/motion.md` 第 1 節（先 Read，
   不要憑記憶寫）。推薦與限制照同一節的「依網站類型推薦」表，`admin`、`docs` 不提供 L3。

## 步驟 5：確認後寫檔

顯示摘要（來源、單一或混搭、主風格與覆蓋、網站類型、動畫、品牌色、icon、深色模式），
確認後寫：

**`.claude/ui/DESIGN.md`**

- 單一：複製 `~/.claude/ui-library/<primary>/DESIGN.md` 全文
- 混搭：以主風格全文為底，把覆蓋項目對應的段落換成那個品牌的同名段落（段落標題對照表見
  `ui-style-compliance` 的 1.2 節；新格式檔頭 YAML 的對應區塊也要一起帶）
- 路徑 H、E：自己寫，段落用 `## Overview`／`## Colors`／`## Typography`／`## Components`／
  `## Layout`／`## 待確認`，不加 YAML 檔頭。直接讀到的值＝高信心；推斷的行尾標「推斷」；
  推不出來留 `【待確認】`，不要猜
- 檔頭加三行：`> 來源：<codename 或網址或 code-scan>`、`> 組合日期：YYYY-MM-DD`、
  `> 風格庫來源與授權：~/.claude/ui-library/<codename>/SOURCE.json`（路徑 H、E 免）
- 檔尾加 `## 專案補充`：品牌色與它生成的色階、深色模式、icon 集、元件策略，每項附一行對應
  偵測到的 CSS 方案的用法示例。**這一節優先於上面的品牌原文**

**`.claude/ui/style.json`**

```json
{
  "version": "1",
  "source": "preview",
  "mode": "mixed",
  "primary": "linear.app",
  "overrides": { "color": "stripe", "typography": null, "components": null, "layout": null },
  "site_type": "brand",
  "motion": "L2",
  "icon_set": "lucide",
  "brand_color": "#FF6B00",
  "dark_mode": "system",
  "chosen_at": "2026-10-27",
  "notes": "方向「工程感的品牌頁」"
}
```

`source`：`preview`／`catalog`／`url`／`code-scan`。路徑 H、E 的 `primary` 寫 `"_project"`。

## 步驟 6：風格樣張（寫完檔一定要做）

只看文字規格，使用者想像不出畫面。寫完兩個檔後，產一頁 `.claude/ui/preview.html` 給使用者
用眼睛確認。**這是看規範長什麼樣的樣張，不是網站的任何一頁**。

**內容**（由上而下，每區一個小標）：

1. 色票：每個 token 一格，標名稱、hex、用途；文字色標出對它的背景的對比值（例如 `7.8:1`），
   低於 4.5:1 的標「不足」
2. 字級：h1～h4、內文、說明文字各一行，中英文都要有（例如「標題範例 Heading Sample 2026」）
3. 元件：主要／次要／停用按鈕（hover 與 focus 狀態另外排一個）、輸入框（一般與錯誤）、
   卡片、徽章、公告列、深色區塊——DESIGN.md 有定義的才做
4. 間距、圓角、邊框、陰影：各畫一排小方塊
5. icon：用 `style.json` 的 `icon_set` 放 6 個常見 icon（選單、搜尋、購物車、地圖、電話、關閉）
6. 一小段組合示意：標題＋一段內文＋按鈕＋兩張卡片，看整體感。動畫等級是 L2／L3 時，這一段
   做往下捲依序出現的效果（並處理 `prefers-reduced-motion`）

**寫法規則**：

- 單一 HTML 檔，不依賴專案的建置工具；字型與 icon 可以從 CDN 載（Google Fonts、lucide）
- 所有顏色、字型、間距寫在 `:root` 的 CSS 變數，值完全取自 DESIGN.md（「專案補充」優先），
  `:root` 以外不准出現 hex
- 範例文字用中性的「標題範例」「這是一段內文範例」，**不放原品牌的店名、logo、文案**，也不編
  價格、地址這類事實
- 寫一份 `.claude/ui/.gitignore`，內容 `preview.html`（樣張隨時可重產，不進版控）

**打開給使用者看**：

- Windows（Claude Code 的 Bash 是 Git Bash）：`cmd.exe //c start "" "<preview.html 的絕對路徑>"`；
  macOS：`open <路徑>`；Linux：`xdg-open <路徑>`
- 有 Playwright MCP 時另外自己截 390 與 1440 兩張（Playwright 擋 `file://`，先用
  `python -m http.server` 在 `.claude/ui` 起一個臨時伺服器，看完關掉），用 Read 看圖檢查破版、
  字型沒載到、對比不足，有問題先修樣張再給使用者
- 沒辦法開瀏覽器（例如遠端環境）→ 給檔案的完整路徑，請使用者自己打開；有截圖就附截圖路徑

**確認**：用 `AskUserQuestion` 問「樣張看起來對嗎？」：

| 選項 | 之後 |
|---|---|
| 對，就這樣（建議） | 定案，進完成訊息 |
| 要調整（直接說哪裡） | 改 DESIGN.md 的「專案補充」與 `style.json`，重產樣張再問一次 |
| 整個重選 | 回步驟 1 |

## 完成訊息

列出三個檔的路徑（DESIGN.md、style.json、preview.html）、主風格、動畫等級，提醒下一步
`/ui-site` 建站點結構，或直接 `/ui-page <路徑>` 做單頁。之後改了 DESIGN.md，用
`/ui-style --preview` 重看樣張。

## 檔案落點約定（前端三部曲共用）

| 檔案 | 位置 | 進 git | 性質 |
|:--|:--|:--|:--|
| `.pen` 設計稿 | `design/site.pen`（大專案可拆 `design/<區域>.pen`） | 是 | 產品設計源檔 |
| DESIGN.md | `.claude/ui/DESIGN.md` | 是 | 風格契約 |
| style.json | `.claude/ui/style.json` | 是 | 選擇紀錄 |
| 風格樣張 | `.claude/ui/preview.html` | 否（隨時重產） | 看規範長什麼樣 |
| IA.md | `.claude/ui/IA.md` | 是 | 資訊架構契約 |
| 灰框原型 | `.claude/ui/prototype/` | 否（即棄） | 動線驗證 |
| 截圖 | `.claude/tmp/ui-screenshots/` | 否 | 驗收用 |

## 鐵則

- 風格庫是**參考風格，不是品牌授權**：產出的介面不放對方 logo、品牌名、招牌文案。
- pencil MCP 可用時，用它取得/同步設計稿的 tokens，DESIGN.md 與設計稿一致。
- ui-ux-pro-max 只查使用體驗，不拿來選風格；DESIGN.md 定案後就是唯一契約。
- 不寫網站的任何頁面或元件程式碼，本站只定規範；樣張是唯一例外，而且只放在 `.claude/ui/`。
