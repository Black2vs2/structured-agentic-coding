"""CLI entry point for sac-graph."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from sac_graph.graph import GraphStore
from sac_graph.indexer import Indexer, _log
from sac_graph.tools.find_symbol import find_symbol
from sac_graph.tools.module_summary import get_module_summary
from sac_graph.tools.dependencies import get_dependencies
from sac_graph.tools.dependents import get_dependents
from sac_graph.tools.blast_radius import get_blast_radius
from sac_graph.tools.test_coverage import get_test_coverage_map
from sac_graph.tools.changes_since import get_changes_since


def _get_root() -> str:
    return os.environ.get("SAC_PROJECT_ROOT", os.getcwd())


def _open_store(root: str) -> tuple[GraphStore, Indexer]:
    db_dir = Path(root) / ".code-graph"
    db_dir.mkdir(parents=True, exist_ok=True)
    store = GraphStore(db_dir / "graph.db")
    indexer = Indexer(store, root)
    return store, indexer


def _ensure_index(store: GraphStore, indexer: Indexer) -> None:
    """Run incremental index if DB exists, else warn."""
    last = store.get_meta("last_indexed_hash")
    if last:
        indexer.incremental_index()
    else:
        _log("No index found. Run: sac-graph index --full")


def _output(data) -> None:
    json.dump(data, sys.stdout, default=str)
    print()


def cmd_find_symbol(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = find_symbol(store, args.name, kind=args.kind, limit=args.limit)
    _output(result)


def cmd_module_summary(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = get_module_summary(store, args.path, depth=args.depth, max_tokens=args.max_tokens)
    _output(result)


def cmd_dependencies(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = get_dependencies(store, args.symbol)
    _output(result)


def cmd_dependents(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = get_dependents(store, args.symbol)
    _output(result)


def cmd_blast_radius(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = get_blast_radius(store, args.targets, max_depth=args.max_depth, project_root=root)
    _output(result)


def cmd_test_coverage(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = get_test_coverage_map(store, args.symbol)
    _output(result)


def cmd_changes_since(args):
    root = _get_root()
    store, indexer = _open_store(root)
    _ensure_index(store, indexer)
    result = get_changes_since(store, args.commit, project_root=root)
    _output(result)


def cmd_index(args):
    root = _get_root()
    store, indexer = _open_store(root)
    if args.full:
        stats = indexer.full_index(parallel=True)
    else:
        stats = indexer.ensure_index()
    _output(stats)


def cmd_rebuild(args):
    root = _get_root()
    db_dir = Path(root) / ".code-graph"
    for f in db_dir.glob("graph.db*"):
        f.unlink(missing_ok=True)
    db_dir.mkdir(parents=True, exist_ok=True)
    store = GraphStore(db_dir / "graph.db")
    indexer = Indexer(store, root)
    stats = indexer.full_index(parallel=False)
    _output({"status": "rebuilt", **stats})


def main():
    parser = argparse.ArgumentParser(prog="sac-graph", description="Code graph CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("find-symbol", help="Find symbols by name")
    p.add_argument("name")
    p.add_argument("--kind", choices=["function", "class", "type", "file", "test"])
    p.add_argument("--limit", type=int, default=10)
    p.set_defaults(func=cmd_find_symbol)

    p = sub.add_parser("module-summary", help="Directory overview")
    p.add_argument("path")
    p.add_argument("--depth", type=int, default=1)
    p.add_argument("--max-tokens", type=int, default=2000)
    p.set_defaults(func=cmd_module_summary)

    p = sub.add_parser("dependencies", help="What does a symbol depend on?")
    p.add_argument("symbol")
    p.set_defaults(func=cmd_dependencies)

    p = sub.add_parser("dependents", help="What depends on a symbol?")
    p.add_argument("symbol")
    p.set_defaults(func=cmd_dependents)

    p = sub.add_parser("blast-radius", help="Affected files, symbols, tests")
    p.add_argument("targets", nargs="+")
    p.add_argument("--max-depth", type=int, default=3)
    p.set_defaults(func=cmd_blast_radius)

    p = sub.add_parser("test-coverage", help="Tests covering a symbol")
    p.add_argument("symbol")
    p.set_defaults(func=cmd_test_coverage)

    p = sub.add_parser("changes-since", help="Symbol-level diffs since a commit")
    p.add_argument("commit")
    p.set_defaults(func=cmd_changes_since)

    p = sub.add_parser("index", help="Index or update the code graph")
    p.add_argument("--full", action="store_true", help="Force full re-index")
    p.set_defaults(func=cmd_index)

    p = sub.add_parser("rebuild", help="Delete and rebuild graph from scratch")
    p.set_defaults(func=cmd_rebuild)

    args = parser.parse_args()
    try:
        args.func(args)
    except Exception as e:
        json.dump({"error": str(e)}, sys.stderr)
        print(file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
