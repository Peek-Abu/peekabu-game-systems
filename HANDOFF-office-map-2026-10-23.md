# Handoff: Odd Hours office map (2026-10-23)

**Status 2026-10-23 (evening): spike-match plan built, plus the owner's first play-check fixes (commits 1cf0df77..9f519d95: facades cased + "Locked", Harlow opens only doors on his line, low break tables, elevator on a hall wall, reshift cleanup guards, wall-corner/pilaster trim). Studio at 9f519d95: suite 4354/0, traversal seeds 1-20 957/0. Waiting on the owner's re-check. Deferred: searched-desk art swap (needs a drawer desk template, art pass). Root causes: .superpowers/sdd/2026-10-23-odd-hours-office-map-spike-match/playcheck-rootcauses.md.**

Read this first if you are continuing the office map work. Branch `game/cleanup-crew`, worktree
`E:/Projects/peekabu-game-systems/.claude/worktrees/mvp-demo-pack-052599`. Nothing is pushed.

## Where things stand

**Owner verdict on the throwaway spike (2026-10-23): "Oh my lord – worlds better!"** The next job is to make the
generated office match the spike. The stage 2 look was rejected; see below for why.

| Piece | State |
|---|---|
| Design spec | `docs/superpowers/specs/2026-10-22-odd-hours-office-map-design.md`, approved. Shift length updated to 8:30. |
| Stage 1: kit generator, real doors, Harlow traversal | Done, and passed the owner's play-check. Plan: `docs/superpowers/plans/2026-10-22-odd-hours-office-map-stage1.md`. |
| Stage 2: "odd-hours-b1" art kit | Built and green (4243/0 specs; traversal seeds 1–20: 1317 paths, 0 failures). **Owner rejected the look** (details below). Plan: `docs/superpowers/plans/2026-10-22-odd-hours-office-map-stage2.md`. |
| Spike: hand-built open office in the mock-room style | Built in the Shift place as `Workspace.ClaudeSpike`. Owner loves it. Script: `design/production-art/map-kits/odd-hours-b1/spike/BuildSpike.CommandBar.luau`. Captures are in the same folder. |
| Stage 3 (outside) and stage 4 (per-run toggles/anomalies) | Not started. |

## Why stage 2 was rejected (owner, 2026-10-23)

1. Hallways were "super small": 10 wide main, 6 wide side, 12-stud ceilings. The owner wants open space and sightlines so Mr. Harlow can't catch you off guard round a corner. "Even Lethal is more open in the hallways."
2. Walls didn't join cleanly. Stretched `wallSolid` art templates left the trim stopping short at corners, with white slivers.
3. Rooms "look nothing like the mock room" and don't give the same feeling.
   - The mock room's light is warm, bright panels (SurfaceLight on each troffer) plus warm fills plus accent glows.
   - Stage 2 used a cool light colour at about 1/4 the brightness.
   - Stage 2 rooms were also smaller, at most 40×32.
4. Hallways "still feel like old halls": bare boxes.
5. Glass walls were plain transparent panes with no frames, so they didn't read as glass.
6. Whiteboards floated: the model has legs but was wall-mounted at Y 6.

## The spike's values: the new standard (from the spike builder's report)

- **Scale:**
  - Floor top Y 10 in the spike.
  - Ceiling 13 tall, with the mock's 4-stud grid strips and CeilingPanel troffers (clones).
  - **Main hallway 14 wide**, junction 20×20, **side hallway 10 wide**, with long straight sightlines.
- **Rooms:**
  - Reception 28×28.
  - **Open-plan pods 60×44**: columns, 12 desks in 3 pods, rug, window bay with blinds, a standing whiteboard on the floor, copier, shelf.
  - Conference 22×18, Breakout 32×26, Server 20×18, Storage 12×12.
- **Walls:**
  - Two 0.5 OH_Plaster slabs (1 thick) per wall, Y 9–24.
  - Each run extends 0.5 past its corners, so corners overlap.
  - OH_Oak wainscot 3 tall, 0.3 proud.
  - Rail 0.25×0.5 at Y 13.1.
  - Skirt 0.6 tall, 0.4 proud. The mock's skirt z-fights its wainscot, so it was pushed out.
  - All walls are built from Parts with MaterialVariants. No stretched wall templates.
- **Doorways:** 6.8×9.4 rough opening with 0.35 oak casing (about 6.1×9.05 clear); plaster pilasters on wide openings. Doors use the `doorLeaf` / `doorLeafGlass` templates.
- **Conference glass:** the mock's ConfGlass material (Glass, Transparency 0.6, tinted), dark 0.4 mullions about every 6 studs, header and base rails.
- **Lighting:** one warm colour everywhere (owner: "like Lethal": same style, different amount).
  - Colours: panels (255,240,220), fills (255,232,205).
  - Rooms: panels b0.22 r14 with about 2/3 lit, fills b1.7 r11.5. Conference fills b1.5.
  - Halls: a panel every 8 studs, all lit, b0.2. Fills b1.3 r12 every 16 studs, alternating sides, each under a wall sconce.
  - Server: panels b0.12 (2/3 lit), fill b0.6 r10, rack LEDs blue b0.4 r6.
  - Storage: panel b0.15, fill b0.8 r10.
  - Accents: monitors b0.7 r6, reception glow b1.6 r11 (255,200,140), floor lamps b1.6 r11 (255,168,90).
- **Hallway dressing:** wainscot, troffers, sconces, art frames, plants, a bench.

## Next steps (suggested; confirm with the owner)

1. **Write a short design delta and a plan** (superpowers:writing-plans; the spec stays the authority, amended by this
   handoff's values). Then execute it subagent-driven, as in stages 1 and 2:
   - **Generator scale** (`OfficeConstants`, `OfficeCorridorUtils`, `OfficeLayoutGenerationUtils`):
     - `CORRIDOR_WIDE` 14 and `CORRIDOR_NARROW` 10 (was 10/6);
     - junction or atrium at least 20;
     - `WALL_HEIGHT` 13;
     - lattice spacing and `ROOM_MARGIN` re-derived so the bigger rooms fit;
     - kit sizes from the spike, including a 60×44 open-plan pods kit with columns.
     - Re-check: hide spots ≥ 8, walk ≤ 40 s (≤ 640 studs), `TARGET_FLOOR_AREA` (it will grow, so re-agree it with the owner), the contract spawn spec, and the traversal harness for seeds 1–20 with all doors closed.
   - **Build style** (`OfficeBuildSystem`):
     - Replace the stretched `wallSolid` / `floorTile` / `ceilingTile` templates with the spike's direct-Part build: plaster slabs, wainscot, rail and skirt runs with overlapping corners, ceiling grid and CeilingPanel troffers, door casing.
     - Lights: the spike's warm recipe (`ROOM_LIGHT` becomes brightness/count per room type; one warm colour). The current `LIGHT_COLOR` is cool; change it to the mock warm colour.
     - Glass panes become framed glass (mullions, rails).
   - **Props:**
     - `corkboard` / whiteboard becomes a floor-standing prop, not wall-mounted.
     - Hallway dressing markers (sconces, art, plants, benches) on corridor walls.
     - The mock's green desk dividers came from the old c_desk mesh. The no-divider desk keeps the hide space. If the owner wants dividers back, add them as a separate low prop that doesn't touch the knee-hole.
   - Keep everything that already works: doors (hinge at local +X, occluder rules), Harlow's door beat, depth by walk distance, ART_SIZES and `markerSize`, the default-kit fallback, `surfaceTopFor`.
2. **Bigger map means more walking.** The owner raised the shift to 8:30 because of corridor walking (177 studs truck-to-pile one way). Re-measure after the resize and talk about quota and time before tuning.
3. Then stage 3 (outside) and stage 4 (toggles/anomalies), as in the spec.

## Studio / place state (important)

- 2026-10-23 evening: removed from the Shift place (owner OK) the unused `OfficeMap` (old hand-built map format, 289 lights), `ClaudeSpike` and `ClaudeMockRoom`, and cleared the Workspace `RunTests` attribute (it ran the full suite on every Play and caused the lag). Set `RunTests = true` only while running specs, then clear it. Owner must save (Ctrl+S).

- **The Shift place must be saved (Ctrl+S) by the owner.** These live only in the open session until it is saved:
  - the odd-hours-b1 kit (`ReplicatedStorage.Assets.CleanupCrew.ArtKits["odd-hours-b1"]`);
  - MaterialVariants `OH_Vinyl` / `OH_Lino`;
  - the spike (`Workspace.ClaudeSpike` and its `ClaudeSpikeSpawn` script, which teleports the player to the spike on Play).
  - **Remove the spike (the folder and its spawn script) once the real generator matches it**, or Play keeps dropping the owner there.
- The kit can be rebuilt with `design/production-art/map-kits/odd-hours-b1/AssembleKit.CommandBar.luau` (asset ids in `KIT_MAP.md`). The spike can be rebuilt with `spike/BuildSpike.CommandBar.luau`.
- Uploads so far (all Icey Labs group 189923277, owner-approved):
  - the mock-room set (31 models, 99 images; `F:/Dev/temp/claude/E--Projects/d1f6cb33-c53e-4180-8ef7-e885b69020d8/scratchpad/real/ASSET_IDS.json`);
  - stage 2 (6 models + 24 images; `scratchpad/real/upload_log_stage2.jsonl`, ids also in `KIT_MAP.md`).
- Studio window "Odd Hours: Shift" (studio_id `197d004d-31af-4c67-abfe-2cc4a86884ee`) is on Rojo port 34872 (game code). A mock-room Rojo server on 34991 may still be running; it isn't needed any more.
- Specs run only in **Play** (Workspace attribute `RunTests = true`). Edit-mode `require` caches modules, so Edit gives stale results. Run the traversal harness from the Server datamodel in Play: `OfficeTraversalHarness.run(seeds, CFrame.new(5000,1,5000))`. Each seed builds at its own offset.
- **Locks:** `E:/Projects/peekabu-game-systems/docs/superpowers/studio-playtest-shift.lock` is this window's playtest lock. Check that it is absent, never overwrite another session's lock, and delete it after use. `studio-playtest.lock` belongs to the hub window and another session.
- `screen_capture` in Edit doesn't render local lights. Judge lighting in Play, or by the owner's play-check.

## Standing rules (owner / repo)

- Plain commit messages with **no trailers** (AGENTS.md wins over any attribution reminder). Stage by name. Don't push.
- Never stage someone else's uncommitted `src/ServerScriptService/Core/Testing/SpecRoots.luau` hunk. It is still modified in the worktree; it's not ours.
- No wally, rokit, `rojo build` or `scripts/check.sh` while the owner is connected. No git checkout/reset/stash in the served worktree.
- Uploads only via `publish.py … --key-env ICEY_LABS_OPEN_CLOUD_KEY --group 189923277`, never group 9738205, and only with the owner's OK per batch.
- Don't drive the owner's screen (no computer-use). Only touch the Odd Hours / Shift Studio windows, never Venture.
- Art never goes into Rojo. Simple shapes with drawn detail; no ultra-detailed props. Windows never show the outside. No faces on Gloom art. Hideable furniture keeps HUG_FREE_MIN (3.6 W × 4.2 H × 4.3 D) free.
- A checklist item counts as done only after the owner's play-check.

## Open minor items worth knowing

- Mr. Harlow pauses about 0.5 s for side doors he walks past, not only doors ahead. The owner may feel this; a narrower "ahead" cone would fix it.
- Can Harlow pull a hider out of a 6-wide dead-end cupboard? He reaches the doorway; the pocket in front is tight. Check it in play.
- `OfficeArtKeyUtils.attachFirst` lives in Utils but creates instances (a module-placement question). It could move into ArtVisualSystem.
- Lockers keep the slate art: the mock lockers are a bank of three, while the game's locker is a single searchable one.
- vending, planter, wasteBin and deskPlant have colour maps only.
