import pytest
from sac_graph.graph import GraphStore


class TestSchema:
    def test_tables_exist(self, graph_store):
        tables = graph_store.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        ).fetchall()
        names = [t[0] for t in tables]
        assert "nodes" in names
        assert "edges" in names
        assert "meta" in names


class TestNodes:
    def test_upsert_node(self, graph_store):
        graph_store.upsert_node(
            kind="function", qualified_name="mod.foo", file_path="mod.py",
            line_start=1, line_end=5, language="python",
        )
        rows = graph_store.find_nodes("foo")
        assert len(rows) == 1
        assert rows[0]["qualified_name"] == "mod.foo"

    def test_upsert_updates_existing(self, graph_store):
        graph_store.upsert_node(
            kind="function", qualified_name="mod.foo", file_path="mod.py",
            line_start=1, line_end=5, language="python",
        )
        graph_store.upsert_node(
            kind="function", qualified_name="mod.foo", file_path="mod.py",
            line_start=1, line_end=10, language="python",
        )
        rows = graph_store.find_nodes("foo")
        assert len(rows) == 1
        assert rows[0]["line_end"] == 10

    def test_find_by_kind(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="mod.foo",
            file_path="mod.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="class", qualified_name="mod.Foo",
            file_path="mod.py", line_start=10, line_end=50, language="python")
        assert len(graph_store.find_nodes("foo", kind="function")) == 1
        assert len(graph_store.find_nodes("Foo", kind="class")) == 1

    def test_get_nodes_in_directory(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="src.utils.helper",
            file_path="src/utils.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="function", qualified_name="lib.other",
            file_path="lib/other.py", line_start=1, line_end=5, language="python")
        assert len(graph_store.get_nodes_in_directory("src/")) == 1

    def test_delete_file(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="mod.foo",
            file_path="mod.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="function", qualified_name="other.bar",
            file_path="other.py", line_start=1, line_end=5, language="python")
        graph_store.add_edge("CALLS", "mod.foo", "other.bar")
        graph_store.delete_file("mod.py")
        assert len(graph_store.find_nodes("foo")) == 0
        assert len(graph_store.get_edges_from("mod.foo")) == 0
        assert len(graph_store.find_nodes("bar")) == 1


class TestEdges:
    def test_add_edge(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="a.foo",
            file_path="a.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="function", qualified_name="b.bar",
            file_path="b.py", line_start=1, line_end=5, language="python")
        graph_store.add_edge("CALLS", "a.foo", "b.bar")
        edges = graph_store.get_edges_from("a.foo")
        assert len(edges) == 1
        assert edges[0]["kind"] == "CALLS"
        assert edges[0]["target"] == "b.bar"

    def test_get_edges_to(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="a.foo",
            file_path="a.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="function", qualified_name="b.bar",
            file_path="b.py", line_start=1, line_end=5, language="python")
        graph_store.add_edge("CALLS", "a.foo", "b.bar")
        edges = graph_store.get_edges_to("b.bar")
        assert len(edges) == 1
        assert edges[0]["source"] == "a.foo"

    def test_duplicate_edge_ignored(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="a.foo",
            file_path="a.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="function", qualified_name="b.bar",
            file_path="b.py", line_start=1, line_end=5, language="python")
        graph_store.add_edge("CALLS", "a.foo", "b.bar")
        graph_store.add_edge("CALLS", "a.foo", "b.bar")
        assert len(graph_store.get_edges_from("a.foo")) == 1


class TestMeta:
    def test_get_set_meta(self, graph_store):
        assert graph_store.get_meta("last_indexed_hash") is None
        graph_store.set_meta("last_indexed_hash", "abc123")
        assert graph_store.get_meta("last_indexed_hash") == "abc123"

    def test_meta_upsert(self, graph_store):
        graph_store.set_meta("key", "val1")
        graph_store.set_meta("key", "val2")
        assert graph_store.get_meta("key") == "val2"


class TestNetworkX:
    def test_build_graph(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="a.foo",
            file_path="a.py", line_start=1, line_end=5, language="python")
        graph_store.upsert_node(kind="function", qualified_name="b.bar",
            file_path="b.py", line_start=1, line_end=5, language="python")
        graph_store.add_edge("CALLS", "a.foo", "b.bar")
        G = graph_store.build_networkx_graph()
        assert G.has_node("a.foo")
        assert G.has_edge("a.foo", "b.bar")
        assert G["a.foo"]["b.bar"]["kind"] == "CALLS"

    def test_cache_invalidation(self, graph_store):
        graph_store.upsert_node(kind="function", qualified_name="a.foo",
            file_path="a.py", line_start=1, line_end=5, language="python")
        G1 = graph_store.build_networkx_graph()
        assert G1.has_node("a.foo")
        graph_store.upsert_node(kind="function", qualified_name="c.baz",
            file_path="c.py", line_start=1, line_end=5, language="python")
        G2 = graph_store.build_networkx_graph()
        assert G2.has_node("c.baz")
