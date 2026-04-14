"""get_blast_radius — BFS dependents + config grep."""
from __future__ import annotations
import subprocess
from collections import deque
from typing import Any
from sac_graph.graph import GraphStore

_CONFIG_GLOBS = ("*.json", "*.yaml", "*.yml", "*.xml", "*.csproj", "*.toml")

def _grep_configs(project_root: str, names: list[str]) -> list[dict]:
    refs, seen = [], set()
    for name in names:
        short = name.rsplit(".", 1)[-1]
        if len(short) < 3: continue
        for ext in _CONFIG_GLOBS:
            try:
                r = subprocess.run(["grep", "-rl", short, "--include", ext, "."],
                                   cwd=project_root, capture_output=True, text=True, timeout=5)
                for line in r.stdout.strip().split("\n"):
                    line = line.strip()
                    if line and (line, short) not in seen:
                        seen.add((line, short))
                        refs.append({"file": line, "symbol": short, "confidence": "low"})
            except Exception: continue
    return refs

def get_blast_radius(store: GraphStore, targets: list[str], max_depth: int = 3,
                     project_root: str = ".") -> dict[str, Any]:
    G = store.build_networkx_graph()
    visited: set[str] = set()
    affected_symbols, affected_tests = [], []
    affected_files: set[str] = set()
    queue: deque[tuple[str, int]] = deque()
    for t in targets:
        if t in G:
            queue.append((t, 0)); visited.add(t)
    while queue:
        node, depth = queue.popleft()
        if depth > max_depth: continue
        data = G.nodes.get(node, {})
        fp, kind = data.get("file_path", ""), data.get("kind", "")
        if depth > 0:
            entry = {"qualified_name": node, "file_path": fp, "depth": depth}
            (affected_tests if kind == "test" else affected_symbols).append(entry)
            if fp: affected_files.add(fp)
        for pred in G.predecessors(node):
            if pred not in visited:
                visited.add(pred); queue.append((pred, depth + 1))
    config_refs = _grep_configs(project_root, targets)
    return {"affected_symbols": affected_symbols, "affected_files": sorted(affected_files),
            "affected_tests": affected_tests, "config_references": config_refs}
