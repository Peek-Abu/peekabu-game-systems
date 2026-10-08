"""One-off mover for the module layout (issue #37). The plan's last task deletes it.

Reads docs/superpowers/plans/2026-10-07-module-layout/moves.json: rows of {group, from, to}, where
the paths are DataModel paths under src/ with "/" separators and no extension.

    python3 scripts/python/move_layout.py verify          every module is mapped, moved or kept
    python3 scripts/python/move_layout.py move GROUP...   rewrite references, then git mv the rows

`move` rewrites every reference first (relative and folder-alias requires, dotted and slash paths,
quoted service names, the locals that hold renamed modules, command Name fields), then moves the
files with their specs and stories. It prints what it could not decide, for a human to finish.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

MOVES_FILE = Path("docs/superpowers/plans/2026-10-07-module-layout/moves.json")
# Files that keep their place (spec §2.2); `verify` accepts them without a row.
KEPT_PREFIXES = (
    "ReplicatedStorage/Client/UI/",
    "ServerScriptService/Commands/",
    "ReplicatedStorage/Shared/CmdrTypes/",
    "ServerScriptService/ServerHandler",
    "ServerScriptService/TestRunner",
    "StarterPlayer/StarterPlayerScripts/",
)
SUFFIXES = (".spec.luau", ".story.luau", ".storybook.luau", ".server.luau", ".client.luau", ".luau")
TAGS = (".spec", ".story", ".storybook")
MOVED_EXTENSIONS = (".luau", ".spec.luau", ".story.luau")
SELF = ("scripts/python/move_layout.py", "scripts/python/test_move_layout.py")

REL_REQUIRE = re.compile(r"require\((script(?:\.Parent)+)((?:\.\w+)+)\)")
FOLDER_ALIAS = re.compile(
    r"^local (\w+) = ((?:ReplicatedStorage|ServerScriptService)(?:\.\w+)+)[ \t]*\n", re.MULTILINE
)
COMMAND_NAME = re.compile(r'Name = "(\w+)"')
# One English word (Admin, Actions, General, Locomotion): too common to rename by text search.
SINGLE_WORD = re.compile(r"^[A-Z][a-z]+$")

Parts = tuple[str, ...]


def instance_path(file: str) -> Parts | None:
    """`src/A/B/C.spec.luau` -> ("A", "B", "C.spec"); `.server`/`.client` drop out. None outside src/."""
    if not file.startswith("src/"):
        return None
    rel = file[len("src/") :]
    for suffix in SUFFIXES:
        if rel.endswith(suffix):
            stem = rel[: -len(suffix)]
            tag = suffix[: -len(".luau")]
            return tuple((stem + tag if tag in TAGS else stem).split("/"))
    return None


def split_tag(parts: Parts) -> tuple[Parts, str]:
    for tag in TAGS:
        if parts[-1].endswith(tag):
            return (*parts[:-1], parts[-1][: -len(tag)]), tag
    return parts, ""


def map_parts(parts: Parts, moves: dict[str, str]) -> Parts:
    """Where `parts` lives after `moves`; a spec follows its module."""
    base, tag = split_tag(parts)
    new = moves.get("/".join(base))
    if new is None:
        return parts
    new_parts = tuple(new.split("/"))
    return (*new_parts[:-1], new_parts[-1] + tag)


def rewrite_relative_requires(text: str, old_self: Parts, moves: dict[str, str]) -> tuple[str, set[str]]:
    """A moved relative require becomes absolute (spec §3 rule 7).

    The one relative require kept is a spec requiring its own module (`script.Parent.X` from
    `X.spec`). Requires where neither side moved are left alone.
    """
    new_self = map_parts(old_self, moves)
    needed: set[str] = set()

    def replace(match: re.Match[str]) -> str:
        ups = match.group(1).count(".Parent")
        target = (*old_self[:-ups], *match.group(2)[1:].split("."))
        new_target = map_parts(target, moves)
        if new_target == target and new_self == old_self:
            return match.group(0)
        if new_target[:-1] == new_self[:-1] and new_self[-1] == new_target[-1] + ".spec":
            return f"require(script.Parent.{new_target[-1]})"
        needed.add(new_target[0])
        return f"require({'.'.join(new_target)})"

    return REL_REQUIRE.sub(replace, text), needed


def ensure_services(text: str, services: set[str]) -> str:
    """Declare `local S = game:GetService("S")` for each service a rewritten require now names."""
    for service in sorted(services):
        if re.search(rf'^local {service} = game:GetService\("{service}"\)', text, re.MULTILINE):
            continue
        first_local = re.search(r"^local ", text, re.MULTILINE)
        at = first_local.start() if first_local else len(text)
        text = f'{text[:at]}local {service} = game:GetService("{service}")\n{text[at:]}'
    return text


def inline_folder_aliases(text: str, moves: dict[str, str], modules: set[Parts]) -> str:
    """`local R = ReplicatedStorage.Shared.Modules.Foo` + `require(R.X)` -> an absolute require.

    The folders these aliases name are split across subfolders by the move, so the alias cannot
    follow. The alias line is dropped once nothing else uses it.
    """
    for match in list(FOLDER_ALIAS.finditer(text)):
        alias, value = match.group(1), tuple(match.group(2).split("."))
        if value in modules:
            continue

        def replace(use: re.Match[str], value: Parts = value) -> str:
            target = (*value, *use.group(1)[1:].split("."))
            new_target = map_parts(target, moves)
            return use.group(0) if new_target == target else f"require({'.'.join(new_target)})"

        text = re.sub(rf"require\({alias}((?:\.\w+)+)\)", replace, text)
        # `(?<![\w.])`: the alias's own folder name inside its value (`...Constants.Animations`) is
        # not a use.
        if len(re.findall(rf"(?<![\w.]){alias}\b", code_only(text))) == 1:
            text = text.replace(match.group(0), "", 1)
    return text


def code_only(text: str) -> str:
    """`text` with comments and string literals blanked, for counting real uses of a name."""
    return LUAU_TOKENS.sub(lambda match: " " * len(match.group(0)), text)


# A require into one feature's folder: group 1 is the folder, group 2 the rest of the path.
FEATURE_REQUIRE = re.compile(
    r"require\(((?:ReplicatedStorage\.(?:Shared|Client)|ServerScriptService)\.Features\.\w+)\.([\w.]+)\)"
)
REALM_OF = {"ReplicatedStorage.Shared": "Shared", "ReplicatedStorage.Client": "Client", "ServerScriptService": "Server"}
# Spec §3 rule 7: name a feature folder only when a file requires from it this many times.
FOLDER_VARIABLE_MIN_USES = 3


def folder_variable_name(folder: str) -> str:
    """`ReplicatedStorage.Client.Features.Replication` -> `ReplicationClient`."""
    root, feature = folder.rsplit(".Features.", 1)
    return feature + REALM_OF[root]


def add_folder_variables(text: str) -> tuple[str, list[str]]:
    """Name a feature folder once when a file requires three or more modules from it (rule 7).

    `local ReplicationClient = ReplicatedStorage.Client.Features.Replication` then
    `require(ReplicationClient.Systems.ReplicationOwnerRigSystem)`. A folder that already has its
    variable gets every require routed through it. A name already used for something else is
    reported, not overwritten.
    """
    counts: dict[str, int] = {}
    for match in FEATURE_REQUIRE.finditer(text):
        counts[match.group(1)] = counts.get(match.group(1), 0) + 1
    collisions: list[str] = []
    declarations: list[str] = []
    for folder in sorted(counts):
        name = folder_variable_name(folder)
        declaration = f"local {name} = {folder}\n"
        declared = declaration in text
        if not declared and counts[folder] < FOLDER_VARIABLE_MIN_USES:
            continue
        if not declared and re.search(rf"(?<![\w.]){name}\b", code_only(text)):
            collisions.append(name)
            continue
        text = text.replace(f"require({folder}.", f"require({name}.")
        if not declared:
            declarations.append(declaration)
    if declarations:
        first_require = re.search(r"^local \w+ =\s*(?:\n\s*)?require\(", text, re.MULTILINE)
        at = first_require.start() if first_require else 0
        text = text[:at] + "".join(declarations) + text[at:]
    return text, collisions


def rewrite_paths(text: str, moves: dict[str, str]) -> str:
    """Dotted (`ReplicatedStorage.Shared.Modules.X`) and slash (`.../Modules/X.luau`) paths."""
    for old in sorted(moves, key=len, reverse=True):
        new = moves[old]
        for sep in (".", "/"):
            pattern = rf"(?<!\w){re.escape(old.replace('/', sep))}(?!\w)"
            replacement = new.replace("/", sep)
            text = re.sub(pattern, lambda _match, r=replacement: r, text)
    return text


def rename_quoted(text: str, renames: dict[str, str]) -> str:
    """`"OldServiceServer"` in dependencies, getService, Logger names and describe blocks."""
    for old, new in renames.items():
        if not SINGLE_WORD.match(old):
            text = text.replace(f'"{old}"', f'"{new}"')
    return text


def rename_bindings(text: str, renames: dict[str, str], own: str | None) -> tuple[str, list[str]]:
    """Rename a renamed module wherever it is a name: in its own file, and the local holding it.

    The module's own-named export type follows it (`RigOutfit.RigOutfit` becomes
    `CustomizationRigOutfitTracker.CustomizationRigOutfitTracker`); any other `.Old` field is left
    alone. A requirer that declares its own `type Old` is skipped and reported for a human.
    """
    skipped: list[str] = []
    for old, new in renames.items():
        is_own = own == new
        bound = re.search(rf"^local {old} = require\(", text, re.MULTILINE) is not None
        if not (bound or is_own):
            continue
        if not is_own and re.search(rf"\btype {old}\b", text):
            skipped.append(old)
            continue
        text = re.sub(rf'(?<![\w."]){old}(?![\w"])', new, text)
        text = re.sub(rf"(?<![\w.]){new}\.{old}(?!\w)", f"{new}.{new}", text)
    return text, skipped


def rename_prose(text: str, renames: dict[str, str]) -> str:
    """Docs: a renamed module's bare name, when it is distinctive enough to search for."""
    for old, new in renames.items():
        if not SINGLE_WORD.match(old):
            text = re.sub(rf"(?<![\w./]){old}(?!\w)", new, text)
    return text


# A Luau comment, or a string literal (matched only so a `--` inside a string is not a comment).
LUAU_TOKENS = re.compile(
    r"""--\[(=*)\[.*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`|\[(=*)\[.*?\]\2\]""",
    re.DOTALL,
)


def rename_in_comments(text: str, renames: dict[str, str]) -> str:
    """Module names mentioned in comments follow the rename; code and strings are left alone."""

    def fix(match: re.Match[str]) -> str:
        token = match.group(0)
        return rename_prose(token, renames) if token.startswith("--") else token

    return LUAU_TOKENS.sub(fix, text)


def rename_command(text: str, old: str, new: str) -> str:
    """The definition's first `Name = "..."` is the typed command."""
    match = COMMAND_NAME.search(text)
    if match is None or match.group(1) != old.lower():
        return text
    return f'{text[: match.start()]}Name = "{new.lower()}"{text[match.end() :]}'


def leftovers(text: str, renames: dict[str, str]) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for old in renames:
            if not SINGLE_WORD.match(old) and re.search(rf"(?<![\w.]){old}(?!\w)", line):
                found.append((line_no, line.strip()))
    return found


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True, encoding="utf-8").stdout


def rewrite_targets() -> list[str]:
    files = git("ls-files", "src", "tasks", "scripts/python", "docs", "AGENTS.md", "README.md", "CONTRIBUTING.md")
    return [
        f
        for f in files.splitlines()
        if f.endswith((".luau", ".py", ".md")) and not f.startswith("docs/superpowers/") and f not in SELF
    ]


def load_rows() -> list[dict[str, str]]:
    return json.loads(MOVES_FILE.read_text(encoding="utf-8"))["rows"]


def read(path: str) -> str:
    with open(path, encoding="utf-8", newline="") as handle:
        return handle.read()


def write(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def cmd_verify() -> int:
    rows = load_rows()
    froms = {r["from"] for r in rows}
    tos = {r["to"] for r in rows}
    # A spec with no module beside it (a load test) is placed by its own row, so it counts here too.
    modules = set()
    for f in git("ls-files", "src").splitlines():
        parts = instance_path(f)
        if parts is not None:
            modules.add("/".join(split_tag(parts)[0]))
    unmapped = sorted(m for m in modules if m not in froms | tos and not m.startswith(KEPT_PREFIXES))
    stale = sorted(r["from"] for r in rows if r["from"] not in modules and r["to"] not in modules)
    for m in unmapped:
        print(f"  UNMAPPED  {m}")
    for m in stale:
        print(f"  STALE     {m}")
    print(f"{len(modules)} modules, {len(unmapped)} unmapped, {len(stale)} stale rows")
    return 1 if unmapped or stale else 0


def cmd_move(groups: list[str]) -> int:
    rows = load_rows()
    known = {r["group"] for r in rows}
    unknown = [g for g in groups if g not in known]
    if unknown:
        print(f"unknown group(s): {', '.join(unknown)}; known: {', '.join(sorted(known))}")
        return 1
    chosen = [r for r in rows if r["group"] in groups]
    moves = {r["from"]: r["to"] for r in chosen}
    renames = {
        old.rsplit("/", 1)[1]: new.rsplit("/", 1)[1]
        for old, new in moves.items()
        if old.rsplit("/", 1)[1] != new.rsplit("/", 1)[1]
    }
    commands = {
        old.rsplit("/", 1)[1]: new.rsplit("/", 1)[1]
        for old, new in moves.items()
        if old.startswith("ServerScriptService/Commands/") and not old.endswith("Server")
    }
    # Command names (AddCurrency, DepositItem) double as packet names and UI labels, so comments and
    # prose never rename them; only their files, paths and Name fields change.
    module_renames = {
        old: new for old, new in renames.items() if old.removesuffix("Server") not in commands
    }
    files = rewrite_targets()
    modules = {p for f in files if (p := instance_path(f)) is not None and split_tag(p)[1] == ""}
    skipped_report: list[str] = []
    leftover_report: list[str] = []
    for file in files:
        original = text = read(file)
        old_self = instance_path(file)
        if file.endswith(".luau"):
            needed: set[str] = set()
            if old_self is not None:
                text, needed = rewrite_relative_requires(text, old_self, moves)
            text = inline_folder_aliases(text, moves, modules)
            text = rewrite_paths(text, moves)
            text = ensure_services(text, needed)
            if old_self is not None:
                text, collisions = add_folder_variables(text)
                skipped_report += [f"{file}: `{name}` is taken, so its folder needs naming by hand" for name in collisions]
            text = rename_quoted(text, renames)
            own = map_parts(old_self, moves)[-1] if old_self is not None else None
            text, skipped = rename_bindings(text, renames, own)
            text = rename_in_comments(text, module_renames)
            skipped_report += [f"{file}: declares `type {name}`, rename its local by hand" for name in skipped]
            if old_self is not None and old_self[:-1] == ("ServerScriptService", "Commands"):
                old_name = old_self[-1]
                if old_name in commands:
                    text = rename_command(text, old_name, commands[old_name])
        else:
            text = rewrite_paths(text, moves)
            if file.endswith(".md"):
                text = rename_prose(text, module_renames)
        if text != original:
            write(file, text)
        leftover_report += [f"{file}:{n}: {line}" for n, line in leftovers(text, module_renames)]
    for old, new in moves.items():
        for ext in MOVED_EXTENSIONS:
            source = Path(f"src/{old}{ext}")
            if source.exists():
                target = Path(f"src/{new}{ext}")
                target.parent.mkdir(parents=True, exist_ok=True)
                git("mv", str(source).replace("\\", "/"), str(target).replace("\\", "/"))
    single = sorted(old for old in renames if SINGLE_WORD.match(old))
    print(f"moved {len(moves)} module(s) in {', '.join(groups)}")
    for line in skipped_report:
        print(f"  BY HAND   {line}")
    if single:
        print(f"  REVIEW    single-word renames ({', '.join(single)}): check `git diff` for English uses")
    for line in leftover_report:
        print(f"  LEFTOVER  {line}")
    return 0


def main(argv: list[str]) -> int:
    # Windows consoles default to cp1252; the report quotes source lines full of em dashes.
    sys.stdout.reconfigure(encoding="utf-8")
    if argv[:1] == ["verify"]:
        return cmd_verify()
    if argv[:1] == ["move"] and len(argv) > 1:
        return cmd_move(argv[1:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
