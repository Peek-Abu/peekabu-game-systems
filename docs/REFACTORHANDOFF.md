# Venture Refactor — Session Handoff

> Paste/attach this into the new local Claude Code session (opened in
> `C:\Users\Bruk Abu\Documents\Projects\venture-game-systems`). It captures every decision and the
> current state so the new session continues seamlessly. Delete this file when the refactor is
> well underway. **This file is a handoff, not committed project doc.**

## TL;DR — what to do next
The immediate goal is to **inspect the FULL live game** via the Roblox Studio MCP (the previous
session only saw 4 exported scripts, which the user says is a small slice of the game). Then build a
real starting refactor plan. First: get the `Roblox_Studio` MCP connected (see "MCP setup" below),
then walk the actual place hierarchy in the open `VentureTestingPlace` Studio session.

---

## What this project is
Reworking a messy ~5-year-old Roblox game ("Venture", currently on **Knit** + lots of tangled
systems) onto a clean, strongly-typed **game-systems base**. The base was cloned from
`peekabu-game-systems` into this repo, `venture-game-systems`.

- **Repo:** `C:\Users\Bruk Abu\Documents\Projects\venture-game-systems`
- **GitHub:** `Peek-Abu/venture-game-systems` (private), branch `main`, CI green.
- **User:** Peek-Abu (brukabu@gmail.com), Windows, PowerShell primary + Git Bash available.

## Working-style preferences (IMPORTANT — memories live under the OLD project key, won't auto-load here)
- **No `any` / no casts.** Casts need real justification + sign-off; fix the type, not the symptom.
- **Root fixes, not band-aids.** User rejects symptom-level fixes and unverified API claims — verify
  against docs/code, fix the real cause.
- **Commits: NO `Co-Authored-By` / `Claude-Session` trailers.** Plain messages only.
- **Strict Luau `--!strict` everywhere.** TDD: spec-first (`SpecRoots.assertAllModulesSpecced`
  fails the build if a module has no `.spec`). Spec files are intentionally untyped — that's fine.

---

## The base's target architecture (what we're porting TO)
- **ServiceController** — service lifecycle (`init`/`start`/`stop`, topological dep sort). Services
  are **lean annotated-literal** tables: `export type MyService = {...}` + `local MyService:
  MyService = {...}` with methods as fields (no colon-method statements, no `self` casts). Auto-
  discovered by `*ServiceServer` / `*ServiceClient` filename suffix.
- **PlayerDataService** — ProfileStore-backed. All writes go through `mutate()` / `transaction()`
  (atomic, rollback, session-locked). Each domain owns a **profile slice** via
  `PlayerDataSliceSystem.register(slice, default, read, validate?)` → typed `get`/`mutate`/`op`. Per-slice
  invariant validators enforced by the data layer.
- **Reactive state** — server writes mirror into **Charm** `StateSyncServerStore` atoms → **charm-sync**
  ships deltas → client `StateSyncClientStore` atoms (read reactively, incl. React UI). Clients never write
  authoritative state.
- **ByteNet** — typed packets for discrete events / RPCs (NOT queryable state; state goes on the
  charm-sync spine).
- **Guard** — shared runtime validators (`userId`, `positiveAmount`, …).
- **Reference implementations already in the base:** Currency + Inventory services (mirror these
  when porting new domains). Also: in-game Debugger overlay (F4), Cmdr admin commands with a
  fail-closed allowlist, PlayerDataMigrationSystem (schema versioning).

---

## Key decisions already made
1. **Data: WIPE / fresh start.** The old 5-year data (currently **DataStore2**) is disposable —
   delete it. **No migration adapter needed.** New code uses ProfileStore and starts everyone fresh
   from the profile template (ProfileStore uses different keys, so old DataStore2 data is simply
   never read). Keep the base's `PlayerDataMigrationSystem` for FUTURE schema evolution only.
2. **Reuse the EXISTING live prod experience for cutover** (not a new experience). It has many
   places (arenas, etc.) and keeps game passes, dev products, badges, favorites, followers, and
   discovery standing. Since data is disposable, no cross-experience data movement.
3. **Content strategy = partially-managed Rojo.** Code lives in git/Rojo; **art (map, terrain,
   decorated builds) is owned by the Studio place**, edited by non-coder devs (modelers, animators,
   map designers) in Studio/Team Create. Rojo mounts **code containers only** — the project files
   here were reconfigured to drop `Workspace`/`Lighting`/`ServerStorage` mounts so `rojo serve` can
   NEVER overwrite artist content. Uploaded assets (meshes/audio/anims) stay on Roblox, referenced
   by ID via registry modules (like the base's `ItemRegistry`/`ItemContentRegistry`).
4. **No CD.** Publishing a place overwrites the WHOLE place → a code-only build would wipe the map.
   So: CI is **validation-only** (lint/format/typecheck/test); production is deployed **manually**
   from Studio (`rojo serve` code into the art-bearing place, then Publish). The prod deploy job was
   removed from CI; `publish_place.py` is kept for a possible future fully-managed pipeline.
5. **Cutover mechanics:** `rojo serve` into the live art-bearing place + Publish from Studio. This
   **deletes the old Knit scripts** in the code containers (intended — it's the rewrite) and
   **preserves art** in unmounted containers. Watch for old logic hiding in unmounted containers
   (Workspace/ServerStorage) that could conflict.

## Environment model (three tiers)
| Tier | Experience | Who | Data | Deploy |
|---|---|---|---|---|
| **CI** | `Venture[Test]` — universe `10488238788`, place `97354325370574` | Machines only (no humans; Team Create OFF) | Empty/throwaway | Automated (Open Cloud) |
| **Staging/QA** | the place currently named `Venture[Prod]` (rename → `Venture[Staging]`) | Human testers | Separate, wipeable | Manual Studio publish |
| **Live** | existing prod experience (arenas etc.) | Real players | Fresh | Manual Studio publish |

---

## Status of setup (Phases 1–7)
- ✅ **Repo:** cloned, renamed `peekabu-game-systems`→`venture`, code-only project files, git init +
  initial commit, pushed to GitHub.
- ✅ **Toolchain green:** `rokit`/`wally`/sourcemap/type-exports/build all pass; `scripts/check.sh`
  clean (lint + format + typecheck + ruff).
- ✅ **Tests:** 400/400 TestEZ passing in Open Cloud CI. (Fixed one Studio-coupled Admin test:
  extracted pure `Admin.isAdminForSession(userId, isStudio, allowlist?)`.)
- ✅ **CI wired to Venture[Test]:** GitHub secret `ROBLOX_API_KEY` + vars `ROBLOX_TEST_UNIVERSE_ID`
  / `ROBLOX_TEST_PLACE_ID` set. Open Cloud key has `universe-places:write` +
  `luau-execution-sessions:write`, restricted to Venture[Test]. Full pipeline green.
- ✅ **Manual deploy dry-run:** user did `rojo serve` → publish into a fresh published place. Loop works.
- ⛔ **Branch protection:** BLOCKED — GitHub requires **Pro** for branch protection/rulesets on
  PRIVATE repos (free personal account can't). Optional. Payload is ready if they upgrade. For now,
  CI still runs on every push/PR (visible green/red), just no hard "can't merge red" gate.

## Gotchas learned (so the new session doesn't repeat them)
- `rokit install` prompts for tool trust non-interactively → use `rokit install --no-trust-check`
  (same pinned tools as base).
- `wally-package-types` is NOT idempotent — running it twice corrupts link files
  (`'REQUIRED_MODULE' is not a function call`). Run `scripts/check.sh` WITH its `wally install`
  step (not `--skip-install`) so links are regenerated fresh first.
- Open Cloud place upload **409 "Server is busy"** = the place has **Team Create ON** or is **open
  in Studio**. CI target (Venture[Test]) must have Team Create OFF and no one editing it.

---

## Refactor analysis so far (PRELIMINARY — only 4 exported scripts, NOT the full game)
The previous session analyzed 4 exports in the `..\venture\` scratch dir (`WeaponService.txt`,
`AbstractBasicWeapon.txt`, `CombatHandler.txt`, `StatusService.txt`). **The user says this is only a
small slice** — do NOT treat this as the game's full architecture. Findings (combat subsystem only):
- It's **one deeply-coupled combat engine**, not 4 independent systems. Frameworks are mixed: Knit
  (WeaponService, StatusService) + hand-rolled metatables (CombatHandler, AbstractBasicWeapon).
- **Four cross-cutting migrations recur everywhere** (these are the real work):
  1. Knit / metatable objects → **ServiceController** services.
  2. State smuggled into the Instance tree (`ServerStorage[UserId]` ValueObjects, Humanoid child
     BoolValues, character attributes, `_G`) → **Charm atoms** (runtime) + **profile slices**
     (persistent). Biggest change; touches everything.
  3. Untyped `EffectFire:FireAllClients({...})` arrays + Knit signals → **ByteNet** (discrete VFX)
     + **charm-sync** (continuous state).
  4. **Client-trusted combat** (`Client:ApplyDamage(player, params)` trusts client target/multiplier)
     → **server-authoritative hit detection**. This is a genuine redesign, not a port.
- **Sequencing principle:** foundation & leaves first, combat core LAST (it's the hub with 10+ deps
  and needs the hit-detection redesign). Candidate first target: **Player Stats & Loadout data
  layer** (loadout profile slice + live-stat atoms, replacing `PlayerStatManager` +
  `ServerStorage[UserId].Stats` ValueObjects). BUT validate against the full game first.
- 10+ referenced modules were NOT exported (`PlayerStatManager`, `CombatState`, `Blocking`,
  `EnchantmentService`, `MobHandler`, `Weapons` config, `AllStatuses`, `BuffsAndResistances`, …).

---

## MCP setup (do this in the new local session)
The `Roblox_Studio` MCP is configured on the machine but was scoped to a DIFFERENT project
(`Downloads/New folder`), so it didn't load here. In the new session's project dir, register it:

```bash
claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```
(defaults to local scope; add `--scope user` for all projects). Then **restart** the session, and
**trust** the server when prompted. Ensure the Roblox Studio MCP plugin is running in the open
`VentureTestingPlace` Studio session. Once connected you'll have `mcp__Roblox_Studio__execute_luau`
(and friends) — use it to walk the real `ServerScriptService` / `ReplicatedStorage` / etc. hierarchy,
enumerate all services/modules, and understand the true scope before planning.

## First actions for the new session
1. Confirm the `Roblox_Studio` MCP tools are available; if not, run the setup above.
2. Use `execute_luau` to enumerate the live game's structure (services, modules, folder tree, how
   data is stored, networking, Knit usage) — the FULL game, not the 4 exported scripts.
3. Build a real starting refactor plan grounded in the actual game: system inventory, dependency
   order, and a concrete first target (spec-first, mirroring the base's Currency/Inventory).
