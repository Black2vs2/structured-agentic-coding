"""get_module_summary — progressive disclosure via depth + max_tokens."""

from __future__ import annotations
import json
from typing import Any
from sac_graph.graph import GraphStore


def get_module_summary(store: GraphStore, path: str, depth: int = 1, max_tokens: int = 2000) -> dict[str, Any]:
    nodes = store.get_nodes_in_directory(path)
    grouped: dict[str, list] = {"files": [], "classes": [], "functions": [], "tests": []}
    for n in nodes:
        key = {"file": "files", "class": "classes", "function": "functions", "test": "tests"}.get(n["kind"], "functions")
        grouped[key].append(n)

    counts = {k: len(v) for k, v in grouped.items()}

    if depth == 1:
        result = {
            "path": path, "counts": counts,
            "classes": [n["qualified_name"].rsplit(".", 1)[-1] for n in grouped["classes"]],
            "functions": [n["qualified_name"].rsplit(".", 1)[-1] for n in grouped["functions"]],
            "tests": [n["qualified_name"].rsplit(".", 1)[-1] for n in grouped["tests"]],
            "files": [n["file_path"] for n in grouped["files"]],
        }
    elif depth == 2:
        result = {
            "path": path, "counts": counts,
            "classes": [{"name": n["qualified_name"], "file": n["file_path"], "lines": f"{n['line_start']}-{n['line_end']}"} for n in grouped["classes"]],
            "functions": [{"name": n["qualified_name"], "file": n["file_path"], "lines": f"{n['line_start']}-{n['line_end']}"} for n in grouped["functions"]],
            "tests": [{"name": n["qualified_name"], "file": n["file_path"]} for n in grouped["tests"]],
            "files": [n["file_path"] for n in grouped["files"]],
        }
    else:
        result = {"path": path, "counts": counts}
        for key in ("classes", "functions", "tests", "files"):
            result[key] = []
            for n in grouped[key]:
                entry = dict(n)
                entry["dependency_count"] = len(store.get_edges_from(n["qualified_name"]))
                entry["dependent_count"] = len(store.get_edges_to(n["qualified_name"]))
                result[key].append(entry)

    serialized = json.dumps(result)
    if len(serialized) > max_tokens * 4:
        result["truncated"] = True
        result["message"] = f"Response truncated. {counts['classes']} classes, {counts['functions']} functions, {counts['tests']} tests total."
        for key in ("classes", "functions", "tests", "files"):
            if isinstance(result.get(key), list) and len(result[key]) > 20:
                result[key] = result[key][:20]
                result[f"{key}_truncated"] = counts.get(key, 0) - 20

    return result
