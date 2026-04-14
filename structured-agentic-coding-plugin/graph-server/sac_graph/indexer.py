"""Full and incremental code indexing with parallel parsing."""

from __future__ import annotations

import os
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from sac_graph.graph import GraphStore
from sac_graph.languages import detect_language
from sac_graph.parser import parse_file

_SKIP_EXTENSIONS = {
    ".md", ".txt", ".json", ".yml", ".yaml", ".env", ".lock", ".log",
    ".svg", ".png", ".jpg", ".jpeg", ".gif", ".ico", ".woff", ".woff2",
    ".ttf", ".eot", ".css", ".scss", ".less", ".html", ".xml",
    ".map", ".min.js", ".min.css",
}


def _log(msg: str) -> None:
    """Log progress to stderr."""
    print(f"[sac-graph] {msg}", file=sys.stderr, flush=True)


def _parse_one(args: tuple[str, str, str]) -> dict[str, Any]:
    """Parse a single file (picklable for ProcessPoolExecutor)."""
    abs_path, rel_path, language = args
    try:
        return parse_file(abs_path, rel_path, language)
    except Exception:
        return {"nodes": [], "edges": []}


class Indexer:
    def __init__(self, store: GraphStore, project_root: str) -> None:
        self.store = store
        self.root = Path(project_root)

    def full_index(self, parallel: bool = False) -> dict[str, Any]:
        files = self._discover()
        _log(f"Full index: {len(files)} source files found")
        start = time.time()
        self._index_files(files, parallel=parallel)
        elapsed = time.time() - start
        self._save_hash()
        _log(f"Full index complete: {len(files)} files, {self.store.node_count()} nodes, {elapsed:.1f}s")
        return {"files_indexed": len(files), "mode": "full", "nodes": self.store.node_count(), "seconds": round(elapsed, 1)}

    def incremental_index(self) -> dict[str, Any]:
        last = self.store.get_meta("last_indexed_hash")
        if not last:
            return self.full_index()
        current = self._git_hash()
        if current == last:
            return {"files_indexed": 0, "mode": "incremental", "reason": "up_to_date"}

        changed = self._changed_files(last, current)
        _log(f"Incremental index: {len(changed)} changed files")
        indexed = 0
        for rel in changed:
            lang = detect_language(rel)
            self.store.delete_file(rel)
            full = self.root / rel
            if full.exists() and lang:
                result = _parse_one((str(full), rel, lang))
                self._store_result(result, rel)
                indexed += 1

        self._save_hash()
        _log(f"Incremental index complete: {indexed} files re-indexed")
        return {"files_indexed": indexed, "mode": "incremental"}

    def ensure_index(self) -> dict[str, Any]:
        """Ensure index is current. Uses sequential parsing."""
        last = self.store.get_meta("last_indexed_hash")
        if not last:
            return self.full_index(parallel=False)
        current = self._git_hash()
        if current == last:
            return {"files_indexed": 0, "mode": "current"}
        return self.incremental_index()

    def _index_files(self, files: list[tuple[str, str, str]], parallel: bool = True) -> None:
        if not files:
            return
        total = len(files)
        done = 0
        report_every = max(total // 10, 1)  # report every ~10%

        max_workers = min(os.cpu_count() or 1, 8)
        if parallel and total > 10 and max_workers > 1:
            _log(f"Parsing with {max_workers} workers...")
            with ProcessPoolExecutor(max_workers=max_workers) as pool:
                futures = {pool.submit(_parse_one, f): f for f in files}
                for future in as_completed(futures):
                    _, rel, _ = futures[future]
                    try:
                        result = future.result()
                        self._store_result(result, rel)
                    except Exception:
                        pass
                    done += 1
                    if done % report_every == 0:
                        _log(f"  {done}/{total} files indexed ({done * 100 // total}%)")
        else:
            for abs_path, rel, lang in files:
                result = _parse_one((abs_path, rel, lang))
                self._store_result(result, rel)
                done += 1
                if done % report_every == 0:
                    _log(f"  {done}/{total} files indexed ({done * 100 // total}%)")

    def _store_result(self, result: dict, rel_path: str) -> None:
        for node in result.get("nodes", []):
            self.store.upsert_node(
                kind=node["kind"], qualified_name=node["qualified_name"],
                file_path=rel_path if node["kind"] != "file" else node["file_path"],
                line_start=node["line_start"], line_end=node["line_end"],
                language=node["language"], params=node.get("params"),
                return_type=node.get("return_type"),
            )
        for edge in result.get("edges", []):
            self.store.add_edge(edge["kind"], edge["source"], edge["target"])

    def _discover(self) -> list[tuple[str, str, str]]:
        """Discover source files using git ls-files (respects .gitignore)."""
        # Use git to list tracked files — automatically respects .gitignore
        r = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
            cwd=self.root, capture_output=True, text=True,
        )
        files = []
        if r.returncode == 0:
            for line in r.stdout.strip().split("\n"):
                rel = line.strip()
                if not rel:
                    continue
                if Path(rel).suffix.lower() in _SKIP_EXTENSIONS:
                    continue
                lang = detect_language(rel)
                if lang:
                    abs_path = str(self.root / rel)
                    if os.path.isfile(abs_path):
                        files.append((abs_path, rel, lang))
        else:
            # Fallback to rglob if not a git repo
            _log("Not a git repo — falling back to filesystem scan")
            for f in self.root.rglob("*"):
                if not f.is_file():
                    continue
                rel = f.relative_to(self.root)
                if f.suffix.lower() in _SKIP_EXTENSIONS:
                    continue
                lang = detect_language(str(f))
                if lang:
                    files.append((str(f), str(rel).replace("\\", "/"), lang))
        return files

    def _git_hash(self) -> str:
        r = subprocess.run(["git", "rev-parse", "HEAD"], cwd=self.root,
                           capture_output=True, text=True)
        return r.stdout.strip()

    def _changed_files(self, old: str, new: str) -> list[str]:
        r = subprocess.run(["git", "diff", "--name-only", f"{old}..{new}"],
                           cwd=self.root, capture_output=True, text=True)
        return [l.strip() for l in r.stdout.strip().split("\n") if l.strip()]

    def _save_hash(self) -> None:
        self.store.set_meta("last_indexed_hash", self._git_hash())
        self.store.set_meta("index_timestamp", datetime.now(timezone.utc).isoformat())
