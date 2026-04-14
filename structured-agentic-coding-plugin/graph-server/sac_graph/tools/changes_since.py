"""get_changes_since — symbol-level diffs since a commit."""
from __future__ import annotations
import subprocess, tempfile
from pathlib import Path
from typing import Any
from sac_graph.graph import GraphStore
from sac_graph.languages import detect_language
from sac_graph.parser import parse_file

def get_changes_since(store: GraphStore, commit_hash: str,
                      project_root: str = ".") -> dict[str, Any]:
    r = subprocess.run(["git", "diff", "--name-status", f"{commit_hash}..HEAD"],
                       cwd=project_root, capture_output=True, text=True)
    added, modified, deleted, files_changed = [], [], [], []
    for line in r.stdout.strip().split("\n"):
        if not line.strip(): continue
        parts = line.split("\t")
        status = parts[0][0]
        if status == "R" and len(parts) >= 3:
            files_changed.extend([parts[1], parts[2]])
        elif len(parts) >= 2:
            files_changed.append(parts[1])
        if status in ("A", "M", "R"):
            rel_path = parts[-1]
            lang = detect_language(rel_path)
            if not lang: continue
            old_path = parts[1] if status == "R" else rel_path
            old_symbols = _parse_old(commit_hash, old_path, lang, project_root)
            full_path = str(Path(project_root) / rel_path)
            try:
                new_result = parse_file(full_path, rel_path, lang)
                new_symbols = {n["qualified_name"]: (n["line_start"], n["line_end"])
                               for n in new_result["nodes"] if n["kind"] != "file"}
            except Exception: new_symbols = {}
            for qn, pos in new_symbols.items():
                if qn not in old_symbols:
                    added.append({"qualified_name": qn, "file_path": rel_path, "line_start": pos[0]})
                elif old_symbols[qn] != pos:
                    modified.append({"qualified_name": qn, "file_path": rel_path, "line_start": pos[0]})
            for qn in old_symbols:
                if qn not in new_symbols:
                    deleted.append({"qualified_name": qn, "file_path": rel_path})
        elif status == "D":
            rel_path = parts[1]
            lang = detect_language(rel_path)
            if not lang: continue
            old_symbols = _parse_old(commit_hash, rel_path, lang, project_root)
            for qn in old_symbols:
                deleted.append({"qualified_name": qn, "file_path": rel_path})
    return {"added": added, "modified": modified, "deleted": deleted,
            "files_changed": list(set(files_changed))}

def _parse_old(commit: str, rel_path: str, lang: str, project_root: str) -> dict:
    try:
        r = subprocess.run(["git", "show", f"{commit}:{rel_path}"],
                           cwd=project_root, capture_output=True)
        if r.returncode != 0: return {}
        with tempfile.NamedTemporaryFile(suffix=Path(rel_path).suffix, delete=False, mode="wb") as tmp:
            tmp.write(r.stdout); tmp_path = tmp.name
        result = parse_file(tmp_path, rel_path, lang)
        Path(tmp_path).unlink(missing_ok=True)
        return {n["qualified_name"]: (n["line_start"], n["line_end"])
                for n in result["nodes"] if n["kind"] != "file"}
    except Exception: return {}
