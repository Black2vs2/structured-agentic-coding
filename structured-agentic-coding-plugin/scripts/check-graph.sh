#!/usr/bin/env bash
# SessionStart hook: report graph status.

DB_PATH=".code-graph/graph.db"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Code graph: not built yet — will auto-build on first query."
    exit 0
fi

if ! command -v sqlite3 &>/dev/null; then
    echo "Code graph: database exists but sqlite3 not available for status check."
    exit 0
fi

SYMBOL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM nodes;" 2>/dev/null || echo "0")
LAST_HASH=$(sqlite3 "$DB_PATH" "SELECT value FROM meta WHERE key='last_indexed_hash';" 2>/dev/null || echo "")
CURRENT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")

if [[ -z "$LAST_HASH" ]]; then
    echo "Code graph: $SYMBOL_COUNT symbols indexed, needs rebuild."
elif [[ "$LAST_HASH" == "$CURRENT_HASH" ]]; then
    echo "Code graph: $SYMBOL_COUNT symbols indexed, up to date."
else
    BEHIND=$(git rev-list --count "$LAST_HASH..HEAD" 2>/dev/null || echo "?")
    echo "Code graph: $SYMBOL_COUNT symbols indexed, $BEHIND commits behind — will auto-update on first query."
fi
