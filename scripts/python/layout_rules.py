"""Module layout rules (issue #37; the reference is docs/project-structure.md).

Whole-tree invariants, like the asset-id rule: the layout move left every file compliant, so there is
no past to grandfather. Every first-party `.luau` file under src/ must sit in a feature folder or in
one of the few places outside features, and its name must say its feature and its role:

* **placement**: inside `Features/<Feature>/` of its realm, or in the outside-features list.
* **depth**: `<Feature>/<Name>` for the service, `<Feature>/<Subfolder>/<Name>` for everything else.
* **prefix**: a feature module's name starts with its feature.
* **role word**: it ends with a role word its subfolder allows; a root file is the feature's service.
* **one service**: one service per feature per realm, unless SERVICE_EXCEPTIONS records why.
* **command names**: a command starts with a feature and its `Name` is its file name in lower case.
* **UI names**: modules in the UI tree are PascalCase, or `use<Thing>` hooks.

Specs, stories and storybooks are judged by the module name they carry.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Iterable

FEATURE_ROOTS: dict[str, str] = {
    "src/ReplicatedStorage/Shared/Features/": "shared",
    "src/ReplicatedStorage/Client/Features/": "client",
    "src/ServerScriptService/Features/": "server",
}
# The only places outside a feature (project-structure.md, "Outside features"). Core and Data are
# closed lists: a module owned by one feature belongs in that feature.
OUTSIDE_FEATURES = (
    "src/ReplicatedStorage/Shared/Core/",
    "src/ServerScriptService/Core/",
    "src/ReplicatedStorage/Shared/Data/",
    "src/ReplicatedStorage/Shared/CmdrTypes/",
    "src/ReplicatedStorage/Client/UI/",
    "src/ServerScriptService/Commands/",
)
ENTRY_SCRIPTS = frozenset(
    {
        "src/ServerScriptService/ServerHandler.server.luau",
        "src/ServerScriptService/TestRunner.server.luau",
        "src/StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau",
        # The engine skips inserting its own Animate script only when the name matches.
        "src/StarterPlayer/StarterCharacterScripts/Animate.client.luau",
    }
)
UI_TREE = "src/ReplicatedStorage/Client/UI/"
COMMANDS = "src/ServerScriptService/Commands/"

# The seven subfolders and the role words each allows. Changing this table is a RULE change:
# a new subfolder kind needs at least three modules that share it AND the user's approval, and a
# new role word needs the user's approval. Editing it only to make a failing file pass is a CI
# bypass and is rejected in review.
ROLE_WORDS: dict[str, tuple[str, ...]] = {
    "Data": ("Constants", "Registry", "Types", "Assets"),
    "Net": ("Events", "Codec", "Sender", "Receiver"),
    "Rules": ("Rules", "Check"),
    "State": ("Store", "Tracker", "Pool"),
    "Utils": ("Utils", "Formulas"),
    "Systems": ("System",),
    "Testing": ("Harness",),
}
# The shared realm has no services: services are server or client.
SERVICE_SUFFIX: dict[str, str] = {"client": "ServiceClient", "server": "ServiceServer"}
# A second service in one feature and realm: file name -> the recorded reason. Each entry needs the
# user's approval. Empty on purpose.
SERVICE_EXCEPTIONS: dict[str, str] = {}

PASCAL = re.compile(r"^[A-Z][A-Za-z0-9]*$")
HOOK = re.compile(r"^use[A-Z][A-Za-z0-9]*$")
COMMAND_NAME = re.compile(r'Name = "(\w+)"')
TAGS = (".spec", ".story", ".storybook", ".server", ".client")
GUIDE = "See docs/project-structure.md, or run the module-placement skill."


def module_name(path: str) -> str:
    """`src/A/BankEvents.spec.luau` -> `BankEvents`."""
    stem = path.rsplit("/", 1)[-1].removesuffix(".luau")
    for tag in TAGS:
        stem = stem.removesuffix(tag)
    return stem


def _feature_root(path: str) -> tuple[str, str] | None:
    for root, realm in FEATURE_ROOTS.items():
        if path.startswith(root):
            return root, realm
    return None


def _feature_of(path: str) -> str | None:
    found = _feature_root(path)
    return None if found is None else path[len(found[0]) :].split("/", 1)[0]


def _check_feature_file(path: str, name: str, root: str, realm: str) -> list[str]:
    parts = path[len(root) :].split("/")
    feature = parts[0]
    if not PASCAL.match(feature):
        return [f"{path}: feature folder `{feature}` is not PascalCase. {GUIDE}"]
    if len(parts) == 2:
        suffix = SERVICE_SUFFIX.get(realm)
        if suffix is None:
            return [f"{path}: the shared realm has no services; this belongs in a subfolder. {GUIDE}"]
        if name == feature + suffix:
            return []
        if name in SERVICE_EXCEPTIONS and name.startswith(feature) and name.endswith(suffix):
            return []
        return [
            f"{path}: only `{feature}{suffix}` sits at the feature root. A second service needs the "
            f"user's approval and an entry in SERVICE_EXCEPTIONS. {GUIDE}"
        ]
    if len(parts) != 3:
        return [f"{path}: too deep. Feature files sit at <Feature>/<Subfolder>/<Name>. {GUIDE}"]
    sub = parts[1]
    if sub not in ROLE_WORDS:
        return [
            f"{path}: `{sub}/` is not a subfolder kind ({', '.join(ROLE_WORDS)}). A new kind needs "
            f"three modules that share it and the user's approval. {GUIDE}"
        ]
    errors: list[str] = []
    if not name.startswith(feature):
        errors.append(f"{path}: `{name}` must start with its feature, `{feature}`. {GUIDE}")
    if not name.endswith(ROLE_WORDS[sub]):
        errors.append(
            f"{path}: `{name}` must end with a {sub}/ role word ({', '.join(ROLE_WORDS[sub])}). "
            f"A new role word needs the user's approval. {GUIDE}"
        )
    return errors


def _check_command(path: str, name: str, features: set[str], read: Callable[[str], str]) -> list[str]:
    base = name.removesuffix("Server")
    errors: list[str] = []
    if not any(base.startswith(feature) for feature in features):
        errors.append(f"{path}: command `{base}` must start with its feature's name. {GUIDE}")
    if path.endswith(".spec.luau") or name.endswith("Server"):
        return errors
    match = COMMAND_NAME.search(read(path))
    if match is None or match.group(1) != base.lower():
        errors.append(f'{path}: its Name must be "{base.lower()}", the file name in lower case. {GUIDE}')
    return errors


def _check_one(path: str, features: set[str], read: Callable[[str], str]) -> list[str]:
    if path in ENTRY_SCRIPTS:
        return []
    name = module_name(path)
    found = _feature_root(path)
    if found is not None:
        return _check_feature_file(path, name, *found)
    if path.startswith(UI_TREE):
        if PASCAL.match(name) or HOOK.match(name):
            return []
        return [f"{path}: UI module names are PascalCase, or use<Thing> for hooks. {GUIDE}"]
    if path.startswith(COMMANDS):
        return _check_command(path, name, features, read)
    if path.startswith(OUTSIDE_FEATURES):
        return []
    return [f"{path}: outside every Features/<Feature>/ root and the outside-features list. {GUIDE}"]


def check_layout(paths: Iterable[str], read: Callable[[str], str]) -> list[str]:
    """Every layout error in `paths` (repo-relative). `read` returns a file's text."""
    luau = sorted(p for p in paths if p.startswith("src/") and p.endswith(".luau"))
    features = {feature for p in luau if (feature := _feature_of(p))}
    errors: list[str] = []
    for path in luau:
        errors.extend(_check_one(path, features, read))
    return errors
