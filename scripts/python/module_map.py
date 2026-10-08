"""Keep the module map in docs/project-structure.md true to the tree.

The map lists every feature module, plus Core and Data, grouped by feature. It is generated, never
hand-edited, so it cannot drift from src/:

    python3 scripts/python/module_map.py --check    fail if the doc's map is stale (check.sh, CI)
    python3 scripts/python/module_map.py --write    regenerate it after adding, moving or renaming
"""

from __future__ import annotations

import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path

DOC = Path("docs/project-structure.md")
START = "<!-- module-map:start -->"
END = "<!-- module-map:end -->"
FEATURE_ROOTS = (
    ("src/ReplicatedStorage/Shared/Features/", "shared"),
    ("src/ReplicatedStorage/Client/Features/", "client"),
    ("src/ServerScriptService/Features/", "server"),
)
OUTSIDE = (
    ("src/ReplicatedStorage/Shared/Core/", "Core", "shared"),
    ("src/ServerScriptService/Core/", "Core", "server"),
    ("src/ReplicatedStorage/Shared/Data/", "Data", "shared"),
)
REALM_ORDER = {"shared": 0, "client": 1, "server": 2}


def render(paths: Iterable[str]) -> str:
    """The map's markdown: one table per feature, then Core and Data."""
    groups: dict[str, list[tuple[str, str]]] = {}
    for path in paths:
        if not path.endswith(".luau") or path.endswith((".spec.luau", ".story.luau")):
            continue
        for root, realm in FEATURE_ROOTS:
            if path.startswith(root):
                feature, rest = path[len(root) :].split("/", 1)
                groups.setdefault(feature, []).append((realm, rest.removesuffix(".luau")))
        for root, group, realm in OUTSIDE:
            if path.startswith(root):
                groups.setdefault(group, []).append((realm, path[len(root) :].removesuffix(".luau")))
    order = sorted(g for g in groups if g not in ("Core", "Data")) + [g for g in ("Core", "Data") if g in groups]
    lines: list[str] = []
    for group in order:
        lines += [f"### {group}", "", "| Realm | Module |", "|---|---|"]
        for realm, rest in sorted(groups[group], key=lambda row: (REALM_ORDER[row[0]], row[1])):
            lines.append(f"| {realm} | `{rest}` |")
        lines.append("")
    return "\n".join(lines)


def replace_section(doc: str, body: str) -> str:
    """`doc` with the text between the markers replaced by `body`."""
    start = doc.index(START) + len(START)
    end = doc.index(END)
    return f"{doc[:start]}\n\n{body}\n{doc[end:]}"


def tracked() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "src"], capture_output=True, text=True, check=True, encoding="utf-8"
    )
    return result.stdout.splitlines()


def main(argv: list[str]) -> int:
    doc = DOC.read_text(encoding="utf-8")
    fresh = replace_section(doc, render(tracked()))
    if argv == ["--write"]:
        DOC.write_text(fresh, encoding="utf-8", newline="\n")
        print(f"    wrote the module map in {DOC}")
        return 0
    if argv == ["--check"]:
        if fresh != doc:
            print(f"  FAIL  the module map in {DOC} is stale. Run: python3 scripts/python/module_map.py --write")
            return 1
        print("    module map is current")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
