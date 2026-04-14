"""Per-language AST node type mappings for tree-sitter.

Hardcoded dicts — proven approach (code-review-graph uses same pattern).
.scm query files deferred to future version.
"""

import re
from pathlib import Path

# Extension → tree-sitter language name
EXTENSION_MAP: dict[str, str] = {
    ".py": "python", ".js": "javascript", ".jsx": "javascript",
    ".ts": "typescript", ".tsx": "tsx",
    ".cs": "c_sharp", ".go": "go", ".rs": "rust",
    ".java": "java", ".kt": "kotlin", ".rb": "ruby",
    ".c": "c", ".cpp": "cpp", ".h": "c", ".hpp": "cpp",
    ".swift": "swift", ".php": "php", ".scala": "scala",
    ".dart": "dart", ".lua": "lua", ".sh": "bash", ".bash": "bash",
}

CLASS_TYPES: dict[str, set[str]] = {
    "python": {"class_definition"},
    "typescript": {"class_declaration"},
    "tsx": {"class_declaration"},
    "javascript": {"class_declaration"},
    "c_sharp": {"class_declaration", "record_declaration", "struct_declaration", "interface_declaration", "enum_declaration"},
    "java": {"class_declaration", "interface_declaration", "record_declaration", "enum_declaration"},
    "go": {"type_declaration"},
    "rust": {"struct_item", "enum_item", "impl_item"},
    "kotlin": {"class_declaration", "object_declaration"},
    "ruby": {"class", "module"},
}

FUNCTION_TYPES: dict[str, set[str]] = {
    "python": {"function_definition"},
    "typescript": {"function_declaration", "method_definition", "arrow_function"},
    "tsx": {"function_declaration", "method_definition", "arrow_function"},
    "javascript": {"function_declaration", "method_definition", "arrow_function"},
    "c_sharp": {"method_declaration", "constructor_declaration", "local_function_statement"},
    "java": {"method_declaration", "constructor_declaration"},
    "go": {"function_declaration", "method_declaration"},
    "rust": {"function_item"},
    "kotlin": {"function_declaration"},
    "ruby": {"method", "singleton_method"},
}

IMPORT_TYPES: dict[str, set[str]] = {
    "python": {"import_statement", "import_from_statement"},
    "typescript": {"import_statement"},
    "tsx": {"import_statement"},
    "javascript": {"import_statement"},
    "c_sharp": {"using_directive"},
    "java": {"import_declaration"},
    "go": {"import_declaration"},
    "rust": {"use_declaration"},
    "kotlin": {"import_header"},
}

TEST_PATTERN = re.compile(r"(^test_|_test$|Test$|\.test\.|\.spec\.|_spec\.)")


def detect_language(file_path: str) -> str | None:
    """Detect language from file extension."""
    return EXTENSION_MAP.get(Path(file_path).suffix.lower())
