#!/usr/bin/env bash
# smoke-test.sh — Scaffold smoke tests with baseline diff
#
# Verifies that scaffold.sh produces deterministic, byte-identical output for
# known scenarios. Run after any change to scaffold.sh, scaffold templates, or
# profiles to confirm no regression.
#
# Usage:
#   bash smoke-test.sh             # check mode — diff output against committed baselines
#   bash smoke-test.sh --regen     # regen mode — overwrite baselines with current output
#
# Normalizations (non-deterministic fields):
#   - .claude/scaffold-manifest.json: scaffoldedAt → "<NORMALIZED_TIMESTAMP>"
#   - .claude/scaffold-manifest.json: placeholders.PLUGIN_DIR → "<NORMALIZED_PLUGIN_DIR>"
#   - any file containing the absolute PLUGIN_DIR path → replaced with "<NORMALIZED_PLUGIN_DIR>"
#
# Requirements:
#   - Bash 4+ (macOS users: brew install bash)
#   - GNU sed (macOS users: brew install gnu-sed and add to PATH)
#   - jq (manifest normalization)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCAFFOLD_DIR="$PLUGIN_DIR/.claude/scaffold"
SCAFFOLD_SCRIPT="$PLUGIN_DIR/scripts/scaffold.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
BASELINES_DIR="$SCRIPT_DIR/baselines"

MODE="${1:-check}"

# --- Environment checks ---
if [[ "${BASH_VERSINFO:-0}" -lt 4 ]]; then
  echo "ERROR: Bash 4+ required (have $BASH_VERSION). On macOS: brew install bash." >&2
  exit 1
fi
if ! sed --version >/dev/null 2>&1; then
  echo "ERROR: GNU sed required. On macOS: brew install gnu-sed and add gnubin to PATH." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required for manifest normalization." >&2
  exit 1
fi

# --- Helpers ---

normalize_output() {
  local target_dir="$1"
  local plugin_dir="$2"

  # Normalize manifest (scaffoldedAt + placeholders.PLUGIN_DIR)
  local manifest="$target_dir/.claude/scaffold-manifest.json"
  if [[ -f "$manifest" ]]; then
    jq '
      .scaffoldedAt = "<NORMALIZED_TIMESTAMP>"
      | .placeholders.PLUGIN_DIR = "<NORMALIZED_PLUGIN_DIR>"
    ' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  fi

  # Normalize any other file containing the absolute PLUGIN_DIR path
  if [[ -d "$target_dir/.claude" ]]; then
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      sed "s|$plugin_dir|<NORMALIZED_PLUGIN_DIR>|g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    done < <(grep -rl "$plugin_dir" "$target_dir/.claude" 2>/dev/null || true)
  fi
}

run_scenario() {
  local name="$1"
  local profile="$2"
  shift 2

  echo ""
  echo "→ $name (profile=$profile)"

  local tmpdir
  tmpdir=$(mktemp -d -t smoke-test-XXXXXX)

  # Seed from fixture
  if [[ -d "$FIXTURES_DIR/$name" ]]; then
    cp -R "$FIXTURES_DIR/$name/." "$tmpdir/"
  fi

  # Run scaffold (suppress verbose output)
  if ! bash "$SCAFFOLD_SCRIPT" "$SCAFFOLD_DIR" "$tmpdir" "$profile" "$@" >/dev/null 2>&1; then
    echo "  [ERROR] scaffold.sh failed. Re-run manually for diagnostics:"
    echo "    bash $SCAFFOLD_SCRIPT $SCAFFOLD_DIR $tmpdir $profile $*"
    rm -rf "$tmpdir"
    return 1
  fi

  normalize_output "$tmpdir" "$PLUGIN_DIR"

  local baseline="$BASELINES_DIR/$name.snapshot"

  if [[ "$MODE" == "--regen" ]]; then
    rm -rf "$baseline"
    mkdir -p "$BASELINES_DIR"
    cp -R "$tmpdir" "$baseline"
    echo "  [REGEN] baseline written"
    rm -rf "$tmpdir"
    return 0
  fi

  if [[ ! -d "$baseline" ]]; then
    echo "  [FAIL] no baseline. Run with --regen to create."
    rm -rf "$tmpdir"
    return 1
  fi

  local diff_out
  diff_out=$(diff -r "$baseline" "$tmpdir" 2>&1 || true)
  if [[ -z "$diff_out" ]]; then
    echo "  [PASS]"
    rm -rf "$tmpdir"
    return 0
  fi

  echo "  [FAIL] diff detected:"
  echo "$diff_out" | head -50
  rm -rf "$tmpdir"
  return 1
}

# --- Run scenarios ---

echo "=== Smoke tests ==="
echo "Mode:          $MODE"
echo "Plugin dir:    $PLUGIN_DIR"
echo "Baselines dir: $BASELINES_DIR"

run_scenario "base-fullstack" "base" \
  PREFIX=testbase \
  PROJECT_NAME="Test Base" \
  PROJECT_DESC="Test base project for smoke testing" \
  FE_DIR=frontend \
  BE_DIR=backend \
  FE_SERVE="npm run dev" \
  FE_BUILD="npm run build" \
  FE_TEST="npm run test" \
  FE_FORMAT="npm run format" \
  FE_LINT="npm run lint" \
  BE_BUILD="echo build" \
  BE_TEST="echo test" \
  BE_RUN="echo run" \
  BE_FORMAT="echo format" \
  DB_START="echo db" \
  MIGRATION="echo mig" \
  E2E_CMD="echo e2e"

run_scenario "angular-dotnet-fullstack" "angular-dotnet" \
  PREFIX=testad \
  PROJECT_NAME="Test Angular Dotnet" \
  PROJECT_DESC="Test angular-dotnet project for smoke testing" \
  FE_DIR=frontend \
  BE_DIR=backend \
  FE_SERVE="cd frontend && npx nx serve app" \
  FE_BUILD="cd frontend && npm run build" \
  FE_TEST="cd frontend && npm run test" \
  FE_FORMAT="cd frontend && npx prettier --write ." \
  FE_LINT="cd frontend && npx nx lint" \
  BE_BUILD="dotnet build backend/App.sln" \
  BE_TEST="dotnet test backend/App.sln" \
  BE_RUN="dotnet run --project backend/src/App.Api" \
  BE_FORMAT="dotnet csharpier backend/" \
  DB_START="docker compose -f docker/docker-compose.yml up -d" \
  MIGRATION="dotnet ef migrations add Mig --project backend/src/App.Migrations --startup-project backend/src/App.Api" \
  BE_SLN="backend/App.sln" \
  BE_API_PROJECT="backend/src/App.Api" \
  BE_NAMESPACE="App" \
  E2E_CMD="cd frontend && npx playwright test"

run_scenario "nestjs-query-be" "nestjs-query-be" \
  PREFIX=testnqbe \
  PROJECT_NAME="Test NestJS Query BE" \
  PROJECT_DESC="Test nestjs-query-be project for smoke testing" \
  SCOPE=be \
  BE_DIR=. \
  BE_RUNTIME=bun \
  BE_BUILD="bun run build" \
  BE_RUN="bun run start:dev" \
  BE_TEST="bun run test" \
  BE_TEST_E2E="bun run test:e2e" \
  BE_FORMAT="bun run format" \
  BE_LINT="bun run lint:fix" \
  MIGRATION_RUN="bun run migration:run" \
  MIGRATION_GENERATE="bun run migration:generate <Name>" \
  MIGRATION_REVERT="bun run migration:revert" \
  DB_MANAGED=true \
  FIREBASE_EMULATOR="bun run firebase:emulator:start" \
  GRAPHQL_SCHEMA_OUT="src/schema.gql"

echo ""
echo "=== All scenarios complete ==="
