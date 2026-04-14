"""Test CLI entry point."""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

# graph-server root — needed so the subprocess can import sac_graph
_GRAPH_SERVER_ROOT = str(Path(__file__).resolve().parent.parent)


@pytest.fixture
def real_project(tmp_path):
    """Create a mini-project, index it, return (tmp_path, db_dir)."""
    subprocess.run(["git", "init", "--quiet"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.com"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "T"], cwd=tmp_path, check=True)

    src = tmp_path / "src"
    src.mkdir()
    (src / "service.py").write_text(
        "from src.model import User\n\n"
        "class UserService:\n"
        "    def get_user(self, user_id: int) -> User:\n"
        "        return User(user_id)\n"
    )
    (src / "model.py").write_text(
        "class User:\n"
        "    def __init__(self, id: int):\n"
        "        self.id = id\n"
    )
    tests_dir = tmp_path / "tests"
    tests_dir.mkdir()
    (tests_dir / "test_service.py").write_text(
        "def test_get_user():\n    assert True\n"
    )
    subprocess.run(["git", "add", "."], cwd=tmp_path, check=True)
    subprocess.run(["git", "commit", "-m", "init", "--quiet"], cwd=tmp_path, check=True)
    return tmp_path


def _run_cli(args: list[str], cwd: str) -> dict:
    """Run sac-graph CLI, parse JSON output."""
    env = {**os.environ, "SAC_PROJECT_ROOT": str(cwd)}
    # Ensure sac_graph is importable even though cwd is the tmp project
    env["PYTHONPATH"] = _GRAPH_SERVER_ROOT + os.pathsep + env.get("PYTHONPATH", "")
    r = subprocess.run(
        [sys.executable, "-m", "sac_graph.cli"] + args,
        cwd=cwd, capture_output=True, text=True, env=env,
    )
    assert r.returncode == 0, f"CLI failed: {r.stderr}"
    return json.loads(r.stdout)


def test_index_and_find_symbol(real_project):
    _run_cli(["index", "--full"], cwd=str(real_project))
    result = _run_cli(["find-symbol", "UserService"], cwd=str(real_project))
    assert len(result) >= 1
    assert any("UserService" in r["qualified_name"] for r in result)


def test_module_summary(real_project):
    _run_cli(["index", "--full"], cwd=str(real_project))
    result = _run_cli(["module-summary", "src/", "--depth", "1"], cwd=str(real_project))
    assert "counts" in result
    assert result["counts"]["classes"] >= 2


def test_rebuild(real_project):
    result = _run_cli(["rebuild"], cwd=str(real_project))
    assert result["status"] == "rebuilt"
    assert result["nodes"] > 0
