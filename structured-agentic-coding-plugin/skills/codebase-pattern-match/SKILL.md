---
name: codebase-pattern-match
description: Extract how THIS codebase already solves similar problems — Locator, Analyzer, and Pattern-Finder subagents dispatched in parallel produce a structured report of file locations, worked exemplars, conventions, and extension hooks. Pairs with deep-research so external evidence is adapted to local patterns, not blindly copy-pasted. Use when the user says how does our repo handle X, show me existing patterns, find similar code, match existing conventions, or what does this codebase already do for Y.
---

# Codebase Pattern Match

Extract structural patterns from the current repository: where things live, how they actually work, what conventions must be respected. Runs inline in the main conversation; dispatches three parallel leaf subagents for specialized extraction.

Announce at start: "Running codebase-pattern-match on: `{topic}`."

## Procedure

### Step 1: Parse Topic

Args: a feature description or tech area (e.g., "OAuth authentication", "background jobs", "client-side state management").

Output path: `docs/research/{topic-slug}.patterns.md` (same slug convention as `structured-agentic-coding:deep-research` so companion reports live together).

### Step 2: Dispatch Three Subagent Leaves (Parallel)

Single message, three `Agent` tool calls concurrently. Each has a distinct role and a strict output contract. Each has a wall-clock cap of **3 minutes** — if exceeded, collect partial output and move on.

**Leaf 1 — Locator.** Goal: map WHERE the topic's code lives. Depth-1 scan only — no deep reads.

Prompt includes:
- The topic
- Instruction to use Glob/Grep heavily; read only first lines of files
- Use graph MCP tools (`mcp__code-graph__*`) if available to shortcut file discovery
- Output contract:
```markdown
## Files
- `path/to/file.ts` — {1-line summary of role}
## Directories
- `path/to/dir/` — {what kind of thing lives here}
## Entry points
- `{file}:{symbol}` — {how it's called / exposed}
```

**Leaf 2 — Analyzer.** Goal: read 2–3 exemplary files end-to-end, extract the real mechanics (flow, dependencies, error handling, testing).

Prompt includes:
- The topic
- Instruction to choose the 2–3 MOST REPRESENTATIVE files (use its own Glob or the Locator's output if available from a prior run)
- Use `ast-grep` or tree-sitter MCP if available; fall back to full Read
- Output contract:
```markdown
## Exemplar: `path/to/file.ts`
**What it does:** ...
**Flow:** step 1 → step 2 → step 3 (with line refs)
**Dependencies:** external libs + internal modules
**Error handling:** how errors surface, where they're caught, what gets logged/reported
**Testing:** test file path, testing style
**Notable details:** non-obvious invariants, assumptions, gotchas
```
Repeat for 2–3 exemplars.

**Leaf 3 — Pattern-Finder.** Goal: extract CONVENTIONS (style, structure, naming) — not individual file mechanics.

Prompt includes:
- The topic
- Instruction to scan 5–10 files quickly (Glob + Read of first 30 lines each)
- Use `ast-grep` for structural patterns if available
- Output contract:
```markdown
## Naming
- Files: `{pattern}` (e.g., `*.controller.ts`, `*-use-case.ts`)
- Types: `{pattern}`
- Functions: `{pattern}`
## Directory layout
- `{module-name}/` typically contains: {subfiles/subdirs}
## Imports
- Internal: {alias style, relative vs absolute}
- External: {preferred libs for common tasks}
## Testing
- Co-located vs separate, framework, naming, mocking style
## Error handling
- Custom error classes? Result<T,E>? Exceptions? Sentinel values?
## Logging / Observability
- Which logger, log levels used, structured vs plain
```

### Step 3: Cross-Check for Gaps

Main chat reads all three outputs. Verify:
- Did Locator and Analyzer point to the same files, or is there disagreement on what counts as "the pattern"?
- Did Pattern-Finder's conventions match what Analyzer saw in the exemplars? If they diverge, **Analyzer's observed exemplars are ground truth** — flag the divergence.
- Are there named anti-patterns in `.claude/anti-patterns.md` relevant to this topic? Include them in the report.

### Step 4: Synthesize and Write Report

Write `docs/research/{topic-slug}.patterns.md`:

```markdown
# Codebase Patterns: {topic}

**Generated:** {ISO timestamp}

## Map
{Locator's Files + Directories + Entry points, lightly edited for readability}

## Worked Exemplars
{Analyzer's full output — this is the meat of the report}

## Conventions
{Pattern-Finder's output}

## Anti-patterns to Avoid
{From .claude/anti-patterns.md if relevant, plus anything the agents flagged}

## Extension Hooks
{Main chat's synthesis — where would new code for {topic} naturally plug in? List 2–3 specific integration points with file:line refs and a 1-sentence "what to do here" for each.}

## Ready-to-Use References
{A bulleted list of the specific files/lines that new code should model itself after. One sentence each.}
```

### Step 5: Report

Tell the user:
- Report path
- N exemplars analyzed, M extension hooks identified
- Any gaps or divergences flagged

Suggest next step: "Pair with `structured-agentic-coding:deep-research` output via `structured-agentic-coding:feature-exploration` for a full researched proposal."

## Budget Safeguards

- 3 parallel leaves × 3 min wall-clock each = bounded total time
- If Locator returns 0 files → STOP. The topic doesn't map to this codebase. Report to the user; do not waste further tokens on Analyzer / Pattern-Finder.
- If exemplars diverge wildly (different architectures in the same repo for the same concern) → include ALL variants in the report, not just one. That divergence is useful signal.

## Integration

- Pairs with `structured-agentic-coding:deep-research` — external evidence is the question, local patterns are the constraint. `structured-agentic-coding:feature-exploration` orchestrates both.
- Complements the existing `research` agent (exploratory, free-form) and `impact-analyst` agent (impact of a proposed change). This skill is the **constraint-extractor for NEW work**.
