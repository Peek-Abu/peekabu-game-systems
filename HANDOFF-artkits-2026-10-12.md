# Handoff — client-office-slate ArtKits install (2026-10-12)

Restart brief for the next agent. User uploaded all 46 models, dumped them into
Place1 at the camera, and asked for the Roblox MCP to be brought up so the agent
can organize them directly. Read this whole file before acting.

## 1. Work contexts (two — do not confuse them)

- **Main repo** `E:\Projects\peekabu-game-systems`, branch
  `claude/clever-dirac-20hjqo`, in sync with `main` (merge PR #1). Shared base
  is complete per `docs/ROADMAP.md` (all 14 systems built). Clean except
  untracked `branding/` (50 PNGs + `urls.json` = 51 files: Icey Studios/Labs
  emblem/cover exploration — **NOT** the 46 below, do not touch).
- **Active work — everything below happens here:**
  `.claude/worktrees/mvp-demo-pack-052599`, branch `game/cleanup-crew`
  (Cleanup Crew game). Uncommitted modular-art work in progress (Art feature
  modules, Office/Cargo integration, docs). Plan: `PLAN-modular-art.md`.
  Gates: `gates/modular-art/{integration,kit-runtime,map-integration,art-catalog}.md`.

## 2. The 46 uploads (facts, all verified 2026-10-12)

- Batch: `design/production-art/map-kits/client-office-slate/upload-batch.json`
  — **46 Model uploads**, owner Icey Labs group **189923277**, names
  `Cleanup Crew <family> <key>`. `deskCalendar` explicitly excluded.
- Source: `manifest.json` — 47 assets (46 + deskCalendar), 30,040 triangles.
- Disk hashes re-verified **46/46 match** batch `sha256`; 47 GLBs on disk
  (extra = deskCalendar, not for upload).
- User state: all 46 uploaded to **Asset Manager folder `Office-slate`** and
  inserted into **Place1, dumped at camera, unorganized**. Nothing renamed yet.

## 3. Roblox MCP (configured, NOT yet active)

- Added `roblox-studio` local MCP server to global
  `C:\Users\Bruk Abu\.config\opencode\opencode.jsonc`:
  `StudioMCP.exe` at
  `C:/Users/Bruk Abu/AppData/Local/Roblox/Versions/version-9b554450a0fc4e65/StudioMCP.exe`
  (verified on disk; same binary the prior Codex session drove Studio with —
  see `tmp/codex-mcp/studio-tools.json`, `client.mjs`, `register.py`).
- **User was told to quit + restart opencode** (config loads once at start).
  This session never had Studio tools. After restart, first prove the bridge:
  list tools, `list_roblox_studios`, confirm Place1's studio instance.
- Caveat told to user: exe path is **Roblox-version-pinned**; after a Studio
  auto-update it breaks — repoint at newest `Versions/version-*/StudioMCP.exe`
  (an older copy already exists under `version-76e1a02649ad4f35`).
- Studio must be open with Place1; tools take a `studio_id`.

## 4. Target layout + contract (what "organized" means)

- Path: `ReplicatedStorage.Assets.CleanupCrew.ArtKits["client-office-slate"].<family>.<key>`
  (folders + Models; exact key spelling per
  `src/ReplicatedStorage/Shared/Features/Art/Data/ArtKitRegistry.luau:11-65`).
  Leave `props/deskCalendar` **missing** (fallback behavior is expected/tested).
- Per template (`src/ReplicatedStorage/Shared/Features/Art/Rules/ArtKitRules.luau:26-88`,
  `src/ServerScriptService/Features/Art/Systems/ArtVisualSystem.luau:39-53,91-94`):
  `RuntimeApproved=true`, `BaseSize` Vector3 from `manifest.json` (must match
  bbox within 1%+0.01, pivot bottom-centred), `OpeningWidth=2.78` on
  `building/wallDoorway` only, `FitMode=Stretch` on `furniture/desk` only
  (never Uniform on building), no tags/scripts/humanoids/prompts in templates.
- Fallback script (use only if MCP bridge fails):
  `design/production-art/map-kits/client-office-slate/OrganizeArtKits.CommandBar.luau`
  — generated from batch+manifest (46 placements), run once in Studio command
  bar, Edit mode. User already has run instructions from prior turn.

## 5. Gates pending (do not claim shipped integration)

- `gates/modular-art/integration.md`: G2 (isolated TestEZ green + persistent
  native client/cargo lifecycle) and G4 (production persistence/owner approval)
  open. Baseline: isolated TestEZ **2,215 passed / 0 failed** on local-only
  templates; local EditableMesh previews were removed from production and
  isolated under `ServerStorage.CodexLocalReviewArtKits` — see
  `design/production-art/map-kits/client-office-slate/NATIVE-VERIFICATION.md`.
- `gates/modular-art/map-integration.md` G3: instance specs written, **Studio
  execution parent-owned/pending**.
- Verification after organize: `rojo serve` worktree → isolated `RunTests=true`
  Play (expect 0 failed) → normal Play (art attached ≈166 models, all 13 cargo
  attach/hide/reveal+grips, carry/load on client). Update gate evidence +
  `NATIVE-VERIFICATION.md` only from observed results.

## 6. Guardrails (from `PLAN-modular-art.md` / `AGENTS.md`)

- Parent (user) owns Studio/Figma. No asset/place publish, no paid assets.
- `ReplicatedStorage` has `$ignoreUnknownInstances: true` — Rojo will not
  delete `Assets/`; keep it that way.
- `--!strict`, no `any`/casts, spec-first, plain commit messages, merge
  commits never squash. No code changes needed for the organize itself.

## 7. First actions after restart (in order)

1. `list_roblox_studios` → confirm Place1 instance; list Studio tools.
2. Organize the 46 via MCP (preferred) or confirm user ran the command-bar
   script; report `organized/missing/warnings`.
3. Run §5 verification; update G2/G4 evidence.
4. Report back: TestEZ counts, any key on fallback, whether Place1 is the
   real art-bearing place or a scratch place needing an `Assets` copy.

## 8. Orientation verdict (2026-10-13, applied live — read-first)

- Place1 = the **"Untitled Experience-Clean"** Studio instance
  (`9c030d65-679f-4db2-a779-3eeed8da5dcf`; other running studios had no kit).
  Bridge used directly, no restart needed:
  `F:\Dev\temp\opencode\studio-bridge.mjs`
  (`call execute_luau <argsFile>`; args JSON = `{studio_id, datamodel_type, code}`).
- Audit found all 46 templates organized, but as **single-part merged meshes**
  (`Cube.*`), and all furniture/cargo but desk+locker stamped
  `FrontAxis=PositiveZ` — with the flip active, shelf/filingCabinet/monitor/
  officeChair/kitchenCounter rendered 180° off.
- Binary test: shelf → `NegativeZ` = FIXED. So the imported geometry is −Z
  in Studio (importer remaps the +Z source); **all 24 `PositiveZ` stamps were
  wrong**. Flipped all of them (plus shelf) to `NegativeZ`; desk+locker kept.
  User to confirm the other four in Play (attach reads flags at build time —
  must rebuild/rejoin to see it).
- `OrganizeArtKits.CommandBar.luau:175` heuristic (`PrototypeComponents` →
  `NegativeZ` else `PositiveZ`) is therefore INVERTED for this kit and must be
  replaced with an explicit per-key table before any re-import. Runtime ignores
  `PrototypeComponents`; only `FrontAxis` matters.
