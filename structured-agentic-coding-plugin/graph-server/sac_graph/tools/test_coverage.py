"""get_test_coverage_map — find tests covering a symbol via TESTED_BY edges."""
from __future__ import annotations
from typing import Any
from sac_graph.graph import GraphStore

def get_test_coverage_map(store: GraphStore, symbol: str) -> list[dict[str, Any]]:
    edges = store.get_edges_from(symbol)
    tests = []
    for e in edges:
        if e["kind"] == "TESTED_BY":
            targets = store.find_nodes(e["target"])
            if targets: tests.append({**targets[0], "confidence": "name-based"})
            else: tests.append({"kind": "test", "qualified_name": e["target"],
                                "file_path": "unknown", "confidence": "name-based"})
    return tests
