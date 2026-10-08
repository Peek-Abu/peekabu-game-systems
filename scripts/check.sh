#!/usr/bin/env bash
# Local mirror of the CI lint + format + type-check jobs (everything except the cloud Tests job).
# Reproduces the lint, format, and typecheck steps in .github/workflows/ci-cd.yml 1:1, so you can
# catch every non-test failure before pushing.
#
#   ./scripts/check.sh                 # lint + format-check + type-check (runs `wally install`)
#   ./scripts/check.sh --skip-install  # skip `wally install` (faster; only if link files are fresh)
#
# Requires the rokit toolchain (run `rokit install` once): selene, stylua, rojo, wally,
# wally-package-types, luau-lsp. On Windows, run via Git Bash: `bash scripts/check.sh`.
#
# Only the **Tests** job genuinely needs the cloud (Open Cloud Luau Execution). Run TestEZ in
# Studio via ServerScriptService/TestRunner.server.luau for a local test confirmation.
set -euo pipefail

cd "$(dirname "$0")/.."

skip_install=false
[ "${1:-}" = "--skip-install" ] && skip_install=true

echo "==> Lint (selene)"
selene src

echo "==> Format check (stylua)"
stylua --check src

echo "==> Type check (luau-lsp analyze)"
# luau-lsp needs the DataModel sourcemap, package type exports, and Roblox global defs first.
# `wally install` runs by default: wally-package-types requires valid package link files, and
# those go stale/malformed otherwise ("'REQUIRED_MODULE' is not a function call"). Pass
# --skip-install to skip it when you know the links are fresh.
if [ "$skip_install" != true ] || [ ! -d Packages ]; then
	echo "    wally install (regenerating package link files)"
	wally install
fi
rojo sourcemap default.project.json --output sourcemap.json
# `if` (not `[ -d ] && ... || true`): skip an absent realm, but let a REAL wally-package-types
# failure fail the script instead of being swallowed (mirrors CI).
wally-package-types -s sourcemap.json Packages/
if [ -d ServerPackages ]; then wally-package-types -s sourcemap.json ServerPackages/; fi
if [ -d DevPackages ]; then wally-package-types -s sourcemap.json DevPackages/; fi
# Pinned to the same luau-lsp release as rokit.toml (mirrors CI). Bump the tag together with
# rokit.toml's luau-lsp entry, and delete the local globalTypes.d.luau so it re-downloads.
if [ ! -f globalTypes.d.luau ]; then
	echo "    downloading Roblox global type definitions"
	curl -fsSL "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.68.1/scripts/globalTypes.d.luau" -o globalTypes.d.luau
fi
# Spec files are excluded: they rely on TestEZ globals (describe/it/expect). Everything else must be
# clean. `tasks/` is included alongside `src` (mirrors CI): runTests.luau is the CI test entry point.
luau-lsp analyze \
	--sourcemap=sourcemap.json \
	--definitions=globalTypes.d.luau \
	--ignore="**/*.spec.luau" \
	src tasks

echo "==> Project rules (added lines vs origin/main)"
# Encodes rules that previously lived only in AGENTS.md and reviewers' memories: no `any` casts in
# production, no Co-Authored-By/Claude-Session commit trailers, no placeholder currencies. Only
# ADDED lines are judged — a ratchet on new work, not a demand to fix the past. Skipped when
# origin/main isn't fetched (a fresh clone with no remote), since CI always has it.
if git rev-parse --verify --quiet origin/main >/dev/null; then
	python3 scripts/python/check_pr_rules.py origin/main
else
	echo "    origin/main not available locally — skipping; CI runs this gate."
fi

echo ""
echo "==> File length (code lines per module)"
# Counts CODE lines only — doc comments explain WHY and have caught real bugs in review, so a raw
# line cap would reward deleting them. Spec files are exempt. See the script's docstring.
python3 scripts/python/check_file_length.py

echo ""
echo "==> Module map (docs/project-structure.md matches src/)"
python3 scripts/python/module_map.py --check

echo ""
echo "==> Python unit tests"
# The layout rules, the module-map generator and (while the move runs) the mover are tested like
# first-party code: a regex that silently stopped matching would let the layout drift.
python3 -m unittest discover -s scripts/python -p "test_*.py"

echo ""

echo "==> Python scripts lint (ruff)"
# Mirrors CI's scripts-lint job. Ruff isn't rokit-managed (it's a Python tool), so unlike the
# checks above this one degrades to a warning when ruff isn't installed — CI still gates it.
if command -v ruff >/dev/null 2>&1; then
	ruff check scripts/python
elif python3 -m ruff --version >/dev/null 2>&1; then
	python3 -m ruff check scripts/python
else
	echo "    ruff not installed (pip install ruff) — skipping locally; CI runs this gate."
fi

echo ""
echo "==> All checks passed."
