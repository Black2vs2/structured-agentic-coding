#!/usr/bin/env bash
# scaffold.sh — Bulk copy + placeholder replacement for init-agentic
# Usage: scaffold.sh <scaffold_dir> <target_dir> <profile> <placeholder_args...>
#
# Placeholder args are passed as KEY=VALUE pairs:
#   scaffold.sh /path/to/scaffold /path/to/project angular-dotnet \
#     PREFIX=recruit-app \
#     PROJECT_NAME="Recruit App" \
#     PROJECT_DESC="A SaaS platform" \
#     FE_DIR=frontend \
#     BE_DIR=backend \
#     ...
#
# This script handles file copying and placeholder replacement in bulk.
# Context-dependent placeholders left as __KEY__ are handled by Claude after.

set -euo pipefail

SCAFFOLD_DIR="$1"
TARGET_DIR="$2"
PROFILE="$3"
shift 3

# Parse KEY=VALUE args into associative array
declare -A PLACEHOLDERS
for arg in "$@"; do
  key="${arg%%=*}"
  value="${arg#*=}"
  PLACEHOLDERS["$key"]="$value"
done

PREFIX="${PLACEHOLDERS[PREFIX]:-}"
FE_DIR="${PLACEHOLDERS[FE_DIR]:-}"
BE_DIR="${PLACEHOLDERS[BE_DIR]:-}"

# Track created and skipped files
CREATED=0
SKIPPED=0

# --- Helper: copy a file to target, skip if exists, replace placeholders ---
copy_and_replace() {
  local src="$1"
  local dst="$2"

  if [[ -f "$dst" ]]; then
    echo "SKIP: $dst (already exists)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"

  # Replace all known placeholders using sed
  for key in "${!PLACEHOLDERS[@]}"; do
    local token="__${key}__"
    local value="${PLACEHOLDERS[$key]}"
    # Escape sed special chars in value
    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
    sed -i "s|${token}|${escaped_value}|g" "$dst"
  done

  echo "CREATE: $dst"
  CREATED=$((CREATED + 1))
}

# --- Phase 4a: Scaffold base files ---
echo "=== Scaffolding base files ==="

# Agents — codebase (prefixed)
for f in "$SCAFFOLD_DIR/base/agents/codebase/"*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/agents/codebase/${PREFIX}-${name}"
done

# Agents — domain (prefixed)
for f in "$SCAFFOLD_DIR/base/agents/domain/"*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/agents/domain/${PREFIX}-${name}"
done

# Commands (not prefixed)
for f in "$SCAFFOLD_DIR/base/commands/"*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/commands/${name}"
done

# Templates
for f in "$SCAFFOLD_DIR/base/templates/"*; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/templates/${name}"
done

# Root files
copy_and_replace "$SCAFFOLD_DIR/base/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
copy_and_replace "$SCAFFOLD_DIR/base/AGENTS.md" "$TARGET_DIR/.claude/AGENTS.md"
copy_and_replace "$SCAFFOLD_DIR/base/anti-patterns.md" "$TARGET_DIR/.claude/anti-patterns.md"
copy_and_replace "$SCAFFOLD_DIR/base/settings.json" "$TARGET_DIR/.claude/settings.json"

# Create directories
mkdir -p "$TARGET_DIR/docs/masterplans/executed" "$TARGET_DIR/docs/reports"

# --- Phase 4b: Scaffold profile files (if angular-dotnet) ---
if [[ "$PROFILE" == "angular-dotnet" ]]; then
  echo ""
  echo "=== Scaffolding angular-dotnet profile ==="

  # Backend agents (prefixed)
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/backend/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${BE_DIR}/.claude/agents/${PREFIX}-${name}"
  done

  # Frontend agents (prefixed)
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/frontend/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${FE_DIR}/.claude/agents/${PREFIX}-${name}"
  done

  # Domain agents (prefixed)
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/domain/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/.claude/agents/domain/${PREFIX}-${name}"
  done

  # Backend scan playbooks (not prefixed)
  mkdir -p "$TARGET_DIR/${BE_DIR}/.claude/agents/be-scans"
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/scans/be-scans/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${BE_DIR}/.claude/agents/be-scans/${name}"
  done

  # Frontend scan playbooks (not prefixed)
  mkdir -p "$TARGET_DIR/${FE_DIR}/.claude/agents/fe-scans"
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/scans/fe-scans/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${FE_DIR}/.claude/agents/fe-scans/${name}"
  done

  # Rules
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/rules/"*.json; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/.claude/rules/${name}"
  done

  # Append profile anti-patterns (with placeholder replacement)
  if [[ -f "$SCAFFOLD_DIR/profiles/angular-dotnet/anti-patterns-profile.md" ]]; then
    echo "" >> "$TARGET_DIR/.claude/anti-patterns.md"
    cat "$SCAFFOLD_DIR/profiles/angular-dotnet/anti-patterns-profile.md" >> "$TARGET_DIR/.claude/anti-patterns.md"
    # Run sed on the appended content
    for key in "${!PLACEHOLDERS[@]}"; do
      _token="__${key}__"
      _value="${PLACEHOLDERS[$key]}"
      _escaped=$(printf '%s' "$_value" | sed 's/[&/\]/\\&/g')
      sed -i "s|${_token}|${_escaped}|g" "$TARGET_DIR/.claude/anti-patterns.md"
    done
    echo "APPEND: .claude/anti-patterns.md (profile anti-patterns)"
  fi

  # OpenAPI sync command
  if [[ -n "$FE_DIR" && -n "$BE_DIR" ]]; then
    copy_and_replace "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/openapi-sync.md" \
      "$TARGET_DIR/.claude/commands/openapi-sync.md"
  fi
fi

echo ""
echo "=== Scaffold complete ==="
echo "Created: $CREATED files"
echo "Skipped: $SKIPPED files (already existed)"

# Check for remaining unresolved placeholders
REMAINING=$(grep -rl '__[A-Z_]*__' "$TARGET_DIR/.claude/" "$TARGET_DIR/CLAUDE.md" 2>/dev/null | head -20 || true)
if [[ -n "$REMAINING" ]]; then
  echo ""
  echo "=== Files with unresolved placeholders ==="
  echo "$REMAINING"
fi
