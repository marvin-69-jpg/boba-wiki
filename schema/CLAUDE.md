# BOBA Wiki — Schema

This wiki is a **persistent, compounding knowledge base** built from BOBA Daily reports.
The LLM writes and maintains all wiki pages. Humans read via Obsidian. Git syncs between them.

## Architecture

```
raw/          ← immutable daily reports (source of truth)
wiki/         ← LLM-maintained entity pages (the knowledge base)
index.md      ← catalog of all wiki pages + one-line summaries
log.md        ← append-only record of all operations
schema/       ← this file (rules for the LLM)
```

## Wiki Page Format

Every page in `wiki/` follows this template:

```markdown
---
aliases: [別名1, 別名2]
first_seen: YYYY-MM-DD
last_updated: YYYY-MM-DD
tags: [crypto, defi, regulation, macro, tech, culture, people]
---

# Entity Name

One-paragraph summary: what this is, why it matters.

## Current Status

Bullet points of the latest known state. Update (not append) when new info arrives.
Mark uncertainty: "as of 2026-04-12" or "unconfirmed".

## Key Events

Reverse-chronological list. Each entry:
- **YYYY-MM-DD** — What happened. Source: [[raw/YYYY/MM/DD]]

## Related

[[other-entity]] [[another-entity]]
```

### Naming Convention

- Filename = lowercase, hyphens for spaces: `bitcoin-etf.md`, `circle.md`, `cz.md`
- Use the most commonly known name (not legal name)
- One entity per page. Don't merge "Ethena" and "USDe" — make two pages and cross-link

## Operations

### 1. Ingest

Triggered after a new daily report is saved to `raw/`. This is the core operation.

**Steps:**

#### Step 1: Orient
- Read `index.md` to understand the current wiki landscape
- Read the last 5 entries of `log.md` to know what was recently processed
- Read the new raw file

#### Step 2: Extract
- Identify every entity mentioned in the daily report:
  - Projects/protocols (Ethena, Base, Scroll...)
  - People (CZ, Trump, Gary Gensler...)
  - Assets (BTC, ETH, SOL...)
  - Organizations (SEC, Circle, WLFI...)
  - Concepts/trends (RWA, DeFi yields, stablecoin regulation...)
- For each entity, note what the report says about it

#### Step 3: Plan
- For each extracted entity, check `index.md`:
  - **Exists** → will update (load the page)
  - **Doesn't exist** → will create (use template above)
- Identify cross-links: which entities in today's report relate to each other?
- Identify contradictions: does today's report contradict anything in existing pages?
- Write out the plan before executing (list of files to create/update)

#### Step 4: Execute
For each page to update:
1. Read the full page
2. **Rewrite** the "Current Status" section to reflect latest info (don't append — integrate)
3. **Append** to "Key Events" (reverse-chronological, newest first)
4. **Add cross-links** in "Related" section (bidirectional — if A links B, B should link A)
5. **Handle contradictions**: if new info contradicts existing wiki content, update the content and note the change in Key Events (e.g. "Previously reported X, now confirmed Y")
6. Update `last_updated` in frontmatter

For new pages:
1. Create using the template
2. Fill in all sections based on what the report says
3. Add cross-links to related existing pages
4. Go to those related pages and add a backlink

#### Step 5: Update Meta
1. **index.md**: add new pages, update summaries for modified pages
2. **log.md**: append one entry:
   ```
   ## [YYYY-MM-DD] ingest | BOBA Daily #NNN
   - Created: page1.md, page2.md
   - Updated: page3.md, page4.md, page5.md
   - Contradictions resolved: [if any]
   - New cross-links: page1 ↔ page3, page2 ↔ page5
   ```

### 2. Query

When asked a question about the wiki:
1. Read `index.md` to find relevant pages
2. Read those pages
3. Synthesize an answer with `[[citations]]` to wiki pages
4. If the answer produces a valuable new synthesis, **save it as a new wiki page** and update index

### 3. Lint

Periodic health check. Look for:
- **Orphan pages**: pages with no inbound links from other pages
- **Missing pages**: entities mentioned in `[[links]]` but no page exists
- **Stale content**: "Current Status" that hasn't been updated in 30+ days
- **Missing cross-links**: pages that discuss the same topic but don't link each other
- **Contradictions**: pages that disagree with each other
- Write findings to `wiki/_lint-report.md`

## Rules

1. **Never modify raw files.** Raw sources are immutable.
2. **Always rewrite, never just append.** Wiki pages should read as coherent documents, not logs.
3. **Every claim needs a source.** Link to `[[raw/YYYY/MM/DD]]` or external URL.
4. **Bidirectional links.** If A references B, B must reference A in its Related section.
5. **Use `[[wiki-links]]`** for internal references (Obsidian format).
6. **One entity per page.** If in doubt, split and cross-link.
7. **Write in Traditional Chinese** (technical terms keep English). Match BOBA's tone.
8. **Frontmatter is mandatory.** Every wiki page must have the YAML frontmatter block.
9. **Update index.md on every operation.** Index must always reflect current wiki state.
10. **Log every operation.** No silent changes.
