#!/usr/bin/env bash
# BOBA Wiki — Daily Ingest Script
# Usage: ./ingest.sh [YYYY-MM-DD]
# Runs a Sonnet session to ingest today's daily report into the wiki.
# If no date given, uses today's date.

set -euo pipefail
cd /home/node/boba-wiki

DATE="${1:-$(date +%Y-%m-%d)}"
YEAR=$(echo "$DATE" | cut -d- -f1)
MONTH=$(echo "$DATE" | cut -d- -f2)
DAY=$(echo "$DATE" | cut -d- -f3)
RAW_FILE="raw/${YEAR}/${MONTH}/${DAY}.md"

if [ ! -f "$RAW_FILE" ]; then
  echo "❌ Raw file not found: $RAW_FILE"
  echo "   Make sure the daily report has been saved first."
  exit 1
fi

echo "🧋 Starting ingest for ${DATE} using Sonnet..."
echo "   Raw file: ${RAW_FILE}"

claude -p "$(cat <<PROMPT
You are the BOBA Wiki ingest agent. Read schema/CLAUDE.md for full rules, then execute a complete ingest of ${RAW_FILE}.

Steps:
1. Read schema/CLAUDE.md
2. Read index.md and the last 10 lines of log.md
3. Read ${RAW_FILE}
4. Extract all entities from today's report
5. For each entity: check index.md → if page exists, read it and contextually rewrite; if not, create new page using the template in schema
6. Add cross-links (bidirectional)
7. Handle contradictions (flag or update)
8. Update index.md (add new pages, update summaries)
9. Append to log.md
10. git add -A && git commit -m "ingest: ${DATE} daily report" && git push

Write in Traditional Chinese (technical terms keep English). Be thorough but concise.
PROMPT
)" --model sonnet --allowedTools "Read,Write,Edit,Bash,Glob,Grep" --dangerously-skip-permissions 2>&1

echo ""
echo "✅ Ingest complete for ${DATE}"
