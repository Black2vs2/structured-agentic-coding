#!/usr/bin/env bash
# scaffold.sh — Bulk copy + placeholder replacement for structured-agentic-coding
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

# Resolve script directory and plugin version
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_VERSION=$(grep '"version"' "${SCRIPT_DIR}/../.claude-plugin/plugin.json" | head -1 | sed 's/.*"version" *: *"\([^"]*\)".*/\1/')

# Temp file to track manifest entries (source_rel, dest_rel, category)
MANIFEST_ENTRIES=$(mktemp)
trap 'rm -f "$MANIFEST_ENTRIES"' EXIT

# Track created and skipped files
CREATED=0
SKIPPED=0

# --- Helper: copy a file to target, skip if exists, replace placeholders ---
copy_and_replace() {
  local src="$1"
  local dst="$2"
  local source_rel="${3:-}"
  local category="${4:-}"

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

  # Track for manifest generation (hash computed later, after all appends)
  if [[ -n "$source_rel" && -n "$category" ]]; then
    local dst_rel="${dst#$TARGET_DIR/}"
    printf '%s\t%s\t%s\n' "$dst_rel" "$source_rel" "$category" >> "$MANIFEST_ENTRIES"
  fi
}

# --- Phase 4a: Scaffold base files ---
echo "=== Scaffolding base files ==="

# Agents — codebase (prefixed)
for f in "$SCAFFOLD_DIR/base/agents/codebase/"*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/agents/codebase/${PREFIX}-${name}" \
    "base/agents/codebase/${name}" "agents-core"
done

# Agents — domain (prefixed)
for f in "$SCAFFOLD_DIR/base/agents/domain/"*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/agents/domain/${PREFIX}-${name}" \
    "base/agents/domain/${name}" "agents-core"
done

# Commands (not prefixed)
for f in "$SCAFFOLD_DIR/base/commands/"*.md; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/commands/${name}" \
    "base/commands/${name}" "commands"
done

# Templates
for f in "$SCAFFOLD_DIR/base/templates/"*; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  copy_and_replace "$f" "$TARGET_DIR/.claude/templates/${name}" \
    "base/templates/${name}" "templates"
done

# Root files
copy_and_replace "$SCAFFOLD_DIR/base/CLAUDE.md" "$TARGET_DIR/CLAUDE.md" \
  "base/CLAUDE.md" "templates"
copy_and_replace "$SCAFFOLD_DIR/base/AGENTS.md" "$TARGET_DIR/.claude/AGENTS.md" \
  "base/AGENTS.md" "templates"
copy_and_replace "$SCAFFOLD_DIR/base/anti-patterns.md" "$TARGET_DIR/.claude/anti-patterns.md" \
  "base/anti-patterns.md" "config"
copy_and_replace "$SCAFFOLD_DIR/base/settings.json" "$TARGET_DIR/.claude/settings.json" \
  "base/settings.json" "config"

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
    copy_and_replace "$f" "$TARGET_DIR/${BE_DIR}/.claude/agents/${PREFIX}-${name}" \
      "profiles/angular-dotnet/agents/backend/${name}" "agents-profile"
  done

  # Frontend agents (prefixed)
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/frontend/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${FE_DIR}/.claude/agents/${PREFIX}-${name}" \
      "profiles/angular-dotnet/agents/frontend/${name}" "agents-profile"
  done

  # Domain agents (prefixed)
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/domain/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/.claude/agents/domain/${PREFIX}-${name}" \
      "profiles/angular-dotnet/agents/domain/${name}" "agents-profile"
  done

  # Backend scan playbooks (not prefixed)
  mkdir -p "$TARGET_DIR/${BE_DIR}/.claude/agents/be-scans"
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/scans/be-scans/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${BE_DIR}/.claude/agents/be-scans/${name}" \
      "profiles/angular-dotnet/scans/be-scans/${name}" "rules-scans"
  done

  # Frontend scan playbooks (not prefixed)
  mkdir -p "$TARGET_DIR/${FE_DIR}/.claude/agents/fe-scans"
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/scans/fe-scans/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/${FE_DIR}/.claude/agents/fe-scans/${name}" \
      "profiles/angular-dotnet/scans/fe-scans/${name}" "rules-scans"
  done

  # Rules
  for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/rules/"*.json; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    copy_and_replace "$f" "$TARGET_DIR/.claude/rules/${name}" \
      "profiles/angular-dotnet/rules/${name}" "rules-scans"
  done

  # Append profile anti-patterns (with placeholder replacement)
  if [[ -f "$SCAFFOLD_DIR/profiles/angular-dotnet/anti-patterns-profile.md" ]]; then
    echo "" >> "$TARGET_DIR/.claude/anti-patterns.md"
    cat "$SCAFFOLD_DIR/profiles/angular-dotnet/anti-patterns-profile.md" >> "$TARGET_DIR/.claude/anti-patterns.md"
    for key in "${!PLACEHOLDERS[@]}"; do
      _token="__${key}__"
      _value="${PLACEHOLDERS[$key]}"
      _escaped=$(printf '%s' "$_value" | sed 's/[&/\]/\\&/g')
      sed -i "s|${_token}|${_escaped}|g" "$TARGET_DIR/.claude/anti-patterns.md"
    done
    echo "APPEND: .claude/anti-patterns.md (profile anti-patterns)"
  fi

  # Profile-specific commands
  copy_and_replace "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/kill.md" \
    "$TARGET_DIR/.claude/commands/kill.md" \
    "profiles/angular-dotnet/commands/kill.md" "commands"

  if [[ -n "$FE_DIR" && -n "$BE_DIR" ]]; then
    copy_and_replace "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/openapi-sync.md" \
      "$TARGET_DIR/.claude/commands/openapi-sync.md" \
      "profiles/angular-dotnet/commands/openapi-sync.md" "commands"
  fi
fi

# --- Generate scaffold manifest ---
generate_manifest() {
  local manifest="$TARGET_DIR/.claude/scaffold-manifest.json"

  # Don't overwrite existing manifest
  if [[ -f "$manifest" ]]; then
    echo "SKIP: .claude/scaffold-manifest.json (already exists)"
    return
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Portable SHA-256: use sha256sum (Linux/Windows) or shasum (macOS)
  if command -v sha256sum &>/dev/null; then
    _sha256() { sha256sum "$1" | awk '{print $1}'; }
  elif command -v shasum &>/dev/null; then
    _sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
  else
    echo "ERROR: Neither sha256sum nor shasum found. Cannot generate manifest." >&2
    return 1
  fi

  # Escape a value for use as a JSON string (handles backslash and double-quote)
  _json_str() {
    local val="$1"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    printf '%s' "$val"
  }

  # Build files JSON object from tracked entries (hash computed now, after all appends)
  local files_json=""
  local first=true
  while IFS=$'\t' read -r dst_rel source_rel category; do
    [[ -z "$dst_rel" ]] && continue
    local file_path="$TARGET_DIR/$dst_rel"
    [[ -f "$file_path" ]] || continue
    local hash
    hash=$(_sha256 "$file_path")

    if [[ "$first" == "true" ]]; then
      first=false
    else
      files_json+=","
    fi
    files_json+=$(printf '\n    "%s": {"hash": "sha256:%s", "category": "%s", "source": "%s"}' \
      "$(_json_str "$dst_rel")" "$hash" "$(_json_str "$category")" "$(_json_str "$source_rel")")
  done < "$MANIFEST_ENTRIES"

  # Build placeholders JSON object
  local placeholders_json=""
  local pfirst=true
  local sorted_keys
  mapfile -t sorted_keys < <(printf '%s\n' "${!PLACEHOLDERS[@]}" | sort)
  for key in "${sorted_keys[@]}"; do
    local val="${PLACEHOLDERS[$key]}"
    # Escape backslashes and double quotes for JSON
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"

    if [[ "$pfirst" == "true" ]]; then
      pfirst=false
    else
      placeholders_json+=","
    fi
    placeholders_json+=$(printf '\n    "%s": "%s"' "$key" "$val")
  done

  cat > "$manifest" <<MANIFEST_EOF
{
  "version": "${PLUGIN_VERSION}",
  "scaffoldedAt": "${timestamp}",
  "updatedAt": null,
  "profile": "${PROFILE}",
  "placeholders": {${placeholders_json}
  },
  "files": {${files_json}
  }
}
MANIFEST_EOF

  echo "CREATE: .claude/scaffold-manifest.json"
}

generate_manifest

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
