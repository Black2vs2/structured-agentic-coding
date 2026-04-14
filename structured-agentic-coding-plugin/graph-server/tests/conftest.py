import os
import subprocess
from pathlib import Path

import pytest

from sac_graph.graph import GraphStore


@pytest.fixture
def tmp_project(tmp_path):
    """Create a minimal git project."""
    subprocess.run(["git", "init", "--quiet"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, check=True)
    return tmp_path


@pytest.fixture
def graph_store(tmp_path):
    """GraphStore with temp DB."""
    db_dir = tmp_path / ".code-graph"
    db_dir.mkdir()
    return GraphStore(db_dir / "graph.db")
