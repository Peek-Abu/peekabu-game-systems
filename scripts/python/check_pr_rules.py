"""Enforce this project's non-negotiable rules on the lines a change ADDS.

Every rule here comes from a bug that actually reached review, not from a style opinion:

* **Casts.** ``--!strict`` with no casts is a stated project rule, previously enforced only by
  someone remembering it. A ``::`` cast is how a flat, pre-slot spec fixture hid from the type
  checker and crashed at runtime — twice. A cast may still be right; it just has to be *argued* in
  a comment at the site, which is exactly the sign-off the rule asks for.
* **Commit trailers.** "Plain commit messages, no ``Co-Authored-By:`` / ``Claude-Session:``" is a
  stated rule with zero enforcement. One careless agent run puts it in the history permanently.
* **Asset-id scatter.** The old game kept animation ids in six-plus places (registry tables, two
  Animate forks, 445 ``Animation`` instances as tree data, hardcoded strings in ~75 scripts) — not
  by choice, but because nothing stopped it. Asset-id literals (``rbxassetid://N`` and the legacy
  URL form) are allowed ONLY in registry modules: each feature's ``Data/`` folder
  (``ASSET_ID_FEATURE_DATA``) and spec fixtures. This one is a WHOLE-TREE
  invariant, not an added-lines ratchet: when the rule landed (Phase 6) every id in src/ already
  lived in a registry, so there is no past to grandfather.
* **UI anti-patterns (Phase 7).** Three whole-tree invariants that keep the React UI framework from
  rebuilding the old game's mistakes: (1) ``Instance.new("ScreenGui")`` only in ``UILayerHost`` — every
  UI root is owned by a layer, so the ``ResetOnSpawn``-direct-PlayerGui-child rule lives in one place;
  (2) no ``.Enabled``/``.Visible`` assignment in ``Client/UI/`` — screen visibility is DERIVED from
  state (conditional render), never commanded; (3) no ``:FireServer``/``:InvokeServer``/ByteNet send
  from ``Client/UI/React/`` — components render, services do I/O. All three were clean when the rule
  landed, so there is no past to grandfather.
* **Module layout (issue #37).** Whole-tree invariants from ``layout_rules.py``: placement, depth,
  feature prefix, role word, one service per feature, command names, UI names. The move left the
  tree compliant, so there is no past to grandfather. The allowed subfolders, role words and service
  exceptions live in that module; changing them is a rule change that needs the developer's approval.

Scope: only ADDED lines, diffed against a base ref (except the asset-id rule, whole-tree as noted).
Pre-existing code is not re-litigated — this is a ratchet on new work, not a demand to fix the past.

Usage:  python3 scripts/python/check_pr_rules.py [base_ref]     (default: origin/main)
"""

from __future__ import annotations

import re
import subprocess
import sys

import layout_rules

# A cast to `any` in production code is the hard error — `any` is banned outright.
CAST_TO_ANY = re.compile(r"::\s*any\b")
# Any other `::` cast wants a justification comment at the site. Match `::` + any non-space so a
# cast to a table type (`:: { ... }`) or function type (`:: (...) -> ()`) is caught too — a `\w`-only
# pattern silently missed those. `::` is only ever the cast operator in Luau, so this is unambiguous.
CAST = re.compile(r"::\s*\S")
# `-- selene:` / `-- stylua:` are tool directives, not justifications.
JUSTIFICATION = re.compile(r"--(?!\s*(?:selene|stylua):)\s*\S")
BANNED_TRAILERS = ("Co-Authored-By:", "Claude-Session:")
# An asset-id LITERAL: either form with actual digits. Digit-less doc mentions ("rbxassetid://N")
# deliberately don't match — prose about the convention is not an id.
ASSET_ID = re.compile(r"(?:rbxassetid://|roblox\.com/asset/\?id=)\d+")
# Asset-id literals may live only in registries: every feature's `Data/` folder (issue #37 layout).
ASSET_ID_FEATURE_DATA = re.compile(r"^src/(?:ReplicatedStorage/(?:Shared|Client)|ServerScriptService)/Features/[^/]+/Data/")

# --- Phase 7 UI anti-pattern gates (whole-tree invariants) ---
UI_TREE = "src/ReplicatedStorage/Client/UI/"
# The client services that OWN UI lifecycle (they acquire layer roots and mount the React trees) live
# outside Client/UI/, so a gate scoped to that prefix alone cannot see the two modules best positioned
# to commit the anti-pattern — they already hold the layer references. Scoped to exactly those two
# features: other client features (VFX emitters and lights, for one) toggle `.Enabled` on world
# instances, which is not UI visibility.
UI_LIFECYCLE_TREES = (
    "src/ReplicatedStorage/Client/Features/UI/",
    "src/ReplicatedStorage/Client/Features/Debugger/",
)
UI_REACT_TREE = "src/ReplicatedStorage/Client/UI/React/"
# The single module allowed to new a ScreenGui and own layer-root instances: the layer factory shell.
UI_LAYER_HOST = "src/ReplicatedStorage/Client/UI/Layers/UILayerHost.luau"
# `Instance.new("ScreenGui")` / `Instance.new('ScreenGui')`, tolerant of inner whitespace.
SCREENGUI_NEW = re.compile(r"""Instance\.new\(\s*["']ScreenGui["']""")
# `.Enabled =` / `.Visible =` ASSIGNMENT (not `==`, `~=`, `>=`, `<=`). The leading dot means a React
# prop (`Visible = x`, no dot, inside a createElement table) is NOT matched — only instance mutation.
IMPERATIVE_VISIBILITY = re.compile(r"\.(?:Enabled|Visible)\s*=(?!=)")
# A React component reaching the server directly: RemoteEvent/Function or a ByteNet packet send.
REACT_REMOTE_CALL = re.compile(r":FireServer\b|:InvokeServer\b|\.packets\.")


def run(*args: str) -> str:
    # Force UTF-8 decoding of git output. Without it, Python uses the locale codec (cp1252 on
    # Windows), which crashes on the UTF-8 em-dashes/ellipses this codebase's diffs are full of —
    # the check then dies locally while passing in CI (Linux defaults to UTF-8). errors="replace"
    # keeps a stray undecodable byte from aborting a rule scan.
    return subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        check=True,
        encoding="utf-8",
        errors="replace",
    ).stdout


def added_lines(base: str) -> dict[str, list[tuple[int, str]]]:
    """Return {path: [(line_no, text)]} for the lines this branch ADDS."""
    # A `...` diff needs the merge-base commit. A shallow clone may not contain it — fail with a
    # clear, actionable message instead of a raw CalledProcessError traceback.
    try:
        diff = run("diff", "-U1", f"{base}...HEAD")
    except subprocess.CalledProcessError as error:
        print(
            f"could not diff against {base} (exit {error.returncode}). If this is CI, the checkout "
            f"needs full history: set `fetch-depth: 0` on actions/checkout for this job.",
            file=sys.stderr,
        )
        raise SystemExit(2) from error
    files: dict[str, list[tuple[int, str]]] = {}
    path: str | None = None
    line_no = 0
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            path = line[6:]
            files.setdefault(path, [])
        elif line.startswith("@@"):
            match = re.search(r"\+(\d+)", line)
            line_no = int(match.group(1)) if match else 0
        elif path and line.startswith("+") and not line.startswith("+++"):
            files[path].append((line_no, line[1:]))
            line_no += 1
        elif path and not line.startswith("-"):
            line_no += 1
    return files


def asset_id_scatter() -> list[str]:
    """Whole-tree scan: asset-id literals outside registry land are errors."""
    errors: list[str] = []
    tracked = run("ls-files", "src").splitlines()
    for path in tracked:
        if not path.endswith(".luau") or ASSET_ID_FEATURE_DATA.match(path):
            continue
        # Spec files are exempt for the same reason they are exempt from the cast rules: fabricated
        # ids (`rbxassetid://1`) are the fixture idiom, and flagging them trains everyone to ignore
        # this check.
        if path.endswith(".spec.luau"):
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                for line_no, text in enumerate(handle, start=1):
                    if ASSET_ID.search(text):
                        errors.append(
                            f"{path}:{line_no}: asset-id literal outside a feature's Data/ folder "
                            f"— ids live in a registry, "
                            f"nowhere else (the six-id-sources disease, Phase 6 spec Decision 1).\n"
                            f"        {text.strip()}"
                        )
        except OSError:
            # Deleted-but-still-listed during odd worktree states; the diff rules still ran.
            continue
    return errors


def _iter_luau(prefix: str | tuple[str, ...]):
    """Yield (path, line_no, text) for tracked, non-spec .luau files under `prefix`."""
    for path in run("ls-files", "src").splitlines():
        if (
            not path.startswith(prefix)
            or not path.endswith(".luau")
            or path.endswith(".spec.luau")
        ):
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                for line_no, text in enumerate(handle, start=1):
                    yield path, line_no, text
        except OSError:
            continue


def screengui_outside_layers() -> list[str]:
    """Whole-tree: a ScreenGui may only be created by the layer factory shell (UILayerHost)."""
    errors: list[str] = []
    for path, line_no, text in _iter_luau("src/"):
        if path == UI_LAYER_HOST or not SCREENGUI_NEW.search(text):
            continue
        errors.append(
            f'{path}:{line_no}: `Instance.new("ScreenGui")` outside UILayerHost. Every UI root is '
            f"owned by a layer (UILayers), so the ResetOnSpawn-must-be-a-direct-PlayerGui-child rule "
            f"lives in exactly one place (Phase 7 spec Decisions 2 + 7).\n        {text.strip()}"
        )
    return errors


def imperative_visibility() -> list[str]:
    """Client/UI/: screen visibility is derived from state, not set with `.Enabled`/`.Visible`."""
    errors: list[str] = []
    for path, line_no, text in _iter_luau((UI_TREE, *UI_LIFECYCLE_TREES)):
        # UILayerHost owns layer-root instances; comment lines aren't code.
        if path == UI_LAYER_HOST or text.lstrip().startswith("--"):
            continue
        if IMPERATIVE_VISIBILITY.search(text):
            errors.append(
                f"{path}:{line_no}: assigns `.Enabled`/`.Visible` in UI code. Visibility is DERIVED "
                f"from reactive state (render conditionally / pass `Visible` as a prop), never "
                f"commanded by mutating an Instance (Phase 7 spec Decisions 3 + 7).\n"
                f"        {text.strip()}"
            )
    return errors


def remote_calls_in_react() -> list[str]:
    """Client/UI/React/: components render; they never talk to the server directly."""
    errors: list[str] = []
    for path, line_no, text in _iter_luau(UI_REACT_TREE):
        if text.lstrip().startswith("--"):
            continue
        if REACT_REMOTE_CALL.search(text):
            errors.append(
                f"{path}:{line_no}: a React component reaches the server directly "
                f"(:FireServer / :InvokeServer / ByteNet `.packets.`). Components render; a service "
                f"does the I/O and writes StateSyncClientStore (Phase 7 spec Decision 7).\n"
                f"        {text.strip()}"
            )
    return errors


def layout_errors() -> list[str]:
    """Whole-tree: every module sits where docs/project-structure.md says and is named for it."""

    def read(path: str) -> str:
        with open(path, encoding="utf-8") as handle:
            return handle.read()

    return layout_rules.check_layout(run("ls-files", "src").splitlines(), read)


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    files = added_lines(base)
    errors: list[str] = [
        *asset_id_scatter(),
        *screengui_outside_layers(),
        *imperative_visibility(),
        *remote_calls_in_react(),
        *layout_errors(),
    ]
    warnings: list[str] = []

    for path, lines in files.items():
        if not path.endswith(".luau"):
            continue

        # Spec files are exempt from the cast rules. They are intentionally untyped, and a cast
        # like `testSlice.get("bad" :: any)` is the IDIOM for proving a guard rejects bad input —
        # flagging it would train everyone to ignore this check, which is worse than no check.
        is_spec = path.endswith(".spec.luau")

        for line_no, text in lines:
            if not is_spec and CAST_TO_ANY.search(text):
                # `any` is banned outright in production code. This is the hard rule.
                errors.append(
                    f"{path}:{line_no}: cast to `any` in production code. Fix the type, not the "
                    f"symptom.\n        {text.strip()}"
                )
            elif not is_spec and CAST.search(text) and not JUSTIFICATION.search(text):
                # Other casts may be legitimate but need an argument at the site. A warning, not an
                # error: the justification often lives in a doc block above, which no regex can
                # reliably find — a human reads this and decides.
                warnings.append(
                    f"{path}:{line_no}: `::` cast with no comment on the line. The no-casts rule "
                    f"wants a justification at the site.\n        {text.strip()}"
                )

    for message in run("log", "--format=%B", f"{base}..HEAD").splitlines():
        for trailer in BANNED_TRAILERS:
            if message.startswith(trailer):
                errors.append(f"commit contains a banned trailer: {message.strip()}")

    touched_src = [p for p in files if p.startswith("src/") and p.endswith(".luau")]
    if touched_src and not any(p.endswith(".spec.luau") for p in touched_src):
        warnings.append(
            "touches src/ but changes no .spec.luau — spec-first TDD is the project rule. "
            "If this is deliberate (a pure comment/doc change), ignore."
        )

    for warning in warnings:
        print(f"  WARN  {warning}\n")
    for error in errors:
        print(f"  FAIL  {error}\n")

    if errors:
        print(f"PR rules FAILED against {base}: {len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    print(f"    PR rules passed against {base} ({len(warnings)} warning(s)).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
