# Rebuild Graph

Force a full re-index of the code graph. Deletes the existing `.code-graph/` database and rebuilds from scratch.

Use this when:
- The graph seems corrupted or returning wrong results
- You want a clean slate after major refactoring
- First-time setup of the graph on a project

## Execution

```bash
sac-graph rebuild
```

If the `sac-graph` command is not available, fall back to manual deletion:
```bash
rm -rf .code-graph/
sac-graph index --full
```

## After Rebuild

If you also added or removed agent files, run the AGENTS.md regeneration separately:
```bash
bash .claude/scripts/regenerate-agents-md.sh
```
