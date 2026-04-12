# BOBA Wiki Skill

觸發：「wiki」「更新 wiki」「ingest」「wiki ingest」「backfill」「wiki 查詢」「wiki lint」

---

## 重要：Wiki 在哪

**Repo**: `/home/node/boba-wiki/`（`marvin-69-jpg/boba-wiki`）
**不是** `/home/node/boba-cli/` 也不是 `/home/node/work/`。

```
boba-wiki/
├── raw/YYYY/MM/DD.md     ← 日報原稿（immutable）
├── wiki/*.md              ← entity pages（LLM 維護）
├── schema/CLAUDE.md       ← ingest 規則（必讀）
├── index.md               ← wiki 目錄 + 摘要
├── log.md                 ← 操作記錄
└── ingest.sh              ← 自動 ingest 腳本
```

---

## Operation 1：Daily Ingest（每日 ingest）

日報 send 後自動同步 raw 到 `boba-wiki/raw/`，接著 ingest。

### 方法 A：用 cli.py（推薦）
```bash
cd /home/node/boba-cli
uv run python3 cli.py ingest              # 今天
uv run python3 cli.py ingest --date YYYY-MM-DD  # 指定日期
```
這會呼叫 `ingest.sh`，跑一個 Sonnet session 自動處理。

### 方法 B：手動 ingest（如果 cli.py 不方便或需要 Opus）
```bash
cd /home/node/boba-wiki
bash ingest.sh YYYY-MM-DD
```

### 方法 C：Claude 自己做（batch/backfill 或需要精細控制時）

1. **讀規則**：`cat /home/node/boba-wiki/schema/CLAUDE.md`
2. **讀 index**：`cat /home/node/boba-wiki/index.md`
3. **讀 log 最後幾筆**：`tail -20 /home/node/boba-wiki/log.md`
4. **讀 raw 檔**：`cat /home/node/boba-wiki/raw/YYYY/MM/DD.md`
5. **Extract**：從日報抽出所有 entity
6. **Plan**：比對 index，列出要建/更新的 page
7. **Execute**：逐頁處理（詳見 schema/CLAUDE.md Step 4）
8. **Update meta**：更新 index.md + log.md
9. **Commit + push**：
```bash
cd /home/node/boba-wiki
git add -A
git commit -m "ingest: MM/DD daily report"
git push origin main
```

---

## Operation 2：Batch Backfill（批次回填舊日報）

使用者提供歷史日報檔案 → 存到 raw/ → 批次 ingest。

### 步驟

1. **存 raw 檔**：
```bash
# 從 discord 上傳或 boba-cli/history/ 複製
cp /path/to/YYYY-MM-DD.txt /home/node/boba-wiki/raw/YYYY/MM/DD.md
```

2. **也存到 boba-cli/history/**（選題 blacklist 用）：
```bash
cp /path/to/YYYY-MM-DD.txt /home/node/boba-cli/history/YYYY-MM-DD.txt
```

3. **判斷日期新舊**：
   - **比現有 wiki 更新** → 正常 ingest（更新 Current Status + 加 Key Events）
   - **比現有 wiki 更舊** → backfill ingest：
     - **不改** Current Status（已有更新資料）
     - **不改** `last_updated`
     - Key Events 加在**底部**（reverse-chronological，舊的在下面）
     - 更新 `first_seen` 如果更早

4. **用 Agent 平行化**（超過 3 天建議）：
   - 分組：crypto pages / macro pages / new pages
   - 每組一個 Agent 平行處理
   - 最後統一更新 index.md + log.md

5. **Commit + push**：一次 commit 搞定整批

### Backfill 注意事項
- 先讀 `schema/CLAUDE.md` 確認格式
- 新 entity（現有 wiki 沒有的）照正常流程建頁
- 已有的 entity 只加 Key Events，不動 Current Status
- `first_seen` 取最早出現的日期
- Cross-links 要雙向

---

## Operation 3：Query（查詢）

使用者問 wiki 裡的知識（「Ethena 最近怎麼了」「穩定幣法案進度」）。

1. 讀 `index.md` 找相關 page
2. 讀那些 page
3. 合成答案（附 `[[wiki-link]]` 引用）
4. 如果產生了有價值的新 synthesis → 存成新 wiki page

---

## Operation 4：Lint（健康檢查）

```
cd /home/node/boba-wiki
```

檢查項目：
- Orphan pages（沒有 inbound link）
- Missing pages（`[[link]]` 指向不存在的頁面）
- Stale content（Current Status 超過 30 天沒更新）
- Missing cross-links
- Contradictions

結果寫到 `wiki/_lint-report.md`。

---

## Git 流程

boba-wiki **直接 push main**（不走 PR），因為：
- Wiki 內容是 LLM 維護的，不需要 code review
- Obsidian 端靠 auto-pull 同步
- `raw/` 是 immutable 不會被改

```bash
cd /home/node/boba-wiki
git add -A
git commit -m "ingest: MM/DD daily report"
git push origin main
```

---

## 常見錯誤

| 錯誤 | 原因 | 修正 |
|------|------|------|
| 把日報存到 boba-cli 但沒存到 boba-wiki | wiki 和 cli 是兩個 repo | 兩邊都要存 |
| 改了 Current Status 但資料比 wiki 舊 | backfill 不應改 Current Status | 只加 Key Events |
| 忘記更新 index.md | 每次 ingest 都要更新 | schema 規則第 9 條 |
| 忘記更新 log.md | 每次操作都要 log | schema 規則第 10 條 |
| 改了 raw/ 檔案 | raw 是 immutable | schema 規則第 1 條 |
