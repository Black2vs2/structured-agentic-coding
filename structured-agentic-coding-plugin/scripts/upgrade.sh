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

# --- macOS portability shim ---
# Prefer Homebrew gnu-sed's gnubin dir over BSD sed (see scaffold.sh for details).
for _gnubin in \
  /usr/local/opt/gnu-sed/libexec/gnubin \
  /opt/homebrew/opt/gnu-sed/libexec/gnubin \
; do
  if [[ -d "$_gnubin" ]]; then
    export PATH="$_gnubin:$PATH"
    break
  fi
done
unset _gnubin

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
MIGRATE_PROFILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)         MANIFEST_PATH="$2"; shift 2 ;;
    --categories)       CATEGORIES="$2"; shift 2 ;;
    --conflict-mode)    CONFLICT_MODE="$2"; shift 2 ;;
    --plugin-version)   PLUGIN_VERSION="$2"; shift 2 ;;
    --migrate-profile)  MIGRATE_PROFILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate required args
[[ -z "$MANIFEST_PATH" ]]  && echo "ERROR: --manifest is required"        && exit 1
[[ -z "$PLUGIN_VERSION" ]] && echo "ERROR: --plugin-version is required"  && exit 1
[[ ! -f "$MANIFEST_PATH" ]] && echo "ERROR: Manifest not found: $MANIFEST_PATH" && exit 1

# --migrate-profile doesn't require --categories (it re-runs full scaffold for the new profile)
if [[ -z "$MIGRATE_PROFILE" && -z "$CATEGORIES" ]]; then
  echo "ERROR: --categories is required (or pass --migrate-profile <new>)"
  exit 1
fi

# --- Read manifest ---
MANIFEST=$(cat "$MANIFEST_PATH")
PROFILE=$(echo "$MANIFEST" | jq -r '.profile' | tr -d '\r')

# Resolve the list of profiles that contributed to this scaffold.
# New manifests (4.4.0+) record a `profiles` array; legacy manifests only have
# `profile`. If the array is absent, expand the scalar via composedFrom (same
# logic as scaffold.sh's resolve_profile_list) so umbrella upgrades still work.
declare -a PROFILE_LIST=()
mapfile -t PROFILE_LIST < <(echo "$MANIFEST" | jq -r '.profiles[]? // empty' | tr -d '\r')
if [[ ${#PROFILE_LIST[@]} -eq 0 ]]; then
  _umbrella_manifest="$SCAFFOLD_DIR/profiles/$PROFILE/variables.json"
  if [[ -f "$_umbrella_manifest" ]]; then
    mapfile -t _composed < <(jq -r '.composedFrom[]? // empty' "$_umbrella_manifest" 2>/dev/null)
    if [[ ${#_composed[@]} -gt 0 ]]; then
      PROFILE_LIST=("${_composed[@]}" "$PROFILE")
    fi
  fi
  unset _umbrella_manifest _composed
fi
if [[ ${#PROFILE_LIST[@]} -eq 0 ]]; then
  PROFILE_LIST=("$PROFILE")
fi

# Read placeholders into associative array
# Note: tr -d '\r' strips Windows CR that jq may emit, preventing \r in filenames
declare -A PLACEHOLDERS
while IFS=$'\t' read -r key value; do
  PLACEHOLDERS["$key"]="$value"
done < <(echo "$MANIFEST" | jq -r '.placeholders | to_entries[] | [.key, .value] | @tsv' | tr -d '\r')

PLACEHOLDERS["PLUGIN_DIR"]="$PLUGIN_DIR"

PREFIX="${PLACEHOLDERS[PREFIX]:-}"
FE_DIR="${PLACEHOLDERS[FE_DIR]:-}"
BE_DIR="${PLACEHOLDERS[BE_DIR]:-}"

# --- Profile migration branch ---
# When --migrate-profile is set, re-run scaffold.sh with the new profile and
# carry-over placeholders. scaffold.sh's skip-if-exists preserves user files
# automatically — so existing edits stay untouched and only new profile-specific
# files get created.
if [[ -n "$MIGRATE_PROFILE" ]]; then
  echo "=== Profile migration: $PROFILE → $MIGRATE_PROFILE ==="

  # Carry-over placeholders (always compatible across profiles)
  CARRY_OVER_KEYS=(PREFIX PROJECT_NAME PROJECT_DESC FE_DIR BE_DIR SCOPE)

  # Build scaffold.sh args
  SCAFFOLD_SCRIPT="$PLUGIN_DIR/scripts/scaffold.sh"
  SCAFFOLD_ARGS=()
  for key in "${CARRY_OVER_KEYS[@]}"; do
    value="${PLACEHOLDERS[$key]:-}"
    if [[ -n "$value" ]]; then
      SCAFFOLD_ARGS+=("$key=$value")
    fi
  done

  # For any stack-specific placeholder already resolved in the old manifest,
  # keep it if it's also declared by the new profile's variables.json (same name = same meaning).
  # Users can manually re-run scaffold/upgrade after reviewing the result if they need to change a value.
  NEW_MANIFEST="$SCAFFOLD_DIR/profiles/$MIGRATE_PROFILE/variables.json"
  if [[ -f "$NEW_MANIFEST" ]]; then
    while IFS= read -r new_key; do
      [[ -z "$new_key" ]] && continue
      for carried_key in "${CARRY_OVER_KEYS[@]}"; do
        [[ "$new_key" == "$carried_key" ]] && continue 2
      done
      existing_value="${PLACEHOLDERS[$new_key]:-}"
      if [[ -n "$existing_value" ]]; then
        SCAFFOLD_ARGS+=("$new_key=$existing_value")
      fi
    done < <(jq -r '.variables[]?.key' "$NEW_MANIFEST" 2>/dev/null)
  fi

  echo "Carrying over: ${SCAFFOLD_ARGS[*]}"
  echo ""

  # Invoke scaffold.sh; it skips any existing files (including user-modified ones).
  bash "$SCAFFOLD_SCRIPT" "$SCAFFOLD_DIR" "$TARGET_DIR" "$MIGRATE_PROFILE" "${SCAFFOLD_ARGS[@]}"

  # Update the manifest's profile field in-place
  MANIFEST_OUT="$TARGET_DIR/.claude/scaffold-manifest.json"
  if [[ -f "$MANIFEST_OUT" ]]; then
    jq --arg p "$MIGRATE_PROFILE" '.profile = $p' "$MANIFEST_OUT" > "$MANIFEST_OUT.tmp" \
      && mv "$MANIFEST_OUT.tmp" "$MANIFEST_OUT"
  fi

  echo ""
  echo "=== Migration complete ==="
  echo "Profile: $PROFILE → $MIGRATE_PROFILE"
  echo ""
  echo "Review the changes, then run upgrade again (without --migrate-profile)"
  echo "to pick up the latest plugin version's fixes."
  exit 0
fi

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
  # Normalize line endings to LF (scaffold templates may have CRLF on Windows)
  tr -d '\r' < "$src" > "$tmp"

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

# --- Helper: process anti-patterns.md as merged base + any number of profile overlays ---
# scaffold.sh appends every profile's anti-patterns-profile.md to the base file.
# upgrade.sh must merge the same set (same order) to produce a matching hash.
#
# Usage: process_merged_anti_patterns <base_src> <profile_src_1> [<profile_src_2> ...]
process_merged_anti_patterns() {
  local base_src="$1"
  shift
  local target_rel=".claude/anti-patterns.md"
  local target_path="$TARGET_DIR/$target_rel"

  # Render base template
  local rendered_base
  rendered_base=$(render_template "$base_src")

  # Merge: base + each profile overlay (blank line between, same as scaffold.sh)
  local merged
  merged=$(mktemp "$TEMP_DIR/anti-patterns-merged.XXXXXX")
  cat "$rendered_base" > "$merged"
  rm -f "$rendered_base"
  local overlay_src
  for overlay_src in "$@"; do
    [[ -f "$overlay_src" ]] || continue
    local rendered_overlay
    rendered_overlay=$(render_template "$overlay_src")
    echo "" >> "$merged"
    cat "$rendered_overlay" >> "$merged"
    rm -f "$rendered_overlay"
  done

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
# anti-patterns is handled per-profile below (merged with each profile's overlay).
# If NO profile contributed an anti-patterns-profile.md, fall back to base-only here.
has_profile_anti_patterns=false
for _p in "${PROFILE_LIST[@]}"; do
  if [[ -f "$SCAFFOLD_DIR/profiles/$_p/anti-patterns-profile.md" ]]; then
    has_profile_anti_patterns=true
    break
  fi
done
unset _p

if is_category_selected "config"; then
  process_template "$SCAFFOLD_DIR/base/settings.json" ".claude/settings.json" \
    "base/settings.json" "config"
  if [[ "$has_profile_anti_patterns" != "true" ]]; then
    process_template "$SCAFFOLD_DIR/base/anti-patterns.md" ".claude/anti-patterns.md" \
      "base/anti-patterns.md" "config"
  fi
fi

# Process profile templates — iterate over every profile in PROFILE_LIST so
# composed/umbrella scaffolds upgrade all contributing profiles' files in one pass.
for _profile in "${PROFILE_LIST[@]}"; do
  PROFILE_SCAFFOLD_DIR="$SCAFFOLD_DIR/profiles/$_profile"
  [[ -d "$PROFILE_SCAFFOLD_DIR" ]] || continue

  # agents-profile
  if is_category_selected "agents-profile"; then
    if [[ -d "$PROFILE_SCAFFOLD_DIR/agents/backend" ]]; then
      for f in "$PROFILE_SCAFFOLD_DIR/agents/backend/"*.md; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        process_template "$f" "${BE_DIR}/.claude/agents/${PREFIX}-${name}" \
          "profiles/${_profile}/agents/backend/${name}" "agents-profile"
      done
    fi
    if [[ -d "$PROFILE_SCAFFOLD_DIR/agents/frontend" ]]; then
      for f in "$PROFILE_SCAFFOLD_DIR/agents/frontend/"*.md; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        process_template "$f" "${FE_DIR}/.claude/agents/${PREFIX}-${name}" \
          "profiles/${_profile}/agents/frontend/${name}" "agents-profile"
      done
    fi
    if [[ -d "$PROFILE_SCAFFOLD_DIR/agents/domain" ]]; then
      for f in "$PROFILE_SCAFFOLD_DIR/agents/domain/"*.md; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        process_template "$f" ".claude/agents/domain/${PREFIX}-${name}" \
          "profiles/${_profile}/agents/domain/${name}" "agents-profile"
      done
    fi
  fi

  # commands (profile)
  if is_category_selected "commands" && [[ -d "$PROFILE_SCAFFOLD_DIR/commands" ]]; then
    for f in "$PROFILE_SCAFFOLD_DIR/commands/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      # openapi-sync requires both FE and BE to be scaffolded.
      if [[ "$name" == "openapi-sync.md" ]] && { [[ -z "$FE_DIR" ]] || [[ -z "$BE_DIR" ]]; }; then
        continue
      fi
      process_template "$f" ".claude/commands/${name}" \
        "profiles/${_profile}/commands/${name}" "commands"
    done
  fi

  # rules-scans
  if is_category_selected "rules-scans"; then
    if [[ -d "$PROFILE_SCAFFOLD_DIR/scans/be-scans" ]]; then
      for f in "$PROFILE_SCAFFOLD_DIR/scans/be-scans/"*.md; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        process_template "$f" "${BE_DIR}/.claude/agents/be-scans/${name}" \
          "profiles/${_profile}/scans/be-scans/${name}" "rules-scans"
      done
    fi
    if [[ -d "$PROFILE_SCAFFOLD_DIR/scans/fe-scans" ]]; then
      for f in "$PROFILE_SCAFFOLD_DIR/scans/fe-scans/"*.md; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        process_template "$f" "${FE_DIR}/.claude/agents/fe-scans/${name}" \
          "profiles/${_profile}/scans/fe-scans/${name}" "rules-scans"
      done
    fi
    if [[ -d "$PROFILE_SCAFFOLD_DIR/rules" ]]; then
      for f in "$PROFILE_SCAFFOLD_DIR/rules/"*.json; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        process_template "$f" ".claude/rules/${name}" \
          "profiles/${_profile}/rules/${name}" "rules-scans"
      done
    fi
  fi
done
unset _profile

# config: merged anti-patterns (base + every contributing profile's overlay).
# Replaces the old hardcoded angular-dotnet branch with a generic multi-profile merge.
if is_category_selected "config" && [[ "$has_profile_anti_patterns" == "true" ]]; then
  profile_overlays=()
  for _p in "${PROFILE_LIST[@]}"; do
    _overlay="$SCAFFOLD_DIR/profiles/$_p/anti-patterns-profile.md"
    [[ -f "$_overlay" ]] && profile_overlays+=("$_overlay")
  done
  unset _p _overlay
  process_merged_anti_patterns \
    "$SCAFFOLD_DIR/base/anti-patterns.md" \
    "${profile_overlays[@]}"
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
done < <(echo "$MANIFEST" | jq -r '.files | to_entries[] | [.key, .value.hash, .value.source, .value.category] | @tsv' | tr -d '\r')

# --- Update manifest ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SCAFFOLD_AT=$(echo "$MANIFEST" | jq -r '.scaffoldedAt' | tr -d '\r')

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

# Build the resolved `profiles` array so the upgraded manifest carries the same
# composition metadata that scaffold.sh writes for fresh scaffolds.
PROFILES_JSON="[]"
for _p in "${PROFILE_LIST[@]}"; do
  PROFILES_JSON=$(printf '%s' "$PROFILES_JSON" | jq --arg p "$_p" '. + [$p]')
done
unset _p

# Write updated manifest (atomic write via jq + mv)
tmp_manifest=$(mktemp "$TEMP_DIR/manifest.XXXXXX")
jq -n \
  --arg version "$PLUGIN_VERSION" \
  --arg scaffoldedAt "$SCAFFOLD_AT" \
  --arg updatedAt "$TIMESTAMP" \
  --arg profile "$PROFILE" \
  --argjson profiles "$PROFILES_JSON" \
  --argjson placeholders "$PLACEHOLDERS_JSON" \
  --argjson files "$FILES_JSON" \
  '{version: $version, scaffoldedAt: $scaffoldedAt, updatedAt: $updatedAt, profile: $profile, profiles: $profiles, placeholders: $placeholders, files: $files}' \
  > "$tmp_manifest"
mv "$tmp_manifest" "$MANIFEST_PATH"

echo ""
echo "=== Upgrade complete ==="
echo "Updated: $UPDATED"
echo "Created: $CREATED"
echo "Skipped: $SKIPPED (modified)"
echo "Forced: $FORCED"
echo "Removed upstream: $REMOVED_UPSTREAM"
