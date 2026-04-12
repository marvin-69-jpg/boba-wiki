# boba-wiki

LLM-maintained knowledge base built from [BOBA Daily](https://t.me/test3635) reports.
Inspired by [Andrej Karpathy's LLM Wiki pattern](https://github.com/karpathy/llm-wiki) and Leo's Claude + Obsidian implementation.

## Architecture

```
                        boba-cli (k8s pod)
                 ┌──────────────────────────┐
                 │  fetch → 撰稿 → send     │
                 └────────────┬─────────────┘
                              │ 日報完成
                              │ send 自動同步
                              ▼
┌─────────────────────────────────────────────────────────┐
│                      boba-wiki repo                     │
│                                                         │
│  raw/                          wiki/                    │
│  ├── 2026/04/09.md             ├── btc.md               │
│  ├── 2026/04/10.md             ├── eth.md               │
│  ├── 2026/04/11.md             ├── us-iran.md           │
│  └── ...                       ├── stablecoins.md       │
│  (immutable, 不可改)            └── ... (LLM 維護)       │
│                                                         │
│  schema/CLAUDE.md    index.md    log.md                  │
│  (ingest 規則)       (wiki 目錄)  (操作記錄)              │
└──────────────┬──────────────────────────┬───────────────┘
               │                          │
               │ ingest (Sonnet)          │ git push
               │                          │
    ┌──────────▼──────────┐    ┌──────────▼──────────┐
    │  claude -p --model   │    │   Obsidian          │
    │  sonnet              │    │   Git plugin         │
    │                      │    │   auto-pull          │
    │  讀 raw → 抽 entity  │    │                      │
    │  → 更新 wiki pages   │    │  graph view          │
    │  → cross-link        │    │  [[wiki-links]]      │
    │  → commit + push     │    │  browse + search     │
    └──────────────────────┘    └──────────────────────┘
         LLM writes                  Human reads
```

## Why — 為什麼要做這個

### 問題

BOBA Daily 每天產出 8 則新聞摘要。發完就沉入 Telegram 歷史，沒有人會回去翻三個月前的日報。知識是**拋棄式**的——每天從零開始，沒有累積。

想知道「Ethena 過去三個月發生什麼事」？你得翻 90 天的日報，逐篇 ctrl+F。

### 解法：LLM Wiki Pattern

來自 Andrej Karpathy 的核心洞察：

> 大多數人用 LLM 處理文件的方式是 RAG——上傳檔案，每次查詢時從零檢索。
> 這能用，但 LLM 每次都在重新發現知識，沒有累積。
>
> 不同的做法：LLM **持續建立和維護一個 wiki**——結構化、互相連結的 markdown 檔案集。
> 知識被編譯一次，然後持續更新，而不是每次查詢都重新推導。

### 三層架構

```
┌─────────────────────────────────────────────┐
│              Human (Schema)                  │
│  定義規則、page 格式、ingest 流程             │
│  → schema/CLAUDE.md                          │
├─────────────────────────────────────────────┤
│              LLM (Wiki)                      │
│  讀 raw → 抽取 entity → 整合改寫 wiki pages  │
│  → wiki/*.md, index.md, log.md               │
├─────────────────────────────────────────────┤
│              Source (Raw)                     │
│  每天日報原稿，immutable，不可修改             │
│  → raw/YYYY/MM/DD.md                         │
└─────────────────────────────────────────────┘
```

- **Raw** = source of truth，LLM 只讀不改
- **Wiki** = LLM 完全擁有這一層，建立 / 更新 / cross-link / 淘汰過時資訊
- **Schema** = 人類定義的規則，告訴 LLM 怎麼當一個有紀律的 wiki 維護者

### 關鍵設計決策

**1. Wiki page 是 rewrite，不是 append**

錯誤做法（變成 log）：
```markdown
## 2026-04-10
Ethena TVL 到 5B...
## 2026-04-12
Ethena 跟 Aave 整合...
```

正確做法（真正的 wiki）：
```markdown
## Current Status
- TVL: $5B
- 已與 Aave 整合（2026-04-12）
- sUSDe APY ~12%

## Key Events
- **2026-04-12** — Aave 整合
- **2026-04-10** — TVL 突破 $5B
```

LLM 每次 ingest 都重新整合「Current Status」，過時的資訊被更新而不是堆疊。

**2. 扁平 entity pages，不分類**

沒有 `projects/`、`trends/`、`people/` 子目錄。`ethena.md` 就是 `ethena.md`——不需要先決定它是「項目」還是「趨勢」。分類靠 tags 和 `[[cross-links]]`，不靠資料夾。

**3. Ingest 用 Sonnet，不用 Opus**

Ingest 是結構化的機械工作（抽 entity → 查 index → 改寫 page），不需要深度推理。Sonnet 品質夠好，成本 ~$0.10/天 vs Opus ~$0.70/天。

**4. Obsidian 只是 viewer**

LLM 寫，人類讀。Obsidian 的 graph view 和 `[[wiki-links]]` 讓你看到知識之間的連結，但你不需要手動維護任何東西。

**5. Git 是同步層**

因為 LLM 跑在遠端 k8s pod，Obsidian 在你的電腦，中間用 Git push/pull 同步。如果 LLM 跑在本機，可以直接共用同一個資料夾（Leo 的原始做法）。

## Ingest Flow

每天日報發完後，Sonnet 跑這 5 步：

```
Step 1: Orient
│  讀 index.md（全 wiki 目錄）
│  讀 log.md 最後幾筆（最近做了什麼）
│  讀今天的 raw（日報原稿）
▼
Step 2: Extract
│  從 8 則新聞抽出所有 entity
│  （項目、人物、資產、組織、趨勢）
▼
Step 3: Plan
│  比對 index：哪些 page 要更新、哪些要新建
│  找出 cross-link 關係
│  偵測新舊資訊矛盾
▼
Step 4: Execute
│  逐頁處理：
│  - 載入整頁 → 整合新資訊 → 改寫（不是 append）
│  - 加 [[cross-link]]（雙向）
│  - 矛盾標註 + 說明
│  - 過時資訊更新或淘汰
▼
Step 5: Update Meta
   更新 index.md（新頁加入、舊頁更新摘要）
   append log.md（記錄今天動了哪些 page）
   git commit + push
```

## Three Operations

| Operation | What | When |
|-----------|------|------|
| **Ingest** | 新 raw 進來 → 更新 wiki | 每天日報後自動跑 |
| **Query** | 問問題 → 讀 wiki → 合成答案 → 好答案存回 wiki | 隨時 |
| **Lint** | 健康檢查：orphan pages、過時內容、缺 cross-link | 定期 |

## Usage

### As Obsidian Vault

1. Clone this repo
2. Install [Obsidian Git plugin](https://github.com/Vinzent03/obsidian-git)
3. Open the repo as an Obsidian vault
4. Set auto-pull interval (e.g. every 10 minutes)
5. Browse wiki pages, explore graph view, search with `[[wiki-links]]`

### Manual Ingest

```bash
# From boba-cli:
uv run python3 cli.py ingest --date 2026-04-12

# Or directly:
/home/node/boba-wiki/ingest.sh 2026-04-12
```

## Directory Structure

```
boba-wiki/
├── schema/
│   └── CLAUDE.md         ← ingest/query/lint rules (the soul of the system)
├── raw/
│   └── YYYY/MM/DD.md     ← daily reports (immutable)
├── wiki/
│   └── *.md              ← entity pages (LLM-maintained)
├── index.md              ← wiki catalog + one-line summaries
├── log.md                ← append-only operation log
├── ingest.sh             ← ingest script (calls claude -p --model sonnet)
└── README.md
```

## Credits

- Pattern: [Andrej Karpathy — LLM Wiki](https://github.com/karpathy/llm-wiki)
- Implementation reference: Leo's "Claude + Obsidian should be illegal"
- Maintained by: Claude Code (via [openab](https://github.com/marvin-69-jpg/openab))
