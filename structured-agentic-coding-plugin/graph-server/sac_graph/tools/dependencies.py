"""get_dependencies — outgoing edges from a symbol."""
from __future__ import annotations
from typing import Any
from sac_graph.graph import GraphStore

def get_dependencies(store: GraphStore, symbol: str) -> list[dict[str, Any]]:
    edges = store.get_edges_from(symbol)
    result = []
    for e in edges:
        targets = store.find_nodes(e["target"])
        info = targets[0] if targets else {"file_path": "unknown", "line_start": 0}
        result.append({"kind": e["kind"], "target": e["target"],
                        "file_path": info.get("file_path", "unknown"),
                        "line_start": info.get("line_start", 0)})
    return result
