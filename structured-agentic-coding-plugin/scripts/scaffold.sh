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

# --- macOS portability shim ---
# Homebrew's gnu-sed ships as `gsed` by default, but installs a `sed` symlink
# under <prefix>/opt/gnu-sed/libexec/gnubin. Prepend that directory if present
# so the `sed -i "..."` calls below use GNU sed instead of BSD sed.
# Linux / CI (no such directory) is a no-op.
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

SCAFFOLD_DIR="$1"
TARGET_DIR="$2"
PROFILE="$3"
shift 3

# Compute plugin directory (parent of scripts/)
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Parse KEY=VALUE args into associative array
declare -A PLACEHOLDERS
for arg in "$@"; do
  key="${arg%%=*}"
  value="${arg#*=}"
  PLACEHOLDERS["$key"]="$value"
done

PLACEHOLDERS["PLUGIN_DIR"]="$PLUGIN_DIR"

PREFIX="${PLACEHOLDERS[PREFIX]:-}"
FE_DIR="${PLACEHOLDERS[FE_DIR]:-}"
BE_DIR="${PLACEHOLDERS[BE_DIR]:-}"
SCOPE="${PLACEHOLDERS[SCOPE]:-fullstack}"

# Validate SCOPE
case "$SCOPE" in
  fe|be|fullstack) ;;
  *) echo "ERROR: SCOPE must be fe|be|fullstack (got '$SCOPE')" >&2; exit 1 ;;
esac

# Ensure SCOPE is in PLACEHOLDERS so it lands in the manifest (always)
PLACEHOLDERS["SCOPE"]="$SCOPE"

# --- Scope helpers ---
scope_includes_be() { [[ "$SCOPE" == "be" || "$SCOPE" == "fullstack" ]]; }
scope_includes_fe() { [[ "$SCOPE" == "fe" || "$SCOPE" == "fullstack" ]]; }

# --- Helper: load profile variables.json (populates PLACEHOLDERS with defaults) ---
# No-op for profiles without a manifest (legacy/hardcoded profiles).
# Only sets a key if it isn't already provided by CLI args.
load_profile_variables() {
  local profile="$1"
  local manifest="$SCAFFOLD_DIR/profiles/$profile/variables.json"
  [[ -f "$manifest" ]] || return 0

  while IFS=$'\t' read -r key default; do
    [[ -z "$key" || -z "$default" ]] && continue
    if [[ -z "${PLACEHOLDERS[$key]:-}" ]]; then
      PLACEHOLDERS["$key"]="$default"
    fi
  done < <(jq -r '.variables[]? | select(.default != null) | [.key, .default] | @tsv' "$manifest" 2>/dev/null)
}

# --- Helper: render a fragmented template per SCOPE ---
# Usage: render_fragmented_template <fragment_dir> <output_file> [<source_rel>] [<category>] [<overlay_file>]
# Concatenates _core.<ext> + _be-section.<ext> (if BE scope) + _fe-section.<ext> (if FE scope),
# where <ext> is derived from output_file. If <overlay_file> is provided and non-empty, it's
# appended after the base fragments — used for profile-specific CLAUDE.md overlays. Then applies
# placeholder replacement, skip-if-exists behavior, and manifest tracking.
render_fragmented_template() {
  local fragment_dir="$1"
  local output_file="$2"
  local source_rel="${3:-}"
  local category="${4:-}"
  local overlay_file="${5:-}"

  if [[ -f "$output_file" ]]; then
    echo "SKIP: $output_file (already exists)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  local ext="${output_file##*.}"
  local core="$fragment_dir/_core.$ext"
  local be="$fragment_dir/_be-section.$ext"
  local fe="$fragment_dir/_fe-section.$ext"

  if [[ ! -f "$core" ]]; then
    echo "ERROR: missing required fragment $core" >&2
    return 1
  fi

  mkdir -p "$(dirname "$output_file")"
  cat "$core" > "$output_file"
  if scope_includes_be && [[ -f "$be" && -s "$be" ]]; then
    cat "$be" >> "$output_file"
  fi
  if scope_includes_fe && [[ -f "$fe" && -s "$fe" ]]; then
    cat "$fe" >> "$output_file"
  fi
  if [[ -n "$overlay_file" && -f "$overlay_file" && -s "$overlay_file" ]]; then
    cat "$overlay_file" >> "$output_file"
  fi

  # Replace placeholders (same logic as copy_and_replace)
  for key in "${!PLACEHOLDERS[@]}"; do
    local token="__${key}__"
    local value="${PLACEHOLDERS[$key]}"
    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
    sed -i "s|${token}|${escaped_value}|g" "$output_file"
  done

  echo "CREATE: $output_file"
  CREATED=$((CREATED + 1))

  # Track for manifest (source_rel identifies the fragment directory, not a single file)
  if [[ -n "$source_rel" && -n "$category" ]]; then
    local dst_rel="${output_file#$TARGET_DIR/}"
    printf '%s\t%s\t%s\n' "$dst_rel" "$source_rel" "$category" >> "$MANIFEST_ENTRIES"
  fi
}

# Populate defaults from profile manifest (if present).
# CLI args take precedence — this only fills in missing keys.
load_profile_variables "$PROFILE"

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

# Root files — CLAUDE.md, AGENTS.md, settings.json assembled from fragments per SCOPE
# CLAUDE.md supports an optional profile overlay (profiles/<profile>/claude-section.md)
# appended after the base fragments so profile-specific commands live with the profile.
PROFILE_CLAUDE_OVERLAY="$SCAFFOLD_DIR/profiles/$PROFILE/claude-section.md"
[[ -f "$PROFILE_CLAUDE_OVERLAY" ]] || PROFILE_CLAUDE_OVERLAY=""

render_fragmented_template "$SCAFFOLD_DIR/base/claude" "$TARGET_DIR/CLAUDE.md" \
  "base/claude" "templates" "$PROFILE_CLAUDE_OVERLAY"
render_fragmented_template "$SCAFFOLD_DIR/base/agents-md" "$TARGET_DIR/.claude/AGENTS.md" \
  "base/agents-md" "templates"
render_fragmented_template "$SCAFFOLD_DIR/base/settings" "$TARGET_DIR/.claude/settings.json" \
  "base/settings" "config"
copy_and_replace "$SCAFFOLD_DIR/base/anti-patterns.md" "$TARGET_DIR/.claude/anti-patterns.md" \
  "base/anti-patterns.md" "config"

# Create directories
mkdir -p "$TARGET_DIR/docs/masterplans/executed" "$TARGET_DIR/docs/reports"

# Add .code-graph/ to .gitignore
echo ".code-graph/" >> "$TARGET_DIR/.gitignore"

# --- Phase 4b: Scaffold profile files (generic for any profile with a scaffold dir) ---
PROFILE_SCAFFOLD_DIR="$SCAFFOLD_DIR/profiles/$PROFILE"
if [[ -d "$PROFILE_SCAFFOLD_DIR" ]]; then
  echo ""
  echo "=== Scaffolding $PROFILE profile ==="

  # Backend agents (prefixed) — BE scope only
  if scope_includes_be && [[ -d "$PROFILE_SCAFFOLD_DIR/agents/backend" ]]; then
    for f in "$PROFILE_SCAFFOLD_DIR/agents/backend/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      copy_and_replace "$f" "$TARGET_DIR/${BE_DIR}/.claude/agents/${PREFIX}-${name}" \
        "profiles/${PROFILE}/agents/backend/${name}" "agents-profile"
    done
  fi

  # Frontend agents (prefixed) — FE scope only
  if scope_includes_fe && [[ -d "$PROFILE_SCAFFOLD_DIR/agents/frontend" ]]; then
    for f in "$PROFILE_SCAFFOLD_DIR/agents/frontend/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      copy_and_replace "$f" "$TARGET_DIR/${FE_DIR}/.claude/agents/${PREFIX}-${name}" \
        "profiles/${PROFILE}/agents/frontend/${name}" "agents-profile"
    done
  fi

  # Domain agents (prefixed) — always (cross-cutting)
  if [[ -d "$PROFILE_SCAFFOLD_DIR/agents/domain" ]]; then
    for f in "$PROFILE_SCAFFOLD_DIR/agents/domain/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      copy_and_replace "$f" "$TARGET_DIR/.claude/agents/domain/${PREFIX}-${name}" \
        "profiles/${PROFILE}/agents/domain/${name}" "agents-profile"
    done
  fi

  # Backend scan playbooks (not prefixed) — BE scope only
  if scope_includes_be && [[ -d "$PROFILE_SCAFFOLD_DIR/scans/be-scans" ]]; then
    mkdir -p "$TARGET_DIR/${BE_DIR}/.claude/agents/be-scans"
    for f in "$PROFILE_SCAFFOLD_DIR/scans/be-scans/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      copy_and_replace "$f" "$TARGET_DIR/${BE_DIR}/.claude/agents/be-scans/${name}" \
        "profiles/${PROFILE}/scans/be-scans/${name}" "rules-scans"
    done
  fi

  # Frontend scan playbooks (not prefixed) — FE scope only
  if scope_includes_fe && [[ -d "$PROFILE_SCAFFOLD_DIR/scans/fe-scans" ]]; then
    mkdir -p "$TARGET_DIR/${FE_DIR}/.claude/agents/fe-scans"
    for f in "$PROFILE_SCAFFOLD_DIR/scans/fe-scans/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      copy_and_replace "$f" "$TARGET_DIR/${FE_DIR}/.claude/agents/fe-scans/${name}" \
        "profiles/${PROFILE}/scans/fe-scans/${name}" "rules-scans"
    done
  fi

  # Rules — filter by scope on filename prefix (be-*.json / fe-*.json)
  if [[ -d "$PROFILE_SCAFFOLD_DIR/rules" ]]; then
    for f in "$PROFILE_SCAFFOLD_DIR/rules/"*.json; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      if [[ "$name" == be-*.json ]] && ! scope_includes_be; then continue; fi
      if [[ "$name" == fe-*.json ]] && ! scope_includes_fe; then continue; fi
      copy_and_replace "$f" "$TARGET_DIR/.claude/rules/${name}" \
        "profiles/${PROFILE}/rules/${name}" "rules-scans"
    done
  fi

  # Append profile anti-patterns (with placeholder replacement)
  if [[ -f "$PROFILE_SCAFFOLD_DIR/anti-patterns-profile.md" ]]; then
    echo "" >> "$TARGET_DIR/.claude/anti-patterns.md"
    cat "$PROFILE_SCAFFOLD_DIR/anti-patterns-profile.md" >> "$TARGET_DIR/.claude/anti-patterns.md"
    for key in "${!PLACEHOLDERS[@]}"; do
      _token="__${key}__"
      _value="${PLACEHOLDERS[$key]}"
      _escaped=$(printf '%s' "$_value" | sed 's/[&/\]/\\&/g')
      sed -i "s|${_token}|${_escaped}|g" "$TARGET_DIR/.claude/anti-patterns.md"
    done
    echo "APPEND: .claude/anti-patterns.md (profile anti-patterns)"
  fi

  # Profile-specific commands (if any)
  if [[ -d "$PROFILE_SCAFFOLD_DIR/commands" ]]; then
    for f in "$PROFILE_SCAFFOLD_DIR/commands/"*.md; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      # Special case: openapi-sync requires SCOPE=fullstack (both FE and BE)
      if [[ "$name" == "openapi-sync.md" ]] && { [[ "$SCOPE" != "fullstack" ]] || [[ -z "$FE_DIR" ]] || [[ -z "$BE_DIR" ]]; }; then
        continue
      fi
      copy_and_replace "$f" "$TARGET_DIR/.claude/commands/${name}" \
        "profiles/${PROFILE}/commands/${name}" "commands"
    done
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
  "scope": "${SCOPE}",
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
