#!/usr/bin/env bash
# upgrade.sh — Upgrade engine for structured-agentic-coding
# Re-renders templates from the new plugin version, compares against
# manifest hashes, and selectively updates files.
#
# Usage:
#   upgrade.sh <scaffold_dir> <target_dir> [options]
#
# Options:
#   --manifest <path>       Path to scaffold-manifest.json (required)
#   --categories <list>     Comma-separated categories to upgrade (required)
#   --conflict-mode <mode>  "skip" or "force" (default: skip)
#   --plugin-version <ver>  New plugin version to write to manifest (required)

set -euo pipefail

# --- Dependency check ---
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for upgrade. Install it:"
  echo "  Windows: choco install jq / scoop install jq"
  echo "  macOS:   brew install jq"
  echo "  Linux:   apt install jq / yum install jq"
  exit 1
fi

# Portable SHA-256
if command -v sha256sum &>/dev/null; then
  _sha256() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum &>/dev/null; then
  _sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  echo "ERROR: Neither sha256sum nor shasum found." >&2
  exit 1
fi

# --- Parse positional args ---
if [[ $# -lt 2 ]]; then
  echo "Usage: upgrade.sh <scaffold_dir> <target_dir> [--manifest <path>] [--categories <list>] [--conflict-mode skip|force] [--plugin-version <ver>]"
  exit 1
fi
SCAFFOLD_DIR="$1"
TARGET_DIR="$2"
shift 2

# Compute plugin directory
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# --- Parse named options ---
MANIFEST_PATH=""
CATEGORIES=""
CONFLICT_MODE="skip"
PLUGIN_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)       MANIFEST_PATH="$2"; shift 2 ;;
    --categories)     CATEGORIES="$2"; shift 2 ;;
    --conflict-mode)  CONFLICT_MODE="$2"; shift 2 ;;
    --plugin-version) PLUGIN_VERSION="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate required args
[[ -z "$MANIFEST_PATH" ]]  && echo "ERROR: --manifest is required"        && exit 1
[[ -z "$CATEGORIES" ]]     && echo "ERROR: --categories is required"      && exit 1
[[ -z "$PLUGIN_VERSION" ]] && echo "ERROR: --plugin-version is required"  && exit 1
[[ ! -f "$MANIFEST_PATH" ]] && echo "ERROR: Manifest not found: $MANIFEST_PATH" && exit 1

# --- Read manifest ---
MANIFEST=$(cat "$MANIFEST_PATH")
PROFILE=$(echo "$MANIFEST" | jq -r '.profile')

# Read placeholders into associative array
declare -A PLACEHOLDERS
while IFS=$'\t' read -r key value; do
  PLACEHOLDERS["$key"]="$value"
done < <(echo "$MANIFEST" | jq -r '.placeholders | to_entries[] | [.key, .value] | @tsv')

PLACEHOLDERS["PLUGIN_DIR"]="$PLUGIN_DIR"

PREFIX="${PLACEHOLDERS[PREFIX]:-}"
FE_DIR="${PLACEHOLDERS[FE_DIR]:-}"
BE_DIR="${PLACEHOLDERS[BE_DIR]:-}"

# Parse selected categories into array
IFS=',' read -ra SELECTED_CATEGORIES <<< "$CATEGORIES"

# --- Counters ---
UPDATED=0
CREATED=0
SKIPPED=0
FORCED=0
REMOVED_UPSTREAM=0

# --- Helper: check if a category is selected ---
is_category_selected() {
  local cat="$1"
  for sel in "${SELECTED_CATEGORIES[@]}"; do
    [[ "$sel" == "$cat" ]] && return 0
  done
  return 1
}

# --- Helper: render a template file with placeholder replacement ---
render_template() {
  local src="$1"
  local tmp
  tmp=$(mktemp "$TEMP_DIR/template.XXXXXX")
  cp "$src" "$tmp"

  for key in "${!PLACEHOLDERS[@]}"; do
    local token="__${key}__"
    local value="${PLACEHOLDERS[$key]}"
    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
    sed -i "s|${token}|${escaped_value}|g" "$tmp"
  done

  echo "$tmp"
}

# --- Helper: compute SHA-256 hash with sha256: prefix ---
compute_hash() {
  echo "sha256:$(_sha256 "$1")"
}

# --- Helper: get manifest hash for a target path ---
get_manifest_hash() {
  local target_rel="$1"
  echo "$MANIFEST" | jq -r --arg path "$target_rel" '.files[$path].hash // empty'
}

# --- Temp directory (holds NEW_MANIFEST_ENTRIES and render_template outputs) ---
TEMP_DIR=$(mktemp -d)
NEW_MANIFEST_ENTRIES="$TEMP_DIR/manifest_entries"
touch "$NEW_MANIFEST_ENTRIES"
trap 'rm -rf "$TEMP_DIR"' EXIT

# --- Helper: process a single template file ---
process_template() {
  local src="$1"
  local target_rel="$2"
  local source_rel="$3"
  local category="$4"
  local target_path="$TARGET_DIR/$target_rel"

  # Render the new template with placeholders
  local rendered
  rendered=$(render_template "$src")

  local manifest_hash
  manifest_hash=$(get_manifest_hash "$target_rel")

  if [[ -n "$manifest_hash" ]]; then
    # File exists in manifest — check for modifications
    if [[ ! -f "$target_path" ]]; then
      # File was in manifest but deleted from disk — recreate
      mkdir -p "$(dirname "$target_path")"
      cp "$rendered" "$target_path"
      local new_hash
      new_hash=$(compute_hash "$target_path")
      echo "CREATE: $target_rel (was deleted)"
      CREATED=$((CREATED + 1))
      printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
    else
      local current_hash
      current_hash=$(compute_hash "$target_path")

      if [[ "$current_hash" == "$manifest_hash" ]]; then
        # Unmodified — safe to overwrite
        cp "$rendered" "$target_path"
        local new_hash
        new_hash=$(compute_hash "$target_path")
        echo "UPDATE: $target_rel"
        UPDATED=$((UPDATED + 1))
        printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
      else
        # Modified by user
        if [[ "$CONFLICT_MODE" == "force" ]]; then
          cp "$rendered" "$target_path"
          local new_hash
          new_hash=$(compute_hash "$target_path")
          echo "FORCE: $target_rel"
          FORCED=$((FORCED + 1))
          printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
        else
          echo "SKIP: $target_rel (modified)"
          SKIPPED=$((SKIPPED + 1))
          # Keep old manifest entry
          printf '%s\t%s\t%s\t%s\n' "$target_rel" "$manifest_hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
        fi
      fi
    fi
  else
    # New file — not in manifest
    if [[ -f "$target_path" ]]; then
      echo "SKIP: $target_rel (exists, not in manifest)"
      SKIPPED=$((SKIPPED + 1))
    else
      mkdir -p "$(dirname "$target_path")"
      cp "$rendered" "$target_path"
      local new_hash
      new_hash=$(compute_hash "$target_path")
      echo "CREATE: $target_rel"
      CREATED=$((CREATED + 1))
      printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
    fi
  fi

  rm -f "$rendered"
}

# --- Helper: process anti-patterns.md as merged base+profile file ---
# scaffold.sh appends the profile anti-patterns to the base file.
# upgrade.sh must do the same to produce the correct hash for comparison.
process_merged_anti_patterns() {
  local base_src="$1"
  local profile_src="$2"
  local target_rel=".claude/anti-patterns.md"
  local target_path="$TARGET_DIR/$target_rel"

  # Render base template
  local rendered_base
  rendered_base=$(render_template "$base_src")

  # Render profile template
  local rendered_profile
  rendered_profile=$(render_template "$profile_src")

  # Merge: append profile to base (same as scaffold.sh)
  local merged
  merged=$(mktemp "$TEMP_DIR/anti-patterns-merged.XXXXXX")
  cat "$rendered_base" > "$merged"
  echo "" >> "$merged"
  cat "$rendered_profile" >> "$merged"
  rm -f "$rendered_base" "$rendered_profile"

  local manifest_hash
  manifest_hash=$(get_manifest_hash "$target_rel")

  if [[ -n "$manifest_hash" ]]; then
    if [[ ! -f "$target_path" ]]; then
      mkdir -p "$(dirname "$target_path")"
      cp "$merged" "$target_path"
      local new_hash
      new_hash=$(compute_hash "$target_path")
      echo "CREATE: $target_rel (was deleted)"
      CREATED=$((CREATED + 1))
      printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "base/anti-patterns.md" "config" >> "$NEW_MANIFEST_ENTRIES"
    else
      local current_hash
      current_hash=$(compute_hash "$target_path")
      if [[ "$current_hash" == "$manifest_hash" ]]; then
        cp "$merged" "$target_path"
        local new_hash
        new_hash=$(compute_hash "$target_path")
        echo "UPDATE: $target_rel"
        UPDATED=$((UPDATED + 1))
        printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "base/anti-patterns.md" "config" >> "$NEW_MANIFEST_ENTRIES"
      else
        if [[ "$CONFLICT_MODE" == "force" ]]; then
          cp "$merged" "$target_path"
          local new_hash
          new_hash=$(compute_hash "$target_path")
          echo "FORCE: $target_rel"
          FORCED=$((FORCED + 1))
          printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "base/anti-patterns.md" "config" >> "$NEW_MANIFEST_ENTRIES"
        else
          echo "SKIP: $target_rel (modified)"
          SKIPPED=$((SKIPPED + 1))
          printf '%s\t%s\t%s\t%s\n' "$target_rel" "$manifest_hash" "base/anti-patterns.md" "config" >> "$NEW_MANIFEST_ENTRIES"
        fi
      fi
    fi
  else
    if [[ -f "$target_path" ]]; then
      echo "SKIP: $target_rel (exists, not in manifest)"
      SKIPPED=$((SKIPPED + 1))
    else
      mkdir -p "$(dirname "$target_path")"
      cp "$merged" "$target_path"
      local new_hash
      new_hash=$(compute_hash "$target_path")
      echo "CREATE: $target_rel"
      CREATED=$((CREATED + 1))
      printf '%s\t%s\t%s\t%s\n' "$target_rel" "$new_hash" "base/anti-patterns.md" "config" >> "$NEW_MANIFEST_ENTRIES"
    fi
  fi

  rm -f "$merged"
}

# --- Category-to-template mapping and processing ---
echo "=== Upgrading structured-agentic-coding ==="

# agents-core: base/agents/codebase/* and base/agents/domain/*
if is_category_selected "agents-core"; then
  for f in "$SCAFFOLD_DIR/base/agents/codebase/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    process_template "$f" ".claude/agents/codebase/${PREFIX}-${name}" \
      "base/agents/codebase/${name}" "agents-core"
  done
  for f in "$SCAFFOLD_DIR/base/agents/domain/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    process_template "$f" ".claude/agents/domain/${PREFIX}-${name}" \
      "base/agents/domain/${name}" "agents-core"
  done
fi

# commands: base/commands/*
if is_category_selected "commands"; then
  for f in "$SCAFFOLD_DIR/base/commands/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    process_template "$f" ".claude/commands/${name}" \
      "base/commands/${name}" "commands"
  done
fi

# templates: base/templates/*, base/CLAUDE.md, base/AGENTS.md
if is_category_selected "templates"; then
  for f in "$SCAFFOLD_DIR/base/templates/"*; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    process_template "$f" ".claude/templates/${name}" \
      "base/templates/${name}" "templates"
  done
  process_template "$SCAFFOLD_DIR/base/CLAUDE.md" "CLAUDE.md" \
    "base/CLAUDE.md" "templates"
  process_template "$SCAFFOLD_DIR/base/AGENTS.md" ".claude/AGENTS.md" \
    "base/AGENTS.md" "templates"
fi

# config: base/settings.json, base/anti-patterns.md
# Note: for angular-dotnet, anti-patterns.md is handled separately (merged with profile)
if is_category_selected "config"; then
  process_template "$SCAFFOLD_DIR/base/settings.json" ".claude/settings.json" \
    "base/settings.json" "config"
  if [[ "$PROFILE" != "angular-dotnet" ]]; then
    process_template "$SCAFFOLD_DIR/base/anti-patterns.md" ".claude/anti-patterns.md" \
      "base/anti-patterns.md" "config"
  fi
fi

# Process profile templates (only if profile matches)
if [[ "$PROFILE" == "angular-dotnet" ]]; then

  # agents-profile
  if is_category_selected "agents-profile"; then
    for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/backend/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      process_template "$f" "${BE_DIR}/.claude/agents/${PREFIX}-${name}" \
        "profiles/angular-dotnet/agents/backend/${name}" "agents-profile"
    done
    for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/frontend/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      process_template "$f" "${FE_DIR}/.claude/agents/${PREFIX}-${name}" \
        "profiles/angular-dotnet/agents/frontend/${name}" "agents-profile"
    done
    for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/agents/domain/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      process_template "$f" ".claude/agents/domain/${PREFIX}-${name}" \
        "profiles/angular-dotnet/agents/domain/${name}" "agents-profile"
    done
  fi

  # commands (profile)
  if is_category_selected "commands"; then
    if [[ -f "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/kill.md" ]]; then
      process_template "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/kill.md" \
        ".claude/commands/kill.md" \
        "profiles/angular-dotnet/commands/kill.md" "commands"
    fi
    if [[ -f "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/openapi-sync.md" ]] && \
       [[ -n "$FE_DIR" && -n "$BE_DIR" ]]; then
      process_template "$SCAFFOLD_DIR/profiles/angular-dotnet/commands/openapi-sync.md" \
        ".claude/commands/openapi-sync.md" \
        "profiles/angular-dotnet/commands/openapi-sync.md" "commands"
    fi
  fi

  # rules-scans
  if is_category_selected "rules-scans"; then
    for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/scans/be-scans/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      process_template "$f" "${BE_DIR}/.claude/agents/be-scans/${name}" \
        "profiles/angular-dotnet/scans/be-scans/${name}" "rules-scans"
    done
    for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/scans/fe-scans/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      process_template "$f" "${FE_DIR}/.claude/agents/fe-scans/${name}" \
        "profiles/angular-dotnet/scans/fe-scans/${name}" "rules-scans"
    done
    for f in "$SCAFFOLD_DIR/profiles/angular-dotnet/rules/"*.json; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      process_template "$f" ".claude/rules/${name}" \
        "profiles/angular-dotnet/rules/${name}" "rules-scans"
    done
  fi

  # config (profile anti-patterns — merged into .claude/anti-patterns.md like scaffold.sh)
  if is_category_selected "config"; then
    if [[ -f "$SCAFFOLD_DIR/profiles/angular-dotnet/anti-patterns-profile.md" ]]; then
      process_merged_anti_patterns \
        "$SCAFFOLD_DIR/base/anti-patterns.md" \
        "$SCAFFOLD_DIR/profiles/angular-dotnet/anti-patterns-profile.md"
    fi
  fi
fi

# --- Detect files removed upstream and preserve non-selected categories ---
while IFS=$'\t' read -r target_rel hash source_rel category; do
  if ! is_category_selected "$category"; then
    # Non-selected category — keep existing entry unchanged
    printf '%s\t%s\t%s\t%s\n' "$target_rel" "$hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
  elif [[ ! -f "$SCAFFOLD_DIR/$source_rel" ]]; then
    # Source template removed in new version — report but keep in manifest
    echo "REMOVED_UPSTREAM: $target_rel"
    REMOVED_UPSTREAM=$((REMOVED_UPSTREAM + 1))
    printf '%s\t%s\t%s\t%s\n' "$target_rel" "$hash" "$source_rel" "$category" >> "$NEW_MANIFEST_ENTRIES"
  fi
done < <(echo "$MANIFEST" | jq -r '.files | to_entries[] | [.key, .value.hash, .value.source, .value.category] | @tsv')

# --- Update manifest ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SCAFFOLD_AT=$(echo "$MANIFEST" | jq -r '.scaffoldedAt')

# Build new files JSON from entries using jq (handles escaping correctly)
files_array="[]"
while IFS=$'\t' read -r target_rel hash source_rel category; do
  [[ -z "$target_rel" ]] && continue
  files_array=$(printf '%s' "$files_array" | jq \
    --arg k "$target_rel" \
    --arg h "$hash" \
    --arg c "$category" \
    --arg s "$source_rel" \
    '. + [{"key": $k, "hash": $h, "category": $c, "source": $s}]')
done < "$NEW_MANIFEST_ENTRIES"
FILES_JSON=$(printf '%s' "$files_array" | jq 'reduce .[] as $item ({}; .[$item.key] = {"hash": $item.hash, "category": $item.category, "source": $item.source})')

# Build placeholders JSON (preserve from original)
PLACEHOLDERS_JSON=$(echo "$MANIFEST" | jq '.placeholders')

# Write updated manifest (atomic write via jq + mv)
tmp_manifest=$(mktemp "$TEMP_DIR/manifest.XXXXXX")
jq -n \
  --arg version "$PLUGIN_VERSION" \
  --arg scaffoldedAt "$SCAFFOLD_AT" \
  --arg updatedAt "$TIMESTAMP" \
  --arg profile "$PROFILE" \
  --argjson placeholders "$PLACEHOLDERS_JSON" \
  --argjson files "$FILES_JSON" \
  '{version: $version, scaffoldedAt: $scaffoldedAt, updatedAt: $updatedAt, profile: $profile, placeholders: $placeholders, files: $files}' \
  > "$tmp_manifest"
mv "$tmp_manifest" "$MANIFEST_PATH"

echo ""
echo "=== Upgrade complete ==="
echo "Updated: $UPDATED"
echo "Created: $CREATED"
echo "Skipped: $SKIPPED (modified)"
echo "Forced: $FORCED"
echo "Removed upstream: $REMOVED_UPSTREAM"
