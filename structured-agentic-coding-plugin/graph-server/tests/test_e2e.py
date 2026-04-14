"""End-to-end: write real files → index via CLI → query via CLI."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

_GRAPH_SERVER_ROOT = str(Path(__file__).resolve().parent.parent)


@pytest.fixture
def real_project(tmp_path):
    """Create a realistic mini-project with multiple languages."""
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


def _run(args: list[str], cwd: str) -> dict:
    env = {**os.environ, "SAC_PROJECT_ROOT": str(cwd)}
    env["PYTHONPATH"] = _GRAPH_SERVER_ROOT + os.pathsep + env.get("PYTHONPATH", "")
    r = subprocess.run(
        [sys.executable, "-m", "sac_graph.cli"] + args,
        cwd=cwd, capture_output=True, text=True, env=env,
    )
    assert r.returncode == 0, f"CLI failed ({args}): {r.stderr}"
    return json.loads(r.stdout)


def test_full_round_trip(real_project):
    """index → find_symbol → module_summary → dependencies → blast_radius."""
    cwd = str(real_project)

    # index
    stats = _run(["index", "--full"], cwd)
    assert stats["files_indexed"] >= 3
    assert stats["nodes"] > 0

    # find_symbol
    results = _run(["find-symbol", "UserService"], cwd)
    assert len(results) >= 1
    assert any("UserService" in r["qualified_name"] for r in results)

    # module_summary
    summary = _run(["module-summary", "src/", "--depth", "1"], cwd)
    assert summary["counts"]["classes"] >= 2

    # dependencies
    svc = [r for r in _run(["find-symbol", "get_user"], cwd)
           if "service" in r["qualified_name"].lower()]
    if svc:
        deps = _run(["dependencies", svc[0]["qualified_name"]], cwd)
        assert isinstance(deps, list)

    # blast_radius
    user_results = _run(["find-symbol", "User", "--kind", "class"], cwd)
    if user_results:
        blast = _run(["blast-radius", user_results[0]["qualified_name"]], cwd)
        assert "affected_files" in blast
        assert "config_references" in blast
