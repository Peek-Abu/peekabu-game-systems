"""Fail the build when a first-party Luau module grows past the code-line limit.

WHY CODE LINES, NOT TOTAL LINES: this codebase's doc comments explain *why* — the rollback
rationale in `mutate`, the mirror-gate reasoning, "do not simplify SlotState back into a scalar".
Reviewers have repeatedly used those comments to catch real bugs. A raw line-count cap would create
a perverse incentive: delete the explanation, pass the gate. So block comments (``--[=[ ]=]``), line
comments, and blank lines do not count against the limit.

SPEC FILES ARE EXEMPT: a spec is long because it lists cases, and capping it would push us toward
*fewer tests* — the opposite of what we want.

THE ALLOWLIST IS A DEBT LEDGER, NOT AN ESCAPE HATCH. Every entry is a file we know is too big, with
the reason and the intended split. It is a ratchet: an allowlisted file that drops back under the
limit FAILS the check, so the entry must be deleted rather than silently lingering. Adding a new
entry should be a deliberate, reviewed decision — not the reflex for making this script quiet.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Ceiling for a single module, in CODE lines (see the module docstring).
MAX_CODE_LINES = 400

# Known oversized files: path -> why it is still here / what the split should be.
# Burn these down; do not grow this table casually.
ALLOWLIST: dict[str, str] = {
    "src/ServerScriptService/Features/PlayerData/PlayerDataServiceServer.luau": (
        "The atomicity core (~680 code lines). mutate / transaction / session lifecycle / path "
        "resolution are four separable concerns, but this is the highest-risk file in the repo. "
        "Splitting it is its own task with its own review — not a side effect of enabling a linter."
    ),
}

BLOCK_COMMENT = re.compile(r"--\[=*\[.*?\]=*\]", re.DOTALL)


def count_code_lines(source: str) -> int:
    """Non-blank, non-comment lines. Block comments are stripped before counting."""
    without_blocks = BLOCK_COMMENT.sub("", source)
    return sum(
        1
        for line in without_blocks.splitlines()
        if line.strip() and not line.strip().startswith("--")
    )


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    failures: list[str] = []

    # Match the "first-party Luau" surface that `scripts/check.sh` type-checks: `src` AND `tasks`
    # (tasks/runTests.luau is the CI test entry point). Gating only `src` would let tasks/ grow
    # unbounded despite being first-party.
    scanned = sorted(
        path
        for base in (root / "src", root / "tasks")
        if base.exists()
        for path in base.rglob("*.luau")
    )
    for path in scanned:
        if path.name.endswith(".spec.luau"):
            continue

        relative = path.relative_to(root).as_posix()
        code_lines = count_code_lines(path.read_text(encoding="utf-8"))
        allowed = relative in ALLOWLIST

        if code_lines > MAX_CODE_LINES and not allowed:
            failures.append(
                f"{relative}: {code_lines} code lines (limit {MAX_CODE_LINES}).\n"
                f"    Split it, or add it to ALLOWLIST in scripts/python/check_file_length.py "
                f"with a reason and the intended split."
            )
        elif code_lines <= MAX_CODE_LINES and allowed:
            # The ratchet: a file that got back under the limit must lose its allowlist entry,
            # or the entry rots into a permanent exemption nobody revisits.
            failures.append(
                f"{relative}: now {code_lines} code lines, under the {MAX_CODE_LINES} limit — "
                f"remove its stale ALLOWLIST entry in scripts/python/check_file_length.py."
            )

    if failures:
        print("File length check FAILED:\n")
        for failure in failures:
            print(f"  {failure}\n")
        return 1

    print(f"    All first-party modules within {MAX_CODE_LINES} code lines "
          f"({len(ALLOWLIST)} allowlisted).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
