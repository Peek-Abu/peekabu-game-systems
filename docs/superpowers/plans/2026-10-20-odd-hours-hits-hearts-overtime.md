# Hits, Hearts and Overtime Loot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:**
- Catches 1 and 2 knock you down for about a second instead of killing you.
- Lives show as toon hearts.
- Overtime spawns a new batch of loot, and only that loot pays ×1.5.

**Architecture:**
- **Knockdown:** a reusable, server-owned knockdown (thrown, ragdolled about 1 s, then up) replaces the kill in Occupant's catch whenever a life remains.
- **Hearts:** a UI swap in `ShiftLivesPips` to the uploaded heart images.
- **Overtime loot:** Office spawns a flagged batch when overtime begins, and the per-item flag rides through Cargo's deposit into Shift's pay.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ in Studio.

**Spec:** `docs/superpowers/specs/2026-10-20-odd-hours-hits-hearts-overtime-design.md`

## Global Constraints

- `--!strict`, no `any`, no casts. Follow `AGENTS.md` and `docs/project-structure.md`.
- **Specs:** new modules get specs, or a reasoned exempt entry. Run `python3 scripts/python/module_map.py --write` after adding modules.
- **Commits:** plain messages, no trailers, staged by name. Never stage other people's `SpecRoots.luau` hunks.
- **Hands off:** do not push. No wally, rokit, `rojo build` or `check.sh`. No git checkout, reset or stash.
- **Checks:** run `selene`, `stylua`, and `luau-lsp analyze` (repo `globalTypes.d.luau` as definitions, sourcemap in your own scratch dir) on touched files.
- **Values:**
  - knockdown ≈ 1 s;
  - hearts at 20 px on phone and 28 px on desktop (never under 20);
  - `heart` = `rbxassetid://75866312534437`;
  - `heart_gloomed` = `rbxassetid://85905766239276`;
  - `OVERTIME_LOOT_SHARE = 0.5`;
  - item attribute `OvertimeLoot`;
  - multiplier 1.5 for overtime items only.

## Review Focus

- **A hit near walls or furniture:** the thrown body must not end up inside geometry. Reuse the launch and keep it short; the knockdown must restore control even if the thrown body is blocked.
- **A hit while hidden or while carrying:** the eviction happens as today. A carried item drops as on today's catch, if that's the current behaviour.
- **A hit during the shift's end or reset:** control is restored and nothing stays stuck in PlatformStand.
- **Overtime with no free spots:** the batch spawns fewer items (down to 0) and never errors.
- **An overtime item banked after the shift's stage changes:** it still pays ×1.5, because the flag is on the item, not on the stage.

---

### Task 1: Hearts replace the dots (client UI)

**Files:**
- `src/ReplicatedStorage/Client/Features/UI/Data/UIAssets.luau`: add `heart` and `heartGloomed` to the `ToonIcon` union and to `TOON_ICONS`.
- `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftLivesPips.luau`: draw hearts.
- `ShiftCrewViewModel` and `ShiftHudViewModel` (and their specs), where pip sizes live: the heart sizes.

**Steps:**
- [ ] **Spec cases:**
  - the heart size is 20 on phone and 28 on desktop;
  - the existing name-width spec (≥60 px) and the overlap specs pass at the new sizes;
  - a pure helper `ShiftCrewViewModel.heartIcons(lives: number, max: number): { "heart" | "heartGloomed" }` returns `max` entries, with the first `lives` being `"heart"`.
- [ ] **Implement:** `ShiftLivesPips` renders `ToonIcon` per entry, and keeps the loss pop on the newly gloomed heart.
- [ ] **Commit:** `UI: lives show as toon hearts`.

### Task 2: Catches 1 and 2 are knockdowns (server and client)

**Files:**
- A knockdown module. Builder's choice of feature (see the spec): a pure decision helper with a spec, plus a server system and a client handler following the cargo slip pattern (`CargoSlipSystem`: `PlatformStand` plus an impulse, then `GettingUp`).
- `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau`: when `hooks.spendLife(player)` returns false (a life remains), knock down instead of `kill`. Then:
  - skip `caughtUntil`, `CatchReport`, the rehire flag and its card;
  - still call `noteCatch`;
  - send a toast that the player was caught, with no "back in" time;
  - keep the grace.
- `OccupantCatchUtils.afterCatch` and its spec: add the knockdown branch.

**Interfaces:**
- Produces: `knockdown(player: Player, launch: Vector3, seconds: number) -> ()`, server-owned. It must restore control even on a reset.
- Produces: `afterCatch(knockedOut)`, which now returns `{ kill: boolean, publishBack: number?, toast: "hit" | "out", rehire: boolean }`.

**Steps:**
- [ ] **Spec cases:**
  - `afterCatch(false)` gives `kill = false`, `toast = "hit"`, `rehire = false`, `publishBack = nil`;
  - `afterCatch(true)` gives `kill = true`, `toast = "out"`;
  - the knockdown decision helper: down for 1 s, then up; a reset mid-knockdown restores.
- [ ] **Implement,** then **Commit:** `Catches 1 and 2 are knockdowns: thrown, about a second down, back up`.

### Task 3: Overtime loot (Office, Cargo, Shift)

**Files:**
- Office:
  - roll the batch when the shift stage becomes `"overtime"`;
  - `OVERTIME_LOOT_SHARE = 0.5` in Office constants;
  - use `OfficeSpawnUtils` and `OfficeSpawnRules` with the spots not used by the first roll;
  - spawn through `CargoServiceServer:spawnItem` with `OvertimeLoot = true`.
- Cargo:
  - `CargoSpawnSystem` sets the attribute;
  - `CargoTypes.DepositItem.overtime: boolean?`;
  - `CargoBankRules` reads it into the deposit.
- Shift:
  - `ShiftQuotaFormulas.pay(deposit)` multiplies only overtime items by `OVERTIME_SALVAGE_MULTIPLIER`;
  - `ShiftBankingSystem` stops passing a stage multiplier;
  - the `overtimeSalvage` stat counts overtime items.
- Client: a subtle gold shimmer on items with `OvertimeLoot`, using the existing sparkle VFX.

**Steps:**
- [ ] **Spec cases:**
  - `pay` with one overtime item worth 10 and one normal item worth 10 is 25;
  - the batch size is `max(1, round(0.5 * normalValuables))` and is capped by the free spots;
  - no free spots gives 0 without error;
  - `CargoBankRules` carries `overtime`.
- [ ] **Implement,** then **Commit:** `Overtime spawns a shimmering batch of loot; only it pays ×1.5`.

### Task 4: Verification (controller and owner)

- [ ] The full Studio suite passes.
- [ ] **Controller 2-player check** with screenshots:
  - catches 1 and 2 are knockdowns;
  - the third knocks out and the body stays put;
  - the hearts render;
  - overtime spawns shimmering loot, and the pay differs per item.
- [ ] The owner's play-check, then update the checklist.
