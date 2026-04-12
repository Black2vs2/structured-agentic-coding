#!/usr/bin/env bash
# check-upgrade.sh — SessionStart hook for structured-agentic-coding
# Compares plugin version against project's scaffold manifest.
# Outputs a one-liner notification if versions differ.
# Silent if: no manifest (not scaffolded), or versions match (up to date).

set -euo pipefail

# Read plugin version from plugin.json
# Try CLAUDE_PLUGIN_ROOT first, then fall back to find
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]]; then
  PLUGIN_JSON="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
else
  PLUGIN_ROOT=$(find ~/.claude/plugins -name "plugin.json" -path "*/structured-agentic-coding*" -exec dirname {} \; 2>/dev/null | head -1)
  PLUGIN_ROOT=$(dirname "${PLUGIN_ROOT:-/nonexistent}")
  PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
fi
if [[ ! -f "$PLUGIN_JSON" ]]; then
  exit 0
fi
PLUGIN_VERSION=$(grep '"version"' "$PLUGIN_JSON" | head -1 | sed 's/.*"version" *: *"\([^"]*\)".*/\1/')

# Read scaffold manifest from current project
MANIFEST=".claude/scaffold-manifest.json"
if [[ ! -f "$MANIFEST" ]]; then
  exit 0
fi
SCAFFOLD_VERSION=$(grep '"version"' "$MANIFEST" | head -1 | sed 's/.*"version" *: *"\([^"]*\)".*/\1/')

# Compare versions
if [[ "$PLUGIN_VERSION" == "$SCAFFOLD_VERSION" ]]; then
  exit 0
fi

# Version mismatch — notify
CHANGELOG_URL="https://github.com/Black2vs2/structured-agentic-coding/blob/main/structured-agentic-coding-plugin/CHANGELOG.md"
echo "structured-agentic-coding v${PLUGIN_VERSION} available (project scaffolded with v${SCAFFOLD_VERSION}). Run /upgrade-agentic-coding to update. Changelog: ${CHANGELOG_URL}"
