import pytest
from sac_graph.parser import parse_file
from sac_graph.languages import EXTENSION_MAP


class TestLanguageDetection:
    def test_common_extensions(self):
        assert ".py" in EXTENSION_MAP
        assert ".ts" in EXTENSION_MAP
        assert ".cs" in EXTENSION_MAP


class TestPythonParsing:
    def test_function(self, tmp_path):
        f = tmp_path / "mod.py"
        f.write_text("def hello(name: str) -> str:\n    return f'Hello {name}'\n")
        result = parse_file(str(f), "mod.py", "python")
        funcs = [n for n in result["nodes"] if n["kind"] == "function"]
        assert any("hello" in n["qualified_name"] for n in funcs)

    def test_class(self, tmp_path):
        f = tmp_path / "mod.py"
        f.write_text("class MyService:\n    def run(self):\n        pass\n")
        result = parse_file(str(f), "mod.py", "python")
        classes = [n for n in result["nodes"] if n["kind"] == "class"]
        assert len(classes) >= 1

    def test_import_edge(self, tmp_path):
        f = tmp_path / "mod.py"
        f.write_text("from os.path import join\nimport sys\n")
        result = parse_file(str(f), "mod.py", "python")
        imports = [e for e in result["edges"] if e["kind"] == "IMPORTS"]
        assert len(imports) >= 1

    def test_test_detection(self, tmp_path):
        f = tmp_path / "test_foo.py"
        f.write_text("def test_something():\n    assert True\n")
        result = parse_file(str(f), "test_foo.py", "python")
        tests = [n for n in result["nodes"] if n["kind"] == "test"]
        assert len(tests) >= 1

    def test_file_node_always_present(self, tmp_path):
        f = tmp_path / "mod.py"
        f.write_text("x = 1\n")
        result = parse_file(str(f), "mod.py", "python")
        files = [n for n in result["nodes"] if n["kind"] == "file"]
        assert len(files) == 1


class TestTypeScriptParsing:
    def test_function(self, tmp_path):
        f = tmp_path / "mod.ts"
        f.write_text("export function greet(name: string): string {\n  return `Hello ${name}`;\n}\n")
        result = parse_file(str(f), "mod.ts", "typescript")
        funcs = [n for n in result["nodes"] if n["kind"] == "function"]
        assert len(funcs) >= 1

    def test_class(self, tmp_path):
        f = tmp_path / "mod.ts"
        f.write_text("export class UserService {\n  getUser(id: number) { return null; }\n}\n")
        result = parse_file(str(f), "mod.ts", "typescript")
        classes = [n for n in result["nodes"] if n["kind"] == "class"]
        assert len(classes) >= 1


class TestCSharpParsing:
    def test_class(self, tmp_path):
        f = tmp_path / "User.cs"
        f.write_text("namespace App.Domain;\npublic class User {\n    public string Name { get; set; }\n}\n")
        result = parse_file(str(f), "User.cs", "c_sharp")
        classes = [n for n in result["nodes"] if n["kind"] == "class"]
        assert len(classes) >= 1

    def test_method(self, tmp_path):
        f = tmp_path / "Svc.cs"
        f.write_text("public class Svc {\n    public void Run() { }\n}\n")
        result = parse_file(str(f), "Svc.cs", "c_sharp")
        funcs = [n for n in result["nodes"] if n["kind"] == "function"]
        assert len(funcs) >= 1


class TestUnsupportedLanguage:
    def test_returns_file_only(self, tmp_path):
        f = tmp_path / "data.json"
        f.write_text('{"key": "value"}')
        result = parse_file(str(f), "data.json", "json")
        assert len(result["nodes"]) == 1
        assert result["nodes"][0]["kind"] == "file"
