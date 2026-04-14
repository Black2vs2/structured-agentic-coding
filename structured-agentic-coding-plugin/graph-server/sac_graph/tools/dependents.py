"""get_dependents — incoming edges to a symbol."""
from __future__ import annotations
from typing import Any
from sac_graph.graph import GraphStore

def get_dependents(store: GraphStore, symbol: str) -> list[dict[str, Any]]:
    edges = store.get_edges_to(symbol)
    result = []
    for e in edges:
        sources = store.find_nodes(e["source"])
        info = sources[0] if sources else {"file_path": "unknown", "line_start": 0}
        result.append({"kind": e["kind"], "source": e["source"],
                        "file_path": info.get("file_path", "unknown"),
                        "line_start": info.get("line_start", 0)})
    return result
