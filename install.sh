#!/bin/bash
set -euo pipefail

# Install the EXACT toolchain pinned in rokit.toml (rojo, wally, wally-package-types, selene,
# stylua, luau-lsp). Do NOT use `rokit add` here: it re-resolves to the latest version and rewrites
# rokit.toml, breaking the version pinning that keeps local tools matching CI — and it would only
# touch the three tools named, leaving selene/stylua/luau-lsp uninstalled.
rokit install

# Order matters: wally install writes the package link files that wally-package-types reads, and the
# sourcemap must exist before generating type exports.
wally install
rojo sourcemap default.project.json --output sourcemap.json

# Generate package type exports for EVERY realm, not just Packages/. ProfileStore lives in
# ServerPackages/ — without this pass its types resolve as `Unknown` and the data layer goes
# effectively unchecked (mirrors CI and scripts/check.sh).
# `if` (not `[ -d ] && ... || true`): skip an absent realm, but let a REAL wally-package-types
# failure fail the script instead of being swallowed (mirrors CI and scripts/check.sh).
wally-package-types -s sourcemap.json Packages/
if [ -d ServerPackages ]; then wally-package-types -s sourcemap.json ServerPackages/; fi
if [ -d DevPackages ]; then wally-package-types -s sourcemap.json DevPackages/; fi

rojo build -o peekabu-game-systems.rbxl default.project.json
