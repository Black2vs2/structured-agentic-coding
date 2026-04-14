"""find_symbol — ranked symbol search."""

from __future__ import annotations
from typing import Any
from sac_graph.graph import GraphStore


def _score(qname: str, query: str) -> int:
    name = qname.rsplit(".", 1)[-1].lower()
    q = query.lower()
    if name == q: return 100
    if name.endswith(q): return 80
    if name.startswith(q): return 60
    if q in name: return 40
    if q in qname.lower(): return 20
    return 0


def find_symbol(store: GraphStore, name: str, kind: str | None = None, limit: int = 10) -> list[dict[str, Any]]:
    raw = store.find_nodes(name, kind=kind)
    scored = [{**r, "score": _score(r["qualified_name"], name)} for r in raw]
    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored[:limit]
