---
description: 把喜歡的網站加進自己的 UI 風格庫：抓公開網站的配色、字型、間距、元件外觀，整理成 DESIGN.md 存進 blackcat 的 ui-library，之後 /ui-style 可以選它。不搬 logo、圖片、文案。
---

# 收藏網站風格（/ui-add）

用法：`/ui-add <網址> [代號]`，例如 `/ui-add https://example-coffee.jp roastery`。

和 `/ui-style` 的「貼網址抽風格」差在哪：那個只寫進**這個專案**的 DESIGN.md；這個存進
**風格庫**，之後每個專案的 `/ui-style` 都選得到。

## 步驟 0：找到風格庫

1. 讀 `~/.claude/blackcat-repo`（`install.bat`／`install.sh` 寫的 blackcat repo 路徑），
   寫入目標是 `<repo>/ui-library/`。這個檔不存在 → 請使用者在 blackcat repo 重跑
   `install.bat`／`install.sh`，停止。
2. 代號：使用者給了就用，沒給就從網域取（`www.example-coffee.jp` → `example-coffee`）。
   一律小寫、只用英數與 `-`，前面加 `my-`（跟上游的風格分開，也避免撞名）。
   `<repo>/ui-library/my-<代號>/` 已存在 → 問要覆蓋還是換代號。

## 步驟 1：抓網站（依序試，成功就不往下）

**A. Playwright MCP（首選）**

1. `browser_resize` 1440×900，`browser_navigate` 到網址，等 2 秒讓字型載入。
2. Read `<repo>/ui-library/_tools/extract-style.js`，把整段函式當 `browser_evaluate` 的
   `function` 參數執行，得到一份 JSON（色彩出現次數、字型、h1～h4 與內文字級、按鈕和輸入框
   樣式、圓角、陰影、間距、版寬、斷點、`:root` 的 CSS 變數）。
3. `browser_take_screenshot` 全頁截圖，存到 `.claude/tmp/ui-add/<代號>/shot-1440.png`；
   再 resize 到 390×844 截 `shot-390.png`（目錄放一份內容是 `*` 的 `.gitignore`）。
4. 使用者另外指定了內頁（例如商品頁）→ 對每個內頁重複 2、3，結果合併看。

**B. 沒有 Playwright MCP**：機器上有全域 `playwright` 套件時，跑
`NODE_PATH="$(npm root -g)" PROBE=<repo>/ui-library/_tools/extract-style.js node <repo>/ui-library/_tools/probe-cli.js <網址> .claude/tmp/ui-add/<代號>`。

**C. 都沒有**：firecrawl MCP 的 scrape（`formats` 帶 `branding` 與 `screenshot`）。只有
色票和字型，元件與間距要看截圖推斷，全部標「推斷」。

**D. 都不行**：請使用者貼 2～3 張網站截圖，Read 看圖，全部標「目測，低信心」，字型寫
「目測無法確認」。

網站擋自動瀏覽（驗證頁、空白頁、cookie 牆蓋住整頁）→ 給使用者看截圖，問要換網址還是改走 D。

## 步驟 2：給使用者確認

Read 兩張截圖，自己先看懂這個網站的感覺。然後用一段話＋清單給使用者看：

- 底色、主要文字色、強調色（各給 hex 與「用在哪裡」）
- 字型（標題、內文；商用字型標「需授權」）
- 形狀：圓角、邊框粗細、有沒有陰影
- 版面：版寬、留白鬆或緊、斷點
- 截圖路徑

問「是你要的那種感覺嗎？」：是／不是，換一頁再抓（例如內頁更有代表性）／取消。

## 步驟 3：寫 DESIGN.md

寫 `<repo>/ui-library/my-<代號>/DESIGN.md`，格式跟風格庫的舊格式一致（9 節，數值寫在段落裡，
不加 YAML 檔頭）：

```markdown
# Design System Inspired by <網站顯示名稱>

## 1. Visual Theme & Atmosphere
## 2. Color Palette & Roles
## 3. Typography Rules
## 4. Component Stylings
## 5. Layout Principles
## 6. Depth & Elevation
## 7. Do's and Don'ts
## 8. Responsive Behavior
## 9. Agent Prompt Guide
```

- 內文用英文寫（跟庫裡其他 89 份一致，`/ui-style` 混搭時才對得上段落）
- 色彩：從抽取結果的出現次數判斷角色（底色、文字、強調、邊框、狀態），每個色給 hex＋用途；
  角色是推斷的行尾標 `(inferred)`
- 數值只能來自抽取結果或截圖；抽不到的寫 `Not observed`，不要補「常見值」
- 第 9 節寫 3～5 句「要做出這種感覺時要注意什麼」，給之後寫頁面的 Claude 看
- **不寫**：logo、圖片網址、品牌標語、商品名、價格、地址、任何原網站文案

寫完跑一次，有命中就改掉：

```bash
grep -nE 'https?://[^ )]+\.(png|jpe?g|svg|webp|gif|ico)|logo' <repo>/ui-library/my-<代號>/DESIGN.md
```

## 步驟 4：寫 SOURCE.json

```json
{
  "source": "personal",
  "source_url": "<網址>",
  "upstream_repo": null,
  "upstream_format": "voltagent-9section",
  "imported_at": "<今天 YYYY-MM-DD>",
  "imported_sha256": "<DESIGN.md 的 sha256>",
  "license": null,
  "license_file": null,
  "locally_modified": false,
  "local_changes": "",
  "language": "en",
  "extraction_method": "playwright | firecrawl | screenshot",
  "note": "公開網站外觀的描述，不是品牌授權；做出來的介面不放對方 logo、品牌名、文案"
}
```

`imported_sha256` 用 `sha256sum`（Windows Git Bash 也有）算。

## 步驟 5：登記到目錄

編輯 `<repo>/ui-library/CATALOG.md`：

1. 開頭「收錄 N 種」的 N 加一
2. 在「## 我的收藏」節（沒有就建在「## 按設計哲學分類」前面）加一行：
   `- **my-<代號>** — <繁中一句話特色>（<網址的網域>，<YYYY-MM-DD> 收藏）`
3. 依它的感覺，在「按設計哲學分類」最接近的那一類的清單後面也加上 `my-<代號>`

## 步驟 6：讓它生效並檢查

1. 全域那份是複製的（Windows，或用 `--copy` 安裝）→ 把 `my-<代號>/` 與 `CATALOG.md` 也複製到
   `~/.claude/ui-library/`。是 symlink 就不用。
2. 在 repo 跑 `bash scripts/check-counts.sh`，要看到 `[pass]`。
3. 完成訊息：代號、存放路徑、截圖路徑，並提醒：
   - 現在跑 `/ui-style my-<代號>` 就能直接套用（不想直接套用可以先 `/ui-style --preview` 看樣張）
   - 這個風格存在 blackcat repo 裡，要同步到其他電腦就在 repo 裡 commit 並 push：
     `git add ui-library && git commit -m "ui-library: add my-<代號>" && git push`
     （不要替使用者 push）

## 鐵則

- 只收外觀規則，不收內容：logo、圖片、文案、商品資料一律不進風格庫。
- 只抓公開頁面；要登入才看得到的頁面不抓。
- 數值沒抓到就寫沒抓到，不憑印象補。
