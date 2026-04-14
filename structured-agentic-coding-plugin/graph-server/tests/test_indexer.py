import subprocess
import pytest
from sac_graph.graph import GraphStore
from sac_graph.indexer import Indexer


@pytest.fixture
def git_project(tmp_path):
    subprocess.run(["git", "init", "--quiet"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.com"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "T"], cwd=tmp_path, check=True)
    (tmp_path / "main.py").write_text("def hello():\n    return 'world'\n")
    (tmp_path / "utils.py").write_text("class Helper:\n    def run(self):\n        pass\n")
    subprocess.run(["git", "add", "."], cwd=tmp_path, check=True)
    subprocess.run(["git", "commit", "-m", "init", "--quiet"], cwd=tmp_path, check=True)
    return tmp_path


@pytest.fixture
def indexer(git_project):
    db_dir = git_project / ".code-graph"
    db_dir.mkdir()
    store = GraphStore(db_dir / "graph.db")
    return Indexer(store, str(git_project))


class TestFullIndex:
    def test_indexes_files(self, indexer):
        stats = indexer.full_index()
        assert stats["files_indexed"] >= 2
        assert indexer.store.find_nodes("hello")

    def test_sets_hash(self, indexer):
        indexer.full_index()
        assert indexer.store.get_meta("last_indexed_hash") is not None

    def test_parallel_flag(self, indexer):
        stats = indexer.full_index()
        assert "mode" in stats
        assert stats["mode"] == "full"


class TestIncrementalIndex:
    def test_no_changes(self, indexer):
        indexer.full_index()
        stats = indexer.incremental_index()
        assert stats["files_indexed"] == 0

    def test_with_changes(self, indexer, git_project):
        indexer.full_index()
        (git_project / "new_mod.py").write_text("def new_func():\n    pass\n")
        subprocess.run(["git", "add", "."], cwd=git_project, check=True)
        subprocess.run(["git", "commit", "-m", "add", "--quiet"], cwd=git_project, check=True)
        stats = indexer.incremental_index()
        assert stats["files_indexed"] >= 1
        assert indexer.store.find_nodes("new_func")

    def test_deleted_file(self, indexer, git_project):
        indexer.full_index()
        assert indexer.store.find_nodes("hello")
        (git_project / "main.py").unlink()
        subprocess.run(["git", "add", "."], cwd=git_project, check=True)
        subprocess.run(["git", "commit", "-m", "del", "--quiet"], cwd=git_project, check=True)
        indexer.incremental_index()
        assert len(indexer.store.find_nodes("hello")) == 0


class TestEnsureIndex:
    def test_builds_if_missing(self, indexer):
        indexer.ensure_index()
        assert indexer.store.get_meta("last_indexed_hash") is not None

    def test_updates_if_stale(self, indexer, git_project):
        indexer.full_index()
        (git_project / "another.py").write_text("def another():\n    pass\n")
        subprocess.run(["git", "add", "."], cwd=git_project, check=True)
        subprocess.run(["git", "commit", "-m", "add", "--quiet"], cwd=git_project, check=True)
        indexer.ensure_index()
        assert indexer.store.find_nodes("another")
