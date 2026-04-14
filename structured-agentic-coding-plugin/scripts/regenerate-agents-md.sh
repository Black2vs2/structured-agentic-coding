#!/usr/bin/env bash
# Regenerate .claude/AGENTS.md from filesystem.
# Scans agent directories, reads title + description, writes manifest.
set -euo pipefail

AGENTS_FILE=".claude/AGENTS.md"

# Find all agent .md files
FOUND=()
while IFS= read -r f; do
    [[ -f "$f" ]] && FOUND+=("$f")
done < <(find .claude/agents -name "*.md" 2>/dev/null | sort)

# Also check BE/FE agent directories
for dir in $(find . -path "*/.claude/agents" -not -path "./.claude/agents" 2>/dev/null); do
    while IFS= read -r f; do
        [[ -f "$f" ]] && FOUND+=("$f")
    done < <(find "$dir" -name "*.md" 2>/dev/null | sort)
done

if [[ ${#FOUND[@]} -eq 0 ]]; then
    echo "No agent files found."
    exit 0
fi

# Generate manifest
{
    echo "# Agent Manifest"
    echo ""
    echo "> **Auto-generated.** Run \`bash .claude/scripts/regenerate-agents-md.sh\` to update."
    echo ""

    current_group=""
    for f in "${FOUND[@]}"; do
        rel="${f#./}"
        group=$(dirname "$rel")

        if [[ "$group" != "$current_group" ]]; then
            current_group="$group"
            echo ""
            echo "## $group"
            echo ""
            echo "| Agent | File | Role |"
            echo "|-------|------|------|"
        fi

        # Read title: skip YAML frontmatter, find first # heading
        title=""
        desc=""
        in_frontmatter=false
        while IFS= read -r line; do
            if [[ "$line" == "---" ]]; then
                if $in_frontmatter; then
                    in_frontmatter=false
                    continue
                else
                    in_frontmatter=true
                    continue
                fi
            fi
            $in_frontmatter && continue
            if [[ -z "$title" && "$line" == \#* ]]; then
                title="${line#\# }"
                continue
            fi
            if [[ -n "$title" && -z "$desc" && -n "$line" ]]; then
                desc="$line"
                break
            fi
        done < "$f"

        [[ -z "$title" ]] && title=$(basename "$f" .md)
        echo "| $title | \`$rel\` | $desc |"
    done
} > "$AGENTS_FILE"

count=${#FOUND[@]}
echo "AGENTS.md updated: $count agents found."
