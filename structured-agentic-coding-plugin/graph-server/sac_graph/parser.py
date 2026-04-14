"""Tree-sitter AST extraction — parse source files into nodes and edges."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import tree_sitter_language_pack as tslp

from sac_graph.languages import (
    CLASS_TYPES, FUNCTION_TYPES, IMPORT_TYPES, TEST_PATTERN, detect_language,
)


def parse_file(abs_path: str, rel_path: str, language: str) -> dict[str, list[dict[str, Any]]]:
    """Parse a source file. Returns {"nodes": [...], "edges": [...]}."""
    path = Path(abs_path)
    source = path.read_bytes()
    line_count = source.count(b"\n") + 1
    file_stem = Path(rel_path).stem

    file_node = {
        "kind": "file", "qualified_name": rel_path, "file_path": rel_path,
        "line_start": 1, "line_end": line_count, "language": language,
        "params": None, "return_type": None,
    }
    nodes: list[dict[str, Any]] = [file_node]
    edges: list[dict[str, Any]] = []

    try:
        parser = tslp.get_parser(language)
    except Exception:
        return {"nodes": nodes, "edges": edges}

    tree = parser.parse(source)
    is_test_file = bool(TEST_PATTERN.search(file_stem))

    class_types = CLASS_TYPES.get(language, set())
    func_types = FUNCTION_TYPES.get(language, set())
    import_types = IMPORT_TYPES.get(language, set())

    _walk(tree.root_node, nodes, edges, rel_path, language, file_stem,
          is_test_file, class_types, func_types, import_types, parent="")
    return {"nodes": nodes, "edges": edges}


def _get_name(node) -> str:
    """Extract name from an AST node."""
    for field in ("name", "declarator"):
        child = node.child_by_field_name(field)
        if child:
            if child.type in ("identifier", "property_identifier"):
                return child.text.decode("utf-8")
            sub = child.child_by_field_name("name")
            if sub:
                return sub.text.decode("utf-8")
            return child.text.decode("utf-8").split("(")[0].split("<")[0].strip()
    for child in node.children:
        if child.type == "identifier":
            return child.text.decode("utf-8")
    return "<anonymous>"


def _get_import_target(node, language: str) -> str | None:
    """Extract import target module/path."""
    if language == "python":
        mod = node.child_by_field_name("module_name")
        if mod:
            return mod.text.decode("utf-8")
        for child in node.children:
            if child.type == "dotted_name":
                return child.text.decode("utf-8")
    elif language in ("typescript", "tsx", "javascript"):
        source = node.child_by_field_name("source")
        if source:
            return source.text.decode("utf-8").strip("'\"")
    elif language == "c_sharp":
        name = node.child_by_field_name("name")
        if name:
            return name.text.decode("utf-8")
    return None


def _walk(node, nodes, edges, rel_path, language, file_stem,
          is_test_file, class_types, func_types, import_types, parent=""):
    """Recursively extract structural nodes and edges from AST."""

    if node.type in class_types:
        name = _get_name(node)
        qname = f"{file_stem}.{parent}{name}" if not parent else f"{file_stem}.{parent}{name}"
        nodes.append({
            "kind": "class", "qualified_name": qname, "file_path": rel_path,
            "line_start": node.start_point[0] + 1, "line_end": node.end_point[0] + 1,
            "language": language, "params": None, "return_type": None,
        })
        edges.append({"kind": "CONTAINS", "source": rel_path, "target": qname})
        for child in node.children:
            _walk(child, nodes, edges, rel_path, language, file_stem,
                  is_test_file, class_types, func_types, import_types, parent=f"{name}.")
        return

    if node.type in func_types:
        name = _get_name(node)
        qname = f"{file_stem}.{parent}{name}"
        kind = "test" if (is_test_file and TEST_PATTERN.search(name)) else "function"
        nodes.append({
            "kind": kind, "qualified_name": qname, "file_path": rel_path,
            "line_start": node.start_point[0] + 1, "line_end": node.end_point[0] + 1,
            "language": language, "params": None, "return_type": None,
        })
        container = rel_path if not parent else f"{file_stem}.{parent.rstrip('.')}"
        edges.append({"kind": "CONTAINS", "source": container, "target": qname})
        return

    if node.type in import_types:
        target = _get_import_target(node, language)
        if target:
            edges.append({"kind": "IMPORTS", "source": rel_path, "target": target})
        return

    for child in node.children:
        _walk(child, nodes, edges, rel_path, language, file_stem,
              is_test_file, class_types, func_types, import_types, parent)
