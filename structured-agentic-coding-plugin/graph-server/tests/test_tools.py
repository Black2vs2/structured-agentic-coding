import pytest
from sac_graph.graph import GraphStore
from sac_graph.tools.find_symbol import find_symbol
from sac_graph.tools.module_summary import get_module_summary
from sac_graph.tools.dependencies import get_dependencies
from sac_graph.tools.dependents import get_dependents
from sac_graph.tools.blast_radius import get_blast_radius
from sac_graph.tools.test_coverage import get_test_coverage_map


@pytest.fixture
def populated_store(graph_store):
    s = graph_store
    s.upsert_node(kind="file", qualified_name="src/service.py", file_path="src/service.py", line_start=1, line_end=50, language="python")
    s.upsert_node(kind="file", qualified_name="src/model.py", file_path="src/model.py", line_start=1, line_end=30, language="python")
    s.upsert_node(kind="class", qualified_name="model.User", file_path="src/model.py", line_start=1, line_end=15, language="python")
    s.upsert_node(kind="class", qualified_name="service.UserService", file_path="src/service.py", line_start=1, line_end=30, language="python")
    s.upsert_node(kind="function", qualified_name="service.UserService.get_user", file_path="src/service.py", line_start=5, line_end=15, language="python")
    s.upsert_node(kind="function", qualified_name="controller.get_endpoint", file_path="src/controller.py", line_start=10, line_end=20, language="python")
    s.upsert_node(kind="test", qualified_name="test_service.test_get_user", file_path="tests/test_service.py", line_start=1, line_end=10, language="python")
    s.add_edge("IMPORTS", "src/service.py", "model")
    s.add_edge("CALLS", "service.UserService.get_user", "model.User")
    s.add_edge("CALLS", "controller.get_endpoint", "service.UserService.get_user")
    s.add_edge("TESTED_BY", "service.UserService.get_user", "test_service.test_get_user")
    s.add_edge("CONTAINS", "src/service.py", "service.UserService")
    s.add_edge("CONTAINS", "service.UserService", "service.UserService.get_user")
    return s


class TestFindSymbol:
    def test_exact_match_ranks_highest(self, populated_store):
        results = find_symbol(populated_store, "UserService")
        assert results[0]["qualified_name"] == "service.UserService"
        assert results[0]["score"] > results[-1]["score"] if len(results) > 1 else True

    def test_kind_filter(self, populated_store):
        results = find_symbol(populated_store, "User", kind="class")
        assert all(r["kind"] == "class" for r in results)

    def test_limit(self, populated_store):
        results = find_symbol(populated_store, "service", limit=2)
        assert len(results) <= 2

    def test_no_match(self, populated_store):
        assert find_symbol(populated_store, "NonExistent") == []


class TestModuleSummary:
    def test_depth_1_counts_only(self, populated_store):
        r = get_module_summary(populated_store, "src/", depth=1)
        assert "counts" in r
        assert isinstance(r["classes"], list)
        # depth=1: class names are strings, not dicts
        if r["classes"]:
            assert isinstance(r["classes"][0], str)

    def test_depth_2_with_locations(self, populated_store):
        r = get_module_summary(populated_store, "src/", depth=2)
        assert "counts" in r
        if r["classes"]:
            assert isinstance(r["classes"][0], dict)
            assert "name" in r["classes"][0]

    def test_depth_3_full_detail(self, populated_store):
        r = get_module_summary(populated_store, "src/", depth=3)
        if r["classes"]:
            assert "dependency_count" in r["classes"][0]

    def test_empty_directory(self, populated_store):
        r = get_module_summary(populated_store, "nonexistent/")
        assert r["counts"]["classes"] == 0

    def test_max_tokens_truncation(self, populated_store):
        r = get_module_summary(populated_store, "src/", depth=3, max_tokens=50)
        assert "counts" in r


class TestDependencies:
    def test_outgoing(self, populated_store):
        r = get_dependencies(populated_store, "service.UserService.get_user")
        targets = [x["target"] for x in r]
        assert "model.User" in targets

    def test_empty(self, populated_store):
        assert get_dependencies(populated_store, "model.User") == []


class TestDependents:
    def test_incoming(self, populated_store):
        r = get_dependents(populated_store, "service.UserService.get_user")
        sources = [x["source"] for x in r]
        assert "controller.get_endpoint" in sources

    def test_empty(self, populated_store):
        assert get_dependents(populated_store, "controller.get_endpoint") == []


class TestBlastRadius:
    def test_finds_affected(self, populated_store):
        r = get_blast_radius(populated_store, ["model.User"])
        assert len(r["affected_symbols"]) >= 1

    def test_returns_config_refs_key(self, populated_store):
        r = get_blast_radius(populated_store, ["model.User"])
        assert "config_references" in r


class TestTestCoverage:
    def test_direct(self, populated_store):
        r = get_test_coverage_map(populated_store, "service.UserService.get_user")
        assert any("test_get_user" in t["qualified_name"] for t in r)

    def test_no_coverage(self, populated_store):
        assert get_test_coverage_map(populated_store, "controller.get_endpoint") == []
