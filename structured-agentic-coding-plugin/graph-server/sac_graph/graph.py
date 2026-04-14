"""SQLite graph storage with NetworkX in-memory cache."""

from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any

import networkx as nx

_SCHEMA = """
CREATE TABLE IF NOT EXISTS nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    qualified_name TEXT NOT NULL UNIQUE,
    file_path TEXT NOT NULL,
    line_start INTEGER NOT NULL,
    line_end INTEGER NOT NULL,
    language TEXT NOT NULL,
    params TEXT,
    return_type TEXT
);
CREATE TABLE IF NOT EXISTS edges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    source TEXT NOT NULL,
    target TEXT NOT NULL,
    UNIQUE(kind, source, target)
);
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
);
CREATE INDEX IF NOT EXISTS idx_nodes_file ON nodes(file_path);
CREATE INDEX IF NOT EXISTS idx_nodes_kind ON nodes(kind);
CREATE INDEX IF NOT EXISTS idx_nodes_qname ON nodes(qualified_name);
CREATE INDEX IF NOT EXISTS idx_edges_source ON edges(source);
CREATE INDEX IF NOT EXISTS idx_edges_target ON edges(target);
"""


class GraphStore:
    """Persistent graph storage backed by SQLite."""

    def __init__(self, db_path: str | Path) -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.executescript(_SCHEMA)
        self._nx: nx.DiGraph | None = None

    def execute(self, sql: str, params: tuple = ()) -> sqlite3.Cursor:
        return self._conn.execute(sql, params)

    def _invalidate_cache(self) -> None:
        self._nx = None

    def upsert_node(self, *, kind: str, qualified_name: str, file_path: str,
                    line_start: int, line_end: int, language: str,
                    params: str | None = None, return_type: str | None = None) -> None:
        self._conn.execute(
            """INSERT INTO nodes (kind, qualified_name, file_path, line_start, line_end, language, params, return_type)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(qualified_name) DO UPDATE SET
                 kind=excluded.kind, file_path=excluded.file_path,
                 line_start=excluded.line_start, line_end=excluded.line_end,
                 language=excluded.language, params=excluded.params, return_type=excluded.return_type""",
            (kind, qualified_name, file_path, line_start, line_end, language, params, return_type),
        )
        self._conn.commit()
        self._invalidate_cache()

    def add_edge(self, kind: str, source: str, target: str) -> None:
        self._conn.execute(
            "INSERT OR IGNORE INTO edges (kind, source, target) VALUES (?, ?, ?)",
            (kind, source, target),
        )
        self._conn.commit()
        self._invalidate_cache()

    def delete_file(self, file_path: str) -> None:
        names = [r[0] for r in self._conn.execute(
            "SELECT qualified_name FROM nodes WHERE file_path=?", (file_path,)
        ).fetchall()]
        if names:
            ph = ",".join("?" * len(names))
            self._conn.execute(f"DELETE FROM edges WHERE source IN ({ph}) OR target IN ({ph})", names + names)
            self._conn.execute("DELETE FROM nodes WHERE file_path=?", (file_path,))
            self._conn.commit()
            self._invalidate_cache()

    def find_nodes(self, name: str, kind: str | None = None) -> list[dict[str, Any]]:
        sql = "SELECT kind, qualified_name, file_path, line_start, line_end, language, params, return_type FROM nodes WHERE qualified_name LIKE ?"
        params: list[Any] = [f"%{name}%"]
        if kind:
            sql += " AND kind=?"
            params.append(kind)
        return [dict(zip(("kind", "qualified_name", "file_path", "line_start", "line_end", "language", "params", "return_type"), r))
                for r in self._conn.execute(sql, params).fetchall()]

    def get_nodes_in_directory(self, path_prefix: str) -> list[dict[str, Any]]:
        rows = self._conn.execute(
            "SELECT kind, qualified_name, file_path, line_start, line_end, language, params, return_type FROM nodes WHERE file_path LIKE ?",
            (f"{path_prefix}%",),
        ).fetchall()
        return [dict(zip(("kind", "qualified_name", "file_path", "line_start", "line_end", "language", "params", "return_type"), r)) for r in rows]

    def get_edges_from(self, qualified_name: str) -> list[dict[str, str]]:
        return [{"kind": r[0], "target": r[1]} for r in
                self._conn.execute("SELECT kind, target FROM edges WHERE source=?", (qualified_name,)).fetchall()]

    def get_edges_to(self, qualified_name: str) -> list[dict[str, str]]:
        return [{"kind": r[0], "source": r[1]} for r in
                self._conn.execute("SELECT kind, source FROM edges WHERE target=?", (qualified_name,)).fetchall()]

    def get_meta(self, key: str) -> str | None:
        row = self._conn.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return row[0] if row else None

    def set_meta(self, key: str, value: str) -> None:
        self._conn.execute(
            "INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, value),
        )
        self._conn.commit()

    def build_networkx_graph(self) -> nx.DiGraph:
        if self._nx is not None:
            return self._nx
        G = nx.DiGraph()
        for r in self._conn.execute("SELECT qualified_name, kind, file_path FROM nodes").fetchall():
            G.add_node(r[0], kind=r[1], file_path=r[2])
        for r in self._conn.execute("SELECT source, target, kind FROM edges").fetchall():
            G.add_edge(r[0], r[1], kind=r[2])
        self._nx = G
        return G

    def node_count(self) -> int:
        return self._conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0]

    def close(self) -> None:
        self._conn.close()
