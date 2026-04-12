#!/usr/bin/env bash
# Usage: bash scripts/release.sh [patch|minor|major]
set -euo pipefail

TYPE="${1:-patch}"
PLUGIN_JSON="structured-agentic-coding-plugin/.claude-plugin/plugin.json"
CHANGELOG="structured-agentic-coding-plugin/CHANGELOG.md"

# Read current version
CURRENT=$(jq -r '.version' "$PLUGIN_JSON")
IFS='.' read -r MAJ MIN PAT <<< "$CURRENT"

case "$TYPE" in
  major) MAJ=$((MAJ+1)); MIN=0; PAT=0 ;;
  minor) MIN=$((MIN+1)); PAT=0 ;;
  patch) PAT=$((PAT+1)) ;;
  *) echo "Usage: $0 [patch|minor|major]" && exit 1 ;;
esac

NEW="${MAJ}.${MIN}.${PAT}"
TODAY=$(date +%Y-%m-%d)

echo "Releasing $CURRENT → $NEW"

# Update plugin.json
jq --arg v "$NEW" '.version = $v' "$PLUGIN_JSON" > tmp.json && mv tmp.json "$PLUGIN_JSON"

# Insert new entry in CHANGELOG after "## [Unreleased]"
ENTRY="## [${NEW}] - ${TODAY}"
awk -v e="$ENTRY" '
  /^## \[Unreleased\]/ { print; print ""; print e; next }
  { print }
' "$CHANGELOG" > tmp.md && mv tmp.md "$CHANGELOG"

# Commit, tag, push
git add "$PLUGIN_JSON" "$CHANGELOG"
git commit -m "release: v${NEW}"
git tag "v${NEW}"
git push origin main --tags

echo "Done — v${NEW} released"
