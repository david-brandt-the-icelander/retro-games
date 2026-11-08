"""Validate architecture schemas, examples and diagrams. Requires jsonschema.

Usage: python3 Meta/Agents/Skills/validate_diagrams.py [repository-root]

The skills are found next to this script. Every `.dev/*.json` file in the repository is checked,
except under directories that never hold source: .git, node_modules, build output and the skills
themselves.
"""

import json
import os
import sys
from collections import Counter
from pathlib import Path

from jsonschema import Draft202012Validator

KINDS = ("component", "class", "state", "deployment")
SKIPPED_DIRS = {".git", "node_modules", "dist", "dist-test", "build", "bin", "obj", ".wrangler", "__pycache__"}


def read_json(path):
    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    return json.loads(path.read_text(), object_pairs_hook=unique_keys)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def repo_path(root, value):
    require(not Path(value).is_absolute(), f"Expected repository-relative path: {value}")
    resolved = (root / value).resolve()
    require(resolved.is_relative_to(root), f"Path escapes repository: {value}")
    require(resolved.exists(), f"Missing path: {value}")
    return resolved


def check_graph(document):
    collection = {"component": "components", "class": "types", "state": "states",
                  "deployment": "nodes"}[document["kind"]]
    ids = [item["id"] for item in document[collection]]
    require(len(ids) == len(set(ids)), f"Duplicate IDs in {collection}")
    edges = document.get("relationships", document.get("transitions", []))
    for edge in edges:
        require(edge["from"] in ids, f"Unknown source: {edge['from']}")
        require(edge["to"] in ids, f"Unknown target: {edge['to']}")
    if document["kind"] == "state":
        require(document["initialState"] in ids, "Unknown initial state")
    if document["kind"] == "deployment":
        artifacts = document["artifacts"]
        artifact_ids = [item["id"] for item in artifacts]
        require(len(artifact_ids) == len(set(artifact_ids)), "Duplicate artifact IDs")
        for artifact in artifacts:
            require(artifact["deployedTo"] in ids, "Unknown deployment target")


def diagram_files(root, skills):
    for directory, subdirs, files in os.walk(root):
        here = Path(directory)
        subdirs[:] = sorted(d for d in subdirs if d not in SKIPPED_DIRS and (here / d).resolve() != skills)
        if here.name == ".dev":
            yield from (here / f for f in sorted(files) if f.endswith(".json"))


def validate(root):
    skills = Path(__file__).resolve().parent
    schemas = {}
    for kind in KINDS:
        folder = skills / f"describe-{kind}-diagram"
        schema = read_json(folder / "schema.json")
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        example = read_json(folder / "example.json")
        validator.validate(example)
        check_graph(example)
        require((folder / example["$schema"]).resolve() == (folder / "schema.json").resolve(),
                "Example references the wrong schema")
        schemas[kind] = validator

    counts = Counter()
    for path in diagram_files(root, skills):
        document = read_json(path)
        try:
            kind = document["kind"]
            require(kind in schemas, f"Unknown diagram kind: {kind}")
            schemas[kind].validate(document)
            check_graph(document)
            expected_schema = skills / f"describe-{kind}-diagram/schema.json"
            require((path.parent / document["$schema"]).resolve() == expected_schema.resolve(),
                    "Diagram references the wrong schema")
            require(repo_path(root, document["folder"]) == path.parent.parent,
                    "Folder does not match diagram location")
            expected_name = f"{kind}-diagram.json"
            require(path.name.endswith(".state-diagram.json") if kind == "state"
                    else path.name == expected_name, "Unexpected diagram filename")
            for source in document["sources"]:
                require(repo_path(root, source["path"]).is_file(), f"Source is not a file: {source['path']}")
            for item in document.get("types", []):
                for source in item["sources"]:
                    require(repo_path(root, source).is_file(), f"Type source is not a file: {source}")
            for component in document.get("components", []):
                if "folder" in component:
                    require(repo_path(root, component["folder"]).is_dir(),
                            f"Component folder is not a directory: {component['folder']}")
                if "diagram" in component:
                    target = read_json(repo_path(root, component["diagram"]))
                    require(target["kind"] == "component" and target["folder"] == component.get("folder"),
                            "Component reference describes a different folder or diagram kind")
            for artifact in document.get("artifacts", []):
                require(repo_path(root, artifact["source"]).is_file(), f"Artifact source is not a file: {artifact['source']}")
        except Exception as error:
            raise ValueError(f"{path.relative_to(root)}: {getattr(error, 'message', error)}") from error
        counts[kind] += 1
    require(sum(counts.values()) > 0, "No diagrams found")
    print("Validated four schemas and examples; " + ", ".join(
        f"{count} {kind} diagrams" for kind, count in sorted(counts.items())) + ".")


if __name__ == "__main__":
    repository = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[3]
    validate(repository)
