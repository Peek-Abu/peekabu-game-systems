# Gloom Coat Catch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace "every catch kills, 8 s spectate, respawn" with the Gloom coat: each grab adds a layer and puts the player down. A teammate's vacuum takes layers off and revives. The last layer knocks the player out, then a rehire countdown brings them back at the truck. Solo players are rehired at once and the clock is cut. A crew wipe costs a time penalty. Every coat number is base plus modifiers.

**Architecture:** A new game feature, **Coat**, owns the coat state. Its decisions are pure, specced modules: the modifier combine is `CoatModifierFormulas` and the ladder is `CoatLadderRules`. Its bookkeeping lives in `CoatModifierTracker` and `CoatWearerTracker`. `CoatServiceServer` is a thin shell. It publishes `coatLayers`, `coatMax`, `downUntil`, `outUntil` and `coatLayeredAt` on the existing public player store, fires the five signals other plans consume, and owns the respawn policy, which it sets to `manual`. Occupant's catch keeps its scare and asks Coat what happens at the throw (`CoatServiceServer:grab`). Death is used only for a knock-out. Down is a reversible ragdoll held by the server (`CoatDownSystem`) that touches no base module. Cleaning is an Interaction channel on a coated player's root. Its kind is registered for each resolved clean time, because base Interaction fixes a channel's duration per kind. Features that Coat requires (Vacuum, Cargo, Hide) refuse actions from a down player through a character attribute. They do not call Coat, which would make a require cycle. **Coat never requires Shift**, because the analytics plan checks for require cycles. Shift requires Coat instead. In its `start`, Shift injects a `CoatTypes.Hooks` table through `CoatServiceServer:configure(hooks)`, the same way `OccupantCatchSystem.Hooks` works. The hooks are: is the shift running, who is in the crew, cut the clock, and count a layer taken and a layer cleaned. The truck spot needs no hook, because Shift's existing spawn resolver already respawns the crew in the loading bay.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, TestEZ (Studio only), Charm/charm-sync public player store, ByteNet (unchanged packets), React UI tree (HudRegistry, UI Labs stories).

**Spec:** `docs/superpowers/specs/2026-10-18-odd-hours-build-week-1-design.md` §3 "Gloom coat catch" (and §4/§6 lines it names: "Crew caught", clock-out XP exclusion, VFX in week 1).

## Approval needed

None of the three gated changes is needed: no new subfolder kind, no new role word, no second service in a feature. Every module below uses an existing subfolder and role word. Coat has one service per realm.

These are not gated, but the owner should confirm them before Task 1:
- **New game feature `Coat`.** The layout rules allow a game to add features ("A game adds its own"). Task 1 adds `Coat` to the Cleanup Crew feature-name line in `docs/project-structure.md`.
- **Channel kind per clean time** (Task 7). Base `InteractionRegistry` fixes a channel's `duration` per kind. Without a base change, Coat registers one kind for each resolved `cleanSeconds`, quantised to 0.05 s (`coatClean@1500`). The alternative is a per-target duration resolver in base Interaction, which would be a `base/*` PR off `origin/main`. This plan does not take that route.
- **Combine math lives in `Utils/CoatModifierFormulas`, not in a Rules module.** `project-structure.md` puts "game maths" in Utils/Formulas and keeps Rules for "allowed or valid?". All ladder decisions are in `Rules/CoatLadderRules`. Both modules are pure and specced.

## Global Constraints

- `--!strict` everywhere. No `any`, no casts. Spec files stay untyped.
- Spec-first: every new module has a `.spec.luau` sibling, or a `SpecRoots.EXEMPT_MODULES` line with a reason.
- Module placement follows `docs/project-structure.md` and the New modules table below. Run `python3 scripts/python/module_map.py --write` after adding modules.
- Server-authoritative: clients never write coat state. The client only names the teammate it aims at.
- Plain commit messages. No `Co-Authored-By:` or `Claude-Session:` trailers.
- No base-feature edits (Death, Interaction, Round, Carry, StateSync, Queue are base). Base fixes go in `base/*` PRs off `origin/main`. This plan needs none.
- Base values: `maxLayers` **3**, `cleanSeconds` **2**, `downSeconds` **12**, `rehireSeconds` **5**, `soloTimeCut` **15** (each solo knock-out costs `soloTimeCut × n`: 15, 30, 45 …), `crewPenalty` **30**.
- Combine: adds first, then multiplies, then clamp. `maxLayers` is an integer clamped to 1–6. Every time stat is ≥ 0.
- Modifier: `{ stat, scope: "server" | Player, kind: "add" | "multiply", value }`. `addModifier` returns a remover (the `CameraServiceClient:addModifier` pattern).
- "Caught" means knocked **out**. Only knock-outs reach `ShiftServiceServer:noteCatch`, so `RankFormulas.factsFor`'s `caught > 0` keeps its meaning. A grab that is revived or gets up does not count.
- A down player stays alive: Death's `dead` is not set. Voice keys on `dead`, so a down player can still talk.
- Kids-simple: nobody carries bodies.
- VFX are functional and in the current style only. Polish needs go to a log for the later VFX phase.
- UI follows the `game-ui-design` skill and is built from the existing paper kit.
- Tests run in Studio only. Set Workspace attribute `RunTests = true`, press Play, read Output, then stop and clear `RunTests`. The last green count was **3828**. Studio work happens only in the "Odd Hours" window under the playtest lock. No computer-use. No installs or builds while the owner is connected.
- Lint and format the changed files only: `selene <files>` and `stylua --check <files>`.
- `src/ServerScriptService/Core/Testing/SpecRoots.luau` already has an uncommitted change in this worktree that is not ours (a moved comment). Leave it as it is, and stage only our lines (`git add -p`).
- Coordination: the currencies plan also edits `ShiftServiceServer.luau` and `ShiftReviewViewModel.luau` (pay text → "Credits"), and the analytics plan may edit `ShiftTypes.luau`/`ShiftResultsUtils.luau`. Rebase before Task 4 and Task 11. Touch only the regions those tasks name, so the plans can run one after another.
- No require cycles: `CoatServiceServer` never requires `ShiftServiceServer`. Shift → Coat is the only direction (Task 4).
- Experiment variants (from the analytics plan, exact): `exp-clean` → `"1.5s"` | `"3s"`; `exp-rehire` → `"5s"` | `"10s"`. The crew id is `ExperimentServiceServer:crewId()` (never `game.JobId`: it is empty in Studio and `crewVariant` errors on an empty id). API: `ExperimentServiceServer:crewVariant(crewId: string, experimentId: string) -> string`.

## Review Focus

1. **A modifier lowers `maxLayers` below a player's current layers** (a perk removed, an event ending). The pips show at most `maxLayers` filled. The next grab knocks the player out and never sets layers above the max. Pinned in Task 2 (`grab` with layers 3, max 2 → out) and Task 3 (`publicOf` clamps layers to max).
2. **A player leaves while down, out, or mid-clean.** Their coat and their player-scoped modifiers are forgotten. If everyone still connected is out, they are rehired at once **without** the crew penalty, because a penalty comes only from a knock-out. Pinned in Task 2 (`afterLeave`) and Task 3 (`forget`).
3. **The shift ends** (timeout, clock out, reset, or a clock cut to 0) **while players are down or out.** Every down player stands up, every out player respawns, the coat fields clear, and no rehire is left owed. Under the manual policy nobody else would respawn them. Pinned in Task 3 (`reset` returns who to stand up and who to respawn) and Task 5.
4. **A clock cut or penalty larger than the time left.** The shift's `endsAt` clamps to now and the shift ends as a normal `timeout`. The clock never shows a negative time. Pinned in Task 4 (`ShiftPhaseRules.cut` / `timedOut`).
5. **Deaths that are not knock-outs under the manual respawn policy** (a character reset, a fall, a knock-out after the shift ended). The player respawns after the fallback delay and keeps their layers. Pinned in Task 2 (`respawnDelay`).

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Coat | shared | Data | `CoatConstants` | Base values, clamps, public field names, tag/attribute names, channel prefix, toast copy |
| Coat | shared | Data | `CoatTypes` | `Stat`, `Modifier`, `Resolved`, `Wearer`, `GrabResult`, `LadderDecision` types |
| Coat | server | (root) | `CoatServiceServer` | The coat service: modifiers, grab, clean, ticks, publishing, signals, respawn policy |
| Coat | server | Utils | `CoatModifierFormulas` | Combine base + modifiers (adds, multiplies, clamp) into resolved stats |
| Coat | server | Utils | `CoatExperimentUtils` | Turns the crew's `exp-clean` / `exp-rehire` variants into server-scoped modifiers |
| Coat | server | Rules | `CoatLadderRules` | Every ladder decision: grab → down/out, clean/revive, get up, rehire, solo cut, wipe, channel kind |
| Coat | server | State | `CoatModifierTracker` | The registered modifiers and their removers |
| Coat | server | State | `CoatWearerTracker` | Each player's coat (layers, down/out deadlines), the shift's solo knock-out count |
| Coat | server | Systems | `CoatDownSystem` | Puts a character down (reversible ragdoll, launch) and stands it up |
| Coat | server | Systems | `CoatCleanSystem` | Tags coated roots, registers clean channel kinds, runs canChannel/onComplete |
| Coat | client | (root) | `CoatServiceClient` | Starts the goo system and registers the layer HUD card |
| Coat | client | Data | `CoatVfxConstants` | Goo stage looks (blob layout, colour, drip rate), clean puff preset |
| Coat | client | Utils | `CoatGooFormulas` | Layer count → goo stage; layer change → added/cleaned |
| Coat | client | Systems | `CoatGooSystem` | Draws each player's goo stage on their character for everyone; clean puff |
| UI tree | client | `UI/React/Screens/Catch` | `CatchLayerCard` | HUD widget wiring the store to `CatchLayerPanel` |
| UI tree | client | `UI/React/Screens/Catch` | `CatchLayerPanel` (+ `.story`) | Presentational "Layer 2 of 3" / "DOWN · up in 0:08" card |
| UI tree | client | `UI/React/Screens/Catch` | `LayerPips` | Presentational pip row (empty → goo-filled), used by the card and the crew list |

---

### Task 1: Coat data, modifier formulas and modifier tracker

**Files:**
- Create: `src/ReplicatedStorage/Shared/Features/Coat/Data/CoatConstants.luau`
- Create: `src/ReplicatedStorage/Shared/Features/Coat/Data/CoatTypes.luau`
- Create: `src/ServerScriptService/Features/Coat/Utils/CoatModifierFormulas.luau`
- Test: `src/ServerScriptService/Features/Coat/Utils/CoatModifierFormulas.spec.luau`
- Create: `src/ServerScriptService/Features/Coat/State/CoatModifierTracker.luau`
- Test: `src/ServerScriptService/Features/Coat/State/CoatModifierTracker.spec.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (`EXEMPT_MODULES`)
- Modify: `docs/project-structure.md` (Cleanup Crew feature line; module map)

**Interfaces:**
- Produces (`CoatTypes`):
  - `export type Stat = "maxLayers" | "cleanSeconds" | "downSeconds" | "rehireSeconds" | "soloTimeCut" | "crewPenalty"`
  - `export type Modifier = { stat: Stat, scope: "server" | Player, kind: "add" | "multiply", value: number }`
  - `export type Resolved = { maxLayers: number, cleanSeconds: number, downSeconds: number, rehireSeconds: number, soloTimeCut: number, crewPenalty: number }`
  - `export type Wearer = { layers: number, downUntil: number?, outUntil: number?, layeredAt: number? }`
  - `export type GrabOutcome = "down" | "out" | "refused"`
  - `export type GrabResult = { outcome: GrabOutcome, layers: number, maxLayers: number, outUntil: number?, solo: boolean, soloCut: number? }`
  - `export type LadderDecision = { outcome: GrabOutcome, wearer: Wearer, soloCut: number? }`
  - `export type Hooks = { running: () -> boolean, crew: () -> { Player }, cutClock: (seconds: number) -> (), noteLayer: (player: Player) -> (), noteCleaned: (cleaners: { Player }) -> () }`. Shift injects these (Task 4). Until then the defaults are: `running` false, `crew` empty, the rest no-ops.
- Produces (`CoatConstants`, frozen):
  - `BASE: CoatTypes.Resolved` = `{ maxLayers = 3, cleanSeconds = 2, downSeconds = 12, rehireSeconds = 5, soloTimeCut = 15, crewPenalty = 30 }`
  - `MIN_LAYERS = 1`, `MAX_LAYERS = 6`
  - `CHANNEL_PREFIX = "coatClean@"`, `CHANNEL_STEP = 0.05`, `MIN_CHANNEL_SECONDS = 0.05`
  - `FALLBACK_RESPAWN_SECONDS = 8` (today's `SPECTATE_SECONDS`, for deaths that are not knock-outs)
  - `PUBLIC_LAYERS = "coatLayers"`, `PUBLIC_MAX_LAYERS = "coatMax"`, `PUBLIC_DOWN_UNTIL = "downUntil"`, `PUBLIC_OUT_UNTIL = "outUntil"`, `PUBLIC_LAYERED_AT = "coatLayeredAt"`
  - `DOWN_ATTRIBUTE = "CoatDown"` (on the character model while down), `CLEAN_TAG = "CoatCleanable"` (on a coated player's HumanoidRootPart), `RAGDOLL_NAME = "CoatRagdoll"`
  - `TICK_INTERVAL = 0.2`, `LAYER_BANNER_SECONDS = 3`
  - Copy: `DOWN_TOAST = "{name} is down! Vacuum them up."`, `OUT_TOAST = "{name} is OUT! Back at the truck in {clock}."`, `SOLO_TOAST = "{name} is OUT! Rehired at the truck. Clock -{clock}."`, `WIPE_TOAST = "Whole crew out! Everyone rehired. Clock -{clock}."` (templates filled by `CoatLadderRules.toastText`, Task 2)
- Produces (`CoatModifierFormulas`):
  - `combine(base: number, modifiers: { CoatTypes.Modifier }, stat: CoatTypes.Stat): number`. Takes only the modifiers for `stat`. Adds `base + Σ add`, then multiplies by `Π multiply`. Does not clamp.
  - `clamp(stat: CoatTypes.Stat, value: number): number`. `maxLayers` → `math.clamp(math.round(value), MIN_LAYERS, MAX_LAYERS)`; any other stat → `math.max(0, value)`.
  - `resolve(base: CoatTypes.Resolved, modifiers: { CoatTypes.Modifier }): CoatTypes.Resolved` (combine and clamp for every stat)
- Produces (`CoatModifierTracker`):
  - `new(): CoatModifierTracker`
  - `add(self, modifier: CoatTypes.Modifier): () -> ()`. Errors on an unknown stat or kind, or a value that is not finite. The remover is idempotent and removes only its own entry.
  - `forPlayer(self, player: Player?): { CoatTypes.Modifier }`. Returns every `"server"` modifier, plus the ones scoped to `player`. With nil it returns only the server ones.
  - `forget(self, player: Player)`: drops the modifiers scoped to `player`.
  - `count(self): number`

- [ ] **Step 1: Write the failing specs**

`CoatModifierFormulas.spec.luau` (the module is required as `script.Parent.CoatModifierFormulas`):

```lua
it("returns the base with no modifiers", function()
	expect(F.resolve(CoatConstants.BASE, {}).maxLayers).to.equal(3)
	expect(F.resolve(CoatConstants.BASE, {}).cleanSeconds).to.equal(2)
end)
it("a +1 layer perk gives 4", function()
	local mods = { { stat = "maxLayers", scope = "server", kind = "add", value = 1 } }
	expect(F.resolve(CoatConstants.BASE, mods).maxLayers).to.equal(4)
end)
it("adds before multiplies", function()
	local mods = {
		{ stat = "rehireSeconds", scope = "server", kind = "multiply", value = 2 },
		{ stat = "rehireSeconds", scope = "server", kind = "add", value = 1 },
	}
	expect(F.combine(5, mods, "rehireSeconds")).to.equal(12)
end)
it("multiplies stack", function()
	local mods = {
		{ stat = "cleanSeconds", scope = "server", kind = "multiply", value = 2 },
		{ stat = "cleanSeconds", scope = "server", kind = "multiply", value = 0.75 },
	}
	expect(F.combine(2, mods, "cleanSeconds")).to.equal(3)
end)
it("ignores other stats", function()
	local mods = { { stat = "downSeconds", scope = "server", kind = "add", value = 5 } }
	expect(F.combine(2, mods, "cleanSeconds")).to.equal(2)
end)
it("clamps maxLayers to 1..6 and rounds", function()
	expect(F.clamp("maxLayers", 9)).to.equal(6)
	expect(F.clamp("maxLayers", 0)).to.equal(1)
	expect(F.clamp("maxLayers", 3.4)).to.equal(3)
end)
it("clamps times at 0", function()
	expect(F.clamp("cleanSeconds", -1)).to.equal(0)
	expect(F.clamp("soloTimeCut", 7.5)).to.equal(7.5)
end)
it("exp-clean fast: 2 s x 0.75 = 1.5 s", function()
	local mods = { { stat = "cleanSeconds", scope = "server", kind = "multiply", value = 0.75 } }
	expect(F.resolve(CoatConstants.BASE, mods).cleanSeconds).to.equal(1.5)
end)
```

`CoatModifierTracker.spec.luau`. Player stand-ins are plain tables (`local alice = { UserId = -9101 }`); the spec is untyped.

```lua
it("server modifiers apply to everyone and to nil", function()
	local t = Tracker.new()
	t:add({ stat = "maxLayers", scope = "server", kind = "add", value = 1 })
	expect(#t:forPlayer(nil)).to.equal(1)
	expect(#t:forPlayer(alice)).to.equal(1)
end)
it("player modifiers apply only to that player", function()
	local t = Tracker.new()
	t:add({ stat = "maxLayers", scope = alice, kind = "add", value = 1 })
	expect(#t:forPlayer(alice)).to.equal(1)
	expect(#t:forPlayer(bob)).to.equal(0)
end)
it("the remover removes only its own entry and is idempotent", function()
	local t = Tracker.new()
	local m = { stat = "cleanSeconds", scope = "server", kind = "multiply", value = 2 }
	local removeA = t:add(m)
	t:add(m)
	removeA()
	removeA()
	expect(t:count()).to.equal(1)
end)
it("forget drops a leaver's modifiers", function()
	local t = Tracker.new()
	t:add({ stat = "maxLayers", scope = alice, kind = "add", value = 1 })
	t:forget(alice)
	expect(t:count()).to.equal(0)
end)
it("rejects a bad stat, kind or value", function()
	local t = Tracker.new()
	expect(function() t:add({ stat = "speed", scope = "server", kind = "add", value = 1 }) end).to.throw()
	expect(function() t:add({ stat = "maxLayers", scope = "server", kind = "set", value = 1 }) end).to.throw()
	expect(function() t:add({ stat = "maxLayers", scope = "server", kind = "add", value = 0 / 0 }) end).to.throw()
end)
```

- [ ] **Step 2: Run the specs to verify they fail**

Run: a Studio test run (Global Constraints).
Expected: FAIL. The two new specs error on requiring missing modules.

- [ ] **Step 3: Implement** `CoatConstants`, `CoatTypes`, `CoatModifierFormulas` and `CoatModifierTracker` with the signatures above. In `SpecRoots.EXEMPT_MODULES`, add `["ReplicatedStorage.Shared.Features.Coat.Data.CoatConstants"] = "static base values, names and copy (no logic)"` and `["ReplicatedStorage.Shared.Features.Coat.Data.CoatTypes"] = "type definitions only (no runtime logic)"`. In `docs/project-structure.md`, add `Coat` to "Cleanup Crew (branch `game/cleanup-crew`) adds …", in alphabetical order. Run `python3 scripts/python/module_map.py --write`.

- [ ] **Step 4: Run the specs to verify they pass, and lint**

Run: a Studio test run. Then `selene` and `stylua --check` on the six new files.
Expected: PASS, with the total above 3828 and 0 failed. Lint is clean.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Coat src/ServerScriptService/Features/Coat docs/project-structure.md
git add -p src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "Coat: modifiers and their combine (base + adds, then multiplies, clamped)"
```

---

### Task 2: The ladder rules

**Files:**
- Create: `src/ServerScriptService/Features/Coat/Rules/CoatLadderRules.luau`
- Test: `src/ServerScriptService/Features/Coat/Rules/CoatLadderRules.spec.luau`

**Interfaces:**
- Consumes: `CoatTypes.Wearer`, `Resolved`, `LadderDecision`; `CoatConstants` (Task 1)
- Produces (all pure):
  - `grab(wearer: Wearer, resolved: Resolved, now: number, solo: boolean, soloKnockouts: number): LadderDecision`
    - Refused (wearer unchanged) when `downUntil` or `outUntil` is set.
    - Otherwise `next = wearer.layers + 1`. When `next >= resolved.maxLayers`, the outcome is **out**: `layers = resolved.maxLayers`, `layeredAt = now`, `outUntil = now` when `solo`, else `now + resolved.rehireSeconds`, and `soloCut = resolved.soloTimeCut * (soloKnockouts + 1)` when `solo`.
    - Otherwise the outcome is **down**: `layers = next`, `layeredAt = now`, `downUntil = now + resolved.downSeconds`.
  - `clean(wearer: Wearer): Wearer?`. Returns nil when `layers == 0` or the wearer is out. Otherwise removes one layer and clears `downUntil` (the revive).
  - `canClean(check: { selfClean: boolean, targetLayers: number, targetOut: boolean, cleanerHidden: boolean, cleanerCarrying: boolean, cleanerDown: boolean }): boolean`
  - `getUpDue(wearer: Wearer, now: number): boolean`. True when `downUntil ~= nil and now >= downUntil`.
  - `rehireDue(wearer: Wearer, now: number): boolean`. True when `outUntil ~= nil and now >= outUntil`.
  - `gotUp(wearer: Wearer): Wearer`. Clears `downUntil` and keeps the layers.
  - `rehired(): Wearer`. Returns `{ layers = 0 }`.
  - `crewWiped(present: { Wearer }): boolean`. True when `#present >= 2` and every entry has `outUntil`.
  - `afterLeave(present: { Wearer }): boolean`. True when `#present >= 1` and every remaining entry is out (rehire now, no penalty).
  - `channelKind(seconds: number): (string, number)`. The duration is `math.max(MIN_CHANNEL_SECONDS, math.round(seconds / CHANNEL_STEP) * CHANNEL_STEP)`, and the kind is `CHANNEL_PREFIX .. math.round(duration * 1000)`.
  - `respawnDelay(cause: string?, heldOut: boolean): number?`. Returns nil when `heldOut` (Coat's rehire handles it). Otherwise returns `FALLBACK_RESPAWN_SECONDS`.
  - `toastText(template: string, name: string, seconds: number): string`. Fills `{name}` and `{clock}` (`m:ss`, rounded up, never negative).

- [ ] **Step 1: Write the failing spec** (`CoatLadderRules.spec.luau`, with `R = CoatConstants.BASE` and `now = 100`)

```lua
it("1st grab: down with 1 layer and a get-up deadline", function()
	local d = Rules.grab({ layers = 0 }, R, 100, false, 0)
	expect(d.outcome).to.equal("down")
	expect(d.wearer.layers).to.equal(1)
	expect(d.wearer.downUntil).to.equal(112)
	expect(d.wearer.layeredAt).to.equal(100)
end)
it("the grab that fills the last layer is out, rehire in 5 s", function()
	local d = Rules.grab({ layers = 2 }, R, 100, false, 0)
	expect(d.outcome).to.equal("out")
	expect(d.wearer.layers).to.equal(3)
	expect(d.wearer.outUntil).to.equal(105)
	expect(d.soloCut).to.equal(nil)
end)
it("solo out is instant and the cut grows 15, 30, 45", function()
	expect(Rules.grab({ layers = 2 }, R, 100, true, 0).wearer.outUntil).to.equal(100)
	expect(Rules.grab({ layers = 2 }, R, 100, true, 0).soloCut).to.equal(15)
	expect(Rules.grab({ layers = 2 }, R, 100, true, 1).soloCut).to.equal(30)
	expect(Rules.grab({ layers = 2 }, R, 100, true, 2).soloCut).to.equal(45)
end)
it("a +1 layer max needs a fourth grab to knock out", function()
	local four = table.clone(R); four.maxLayers = 4
	expect(Rules.grab({ layers = 2 }, four, 100, false, 0).outcome).to.equal("down")
	expect(Rules.grab({ layers = 3 }, four, 100, false, 0).outcome).to.equal("out")
end)
it("a lowered max knocks out on the next grab and caps the layers", function() -- Review Focus 1
	local two = table.clone(R); two.maxLayers = 2
	local d = Rules.grab({ layers = 3 }, two, 100, false, 0)
	expect(d.outcome).to.equal("out")
	expect(d.wearer.layers).to.equal(2)
end)
it("refuses a grab while down or out", function()
	expect(Rules.grab({ layers = 1, downUntil = 110 }, R, 100, false, 0).outcome).to.equal("refused")
	expect(Rules.grab({ layers = 3, outUntil = 105 }, R, 100, false, 0).outcome).to.equal("refused")
end)
it("clean revives: one layer off and up", function()
	local w = Rules.clean({ layers = 1, downUntil = 112, layeredAt = 100 })
	expect(w.layers).to.equal(0)
	expect(w.downUntil).to.equal(nil)
end)
it("clean takes a layer off someone who is up", function()
	expect(Rules.clean({ layers = 2 }).layers).to.equal(1)
end)
it("nothing to clean on a clean coat or an out player", function()
	expect(Rules.clean({ layers = 0 })).to.equal(nil)
	expect(Rules.clean({ layers = 3, outUntil = 105 })).to.equal(nil)
end)
it("no self-clean, none while hiding, carrying or down", function()
	local ok = { selfClean = false, targetLayers = 1, targetOut = false, cleanerHidden = false, cleanerCarrying = false, cleanerDown = false }
	expect(Rules.canClean(ok)).to.equal(true)
	for _, key in { "selfClean", "cleanerHidden", "cleanerCarrying", "cleanerDown", "targetOut" } do
		local bad = table.clone(ok); bad[key] = true
		expect(Rules.canClean(bad)).to.equal(false)
	end
	local empty = table.clone(ok); empty.targetLayers = 0
	expect(Rules.canClean(empty)).to.equal(false)
end)
it("gets up on the timer and keeps the layer", function()
	local w = { layers = 1, downUntil = 112 }
	expect(Rules.getUpDue(w, 111.9)).to.equal(false)
	expect(Rules.getUpDue(w, 112)).to.equal(true)
	expect(Rules.gotUp(w).layers).to.equal(1)
	expect(Rules.gotUp(w).downUntil).to.equal(nil)
end)
it("rehire is due at outUntil and clears the coat", function()
	expect(Rules.rehireDue({ layers = 3, outUntil = 105 }, 105)).to.equal(true)
	expect(Rules.rehired().layers).to.equal(0)
end)
it("a crew wipe needs two or more, all out", function()
	expect(Rules.crewWiped({ { layers = 3, outUntil = 1 }, { layers = 3, outUntil = 2 } })).to.equal(true)
	expect(Rules.crewWiped({ { layers = 3, outUntil = 1 }, { layers = 1, downUntil = 9 } })).to.equal(false)
	expect(Rules.crewWiped({ { layers = 3, outUntil = 1 } })).to.equal(false)
end)
it("after a leave, the rest all out means rehire now", function() -- Review Focus 2
	expect(Rules.afterLeave({ { layers = 3, outUntil = 1 } })).to.equal(true)
	expect(Rules.afterLeave({ { layers = 0 } })).to.equal(false)
	expect(Rules.afterLeave({})).to.equal(false)
end)
it("channel kinds are quantised and never zero", function()
	expect(select(1, Rules.channelKind(1.5))).to.equal("coatClean@1500")
	expect(select(2, Rules.channelKind(1.52))).to.equal(1.5)
	expect(select(2, Rules.channelKind(0))).to.equal(0.05)
end)
it("only a held knock-out skips the fallback respawn", function() -- Review Focus 5
	expect(Rules.respawnDelay("caught", true)).to.equal(nil)
	expect(Rules.respawnDelay("caught", false)).to.equal(8)
	expect(Rules.respawnDelay(nil, false)).to.equal(8)
end)
it("fills toast copy", function()
	expect(Rules.toastText(CoatConstants.OUT_TOAST, "Sam", 4.2)).to.equal("Sam is OUT! Back at the truck in 0:05.")
end)
```

- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL (the module is missing).
- [ ] **Step 3: Implement `CoatLadderRules`** with the signatures above. Each function is a few lines. `grab`'s branch order is: refused, then out, then down.
- [ ] **Step 4: Run to verify it passes, and lint.** Run a Studio test run, then `selene`/`stylua --check` on both files and `module_map.py --write`. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Features/Coat/Rules docs/project-structure.md
git commit -m "Coat: ladder rules (down, out, revive, get up, rehire, solo cut, crew wipe)"
```

---

### Task 3: The wearer tracker

**Files:**
- Create: `src/ServerScriptService/Features/Coat/State/CoatWearerTracker.luau`
- Test: `src/ServerScriptService/Features/Coat/State/CoatWearerTracker.spec.luau`

**Interfaces:**
- Consumes: `CoatTypes.Wearer`, `CoatConstants.PUBLIC_*`
- Produces:
  - `new(): CoatWearerTracker`
  - `get(self, userId: number): Wearer`. Returns a copy. An unknown player reads `{ layers = 0 }`.
  - `set(self, userId: number, wearer: Wearer)`
  - `forget(self, userId: number)`
  - `present(self, userIds: { number }): { Wearer }` (the wearers of the given ids, in order)
  - `soloKnockouts(self): number`, `noteSoloKnockout(self)`
  - `reset(self): (down: { number }, out: { number })`. Clears every wearer and the solo count. Returns the ids that were down and the ids that were out, so the service can stand up and respawn them.
  - `publicOf(self, userId: number, maxLayers: number): PublicPlayerTypes.PublicPlayer`. Returns `coatLayers = math.min(layers, maxLayers)`, `coatMax = maxLayers`, plus `downUntil`, `outUntil` and `coatLayeredAt` when they are set.
  - `cleared(): { string }`. Static: the optional field names (`downUntil`, `outUntil`, `coatLayeredAt`) that the service clears when they are absent.

- [ ] **Step 1: Write the failing spec**

```lua
it("an unknown player has a clean coat", function()
	expect(Tracker.new():get(1).layers).to.equal(0)
end)
it("get returns a copy", function()
	local t = Tracker.new(); t:set(1, { layers = 1 })
	t:get(1).layers = 9
	expect(t:get(1).layers).to.equal(1)
end)
it("reset reports who was down and who was out, then forgets all", function() -- Review Focus 3
	local t = Tracker.new()
	t:set(1, { layers = 1, downUntil = 10 }); t:set(2, { layers = 3, outUntil = 5 }); t:set(3, { layers = 2 })
	t:noteSoloKnockout()
	local down, out = t:reset()
	expect(down[1]).to.equal(1); expect(#down).to.equal(1)
	expect(out[1]).to.equal(2); expect(#out).to.equal(1)
	expect(t:get(3).layers).to.equal(0)
	expect(t:soloKnockouts()).to.equal(0)
end)
it("publicOf clamps layers to the max", function() -- Review Focus 1
	local t = Tracker.new(); t:set(1, { layers = 3 })
	local p = t:publicOf(1, 2)
	expect(p.coatLayers).to.equal(2); expect(p.coatMax).to.equal(2)
	expect(p.downUntil).to.equal(nil)
end)
it("publicOf carries the deadlines", function()
	local t = Tracker.new(); t:set(1, { layers = 1, downUntil = 12, layeredAt = 0 })
	expect(t:publicOf(1, 3).downUntil).to.equal(12)
	expect(t:publicOf(1, 3).coatLayeredAt).to.equal(0)
end)
it("forget drops a leaver", function() -- Review Focus 2
	local t = Tracker.new(); t:set(1, { layers = 2 }); t:forget(1)
	expect(#t:present({ 1 })).to.equal(1)
	expect(t:present({ 1 })[1].layers).to.equal(0)
end)
```

- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL (the module is missing).
- [ ] **Step 3: Implement `CoatWearerTracker`** with the signatures above. It holds a plain table keyed by userId and a solo counter.
- [ ] **Step 4: Run to verify it passes, and lint.** Run a Studio test run, lint both files, `module_map.py --write`. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Features/Coat/State/CoatWearerTracker.luau src/ServerScriptService/Features/Coat/State/CoatWearerTracker.spec.luau docs/project-structure.md
git commit -m "Coat: wearer tracker (layers, deadlines, solo count, public fields)"
```

---

### Task 4: Shift support: clock cuts and layer counts

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.luau` (add `cut`, `timedOut`)
- Test: `src/ServerScriptService/Features/Shift/Rules/ShiftPhaseRules.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.luau` (delta fields `layers`, `cleaned`)
- Test: `src/ServerScriptService/Features/Shift/State/ShiftRosterTracker.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau` (roster entry + `CrewLine` gain `layers: number?`, `cleaned: number?`; `ShiftResults` gains `layersCleaned: number?`; the `catches` comment becomes "Knock-outs this shift (the Gloom coat's last layer)")
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.luau` (copy `layers`/`cleaned` per line; sum `layersCleaned`)
- Test: `src/ServerScriptService/Features/Shift/Utils/ShiftResultsUtils.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`. Touch exactly these regions:
  - the `export type ShiftServiceServer` block (add `cutClock` after `noteCatch`);
  - the literal's method list (add `cutClock` right after `noteCatch = function`);
  - module-level locals near `noteCatch`'s helpers (two local functions `noteLayer` and `noteCleaned`);
  - the require block (add `RoundConstants`, if it is not required already);
  - `local function step()` (one `timedOut` check);
  - the header comment (one bullet).

  Leave pay and results text alone; that belongs to the currencies plan. Task 5 adds the `configure` call in `start`/`stop`.

**Interfaces:**
- Produces:
  - `ShiftPhaseRules.cut(state: ShiftState, seconds: number, now: number): ShiftState?`. Returns nil unless the phase is `running`, `endsAt` is set and `seconds > 0`. Otherwise returns a copy with `endsAt = math.max(now, endsAt - seconds)`.
  - `ShiftPhaseRules.timedOut(state: ShiftState, now: number): boolean`. True when the phase is `running` and `endsAt ~= nil and now >= endsAt`.
  - `ShiftServiceServer:cutClock(seconds: number) -> boolean`. Applies `cut`, publishes, and returns false outside a running shift. It is public so the coat hook and the Studio command bar can use it.
  - Module-local `noteLayer(player: Player): ()`. Adds `{ layers = 1 }` to the roster while running.
  - Module-local `noteCleaned(cleaners: { Player }): ()`. Adds `{ cleaned = 1 }` to each cleaner's entry while running. The crew total is the sum of the lines.
  - Task 5 hands both locals to Coat as hooks. `noteCatch` is unchanged; Task 6 calls it only on a knock-out.

- [ ] **Step 1: Write the failing tests**

`ShiftPhaseRules.spec.luau`:

```lua
it("cut lowers the end and clamps at now", function() -- Review Focus 4
	local running = { phase = "running", sub = "normal", stage = "normal", tier = 0, shift = 1, endsAt = 120, quota = 1, quotaMet = false }
	expect(ShiftPhaseRules.cut(running, 15, 100).endsAt).to.equal(105)
	expect(ShiftPhaseRules.cut(running, 60, 100).endsAt).to.equal(100)
end)
it("cut does nothing outside a running shift or for 0 s", function()
	expect(ShiftPhaseRules.cut({ phase = "lobby" }, 15, 100)).to.equal(nil)
	expect(ShiftPhaseRules.cut({ phase = "running", endsAt = 120 }, 0, 100)).to.equal(nil)
end)
it("timedOut once the cut end has passed", function()
	expect(ShiftPhaseRules.timedOut({ phase = "running", endsAt = 100 }, 100)).to.equal(true)
	expect(ShiftPhaseRules.timedOut({ phase = "running", endsAt = 100 }, 99)).to.equal(false)
	expect(ShiftPhaseRules.timedOut({ phase = "results", endsAt = 100 }, 200)).to.equal(false)
end)
```

`ShiftRosterTracker.spec.luau`: `record(1, "Sam", { layers = 1 })` twice, then `{ cleaned = 1 }` once. The entry reads `layers == 2` and `cleaned == 1`, and a new entry starts both at 0.
`ShiftResultsUtils.spec.luau`: two members with `cleaned` 2 and 1 and `caught` 1 and 0 give `results.layersCleaned == 3` and `results.catches == 1`. Each `CrewLine` carries its own `layers` and `cleaned`.

- [ ] **Step 2: Run to verify they fail.** Run a Studio test run. Expected: FAIL (`cut` and `timedOut` are nil; the new fields are missing).
- [ ] **Step 3: Implement.** Add the two rules, the roster delta fields (absent reads 0, like `caught`), the results sums, `cutClock` (typed in `export type ShiftServiceServer`) and the two locals. In the service's `step()`, while running: `if ShiftPhaseRules.timedOut(state, now()) then RoundServiceServer:endRound(RoundConstants.OUTCOME_TIMEOUT) end`. `onRoundPhase` then builds the review exactly as it does for a real timeout. Add one header bullet: "the coat's clock cuts (`cutClock`) lower the shift's end; the shift ends as a timeout once it passes."
- [ ] **Step 4: Run to verify they pass, and lint** the six touched files. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Features/Shift src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftTypes.luau
git commit -m "Shift: clock cuts that end as a timeout, and per-player layers taken and cleaned"
```

---

### Task 5: CoatServiceServer and the down ragdoll

**Files:**
- Create: `src/ServerScriptService/Features/Coat/CoatServiceServer.luau`
- Test: `src/ServerScriptService/Features/Coat/CoatServiceServer.spec.luau`
- Create: `src/ServerScriptService/Features/Coat/Systems/CoatDownSystem.luau` (spec-exempt)
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau`. Touch exactly these regions: the `dependencies` list (add `"CoatServiceServer"`), the require block (one require), `start` (one `CoatServiceServer:configure({...})` call after `DeathServiceServer:setSpawnPoint`), and `stop` (`CoatServiceServer:configure(nil)`).
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: Tasks 1–4; `DeathServiceServer:configure/respawn/isDead`, `DeathServiceServer.died`; `CoatTypes.Hooks`, injected by Shift (Coat requires neither Shift nor Round; the crew comes from `hooks.crew()`); `CarryServiceServer:forceDrop(player, "forced")`; `CargoServiceServer:scatterPockets(player, origin)`; `AnimationServiceServer:stopAll(player)`; `ToastServiceServer:send`; `StateSyncPublicPlayerStore.set/clearField`; `QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)`; `DeathRagdollUtils.isRootJoint/limitsFor/selfCollisionPairs` (pure base utils; read only)
- Produces:
  - `CoatDownSystem.down(character: Model, launch: Vector3): boolean`. False when the character is already down or has no Humanoid or root.
  - `CoatDownSystem.up(character: Model)`
  - `CoatDownSystem.isDown(character: Model?): boolean`
  - `CoatServiceServer` (`export type`, lean annotated literal):
    - `configure: (self, hooks: CoatTypes.Hooks?) -> ()`. Nil restores the defaults (not running).
    - `dependencies` = `{ "DeathServiceServer", "CarryServiceServer", "CargoServiceServer", "AnimationServiceServer", "ToastServiceServer", "StateSyncServiceServer", "QueueServiceServer", "InteractionServiceServer", "VacuumServiceServer", "HideServiceServer" }`
    - `layerAdded: SignalTyped.Signal<Player, number, number>` (player, layers, maxLayers)
    - `layerCleaned: SignalTyped.Signal<Player, Player>` (target, cleaner). Fires once per cleaned layer, with the first of the channel's cleaners.
    - `knockedOut: SignalTyped.Signal<Player>`, `rehired: SignalTyped.Signal<Player>`, `crewWiped: SignalTyped.Signal<()>`
    - `addModifier: (self, modifier: CoatTypes.Modifier) -> () -> ()`
    - `resolve: (self, player: Player?) -> CoatTypes.Resolved`
    - `grab: (self, player: Player, launch: Vector3) -> CoatTypes.GrabResult`
    - `clean: (self, target: Player, cleaners: { Player }) -> boolean`
    - `isDown: (self, player: Player) -> boolean`, `isOut: (self, player: Player) -> boolean`, `layersOf: (self, player: Player) -> number`
    - `start`, `stop`, `getState`

- [ ] **Step 1: Write the failing spec** (`CoatServiceServer.spec.luau`; the real-singleton rules in `docs/testing.md` apply)

Use a stand-in `{ UserId = -9201, DisplayName = "Spec" }` with `StateSyncPublicPlayerStore.join(-9201)` in `beforeAll` and `.remove(-9201)` in `afterAll`. Assert only on that id. Remove every modifier the spec adds.

```lua
it("resolves the base with no modifiers", function()
	expect(Coat:resolve(nil).maxLayers).to.equal(3)
	expect(Coat:resolve(nil).downSeconds).to.equal(12)
end)
it("a server modifier applies until removed", function()
	local remove = Coat:addModifier({ stat = "cleanSeconds", scope = "server", kind = "multiply", value = 0.75 })
	expect(Coat:resolve(nil).cleanSeconds).to.equal(1.5)
	remove()
	expect(Coat:resolve(nil).cleanSeconds).to.equal(2)
end)
it("the +1 layer test perk publishes a max of 4 for that player", function()
	local remove = Coat:addModifier({ stat = "maxLayers", scope = fake, kind = "add", value = 1 })
	expect(Coat:resolve(fake).maxLayers).to.equal(4)
	expect(StateSyncPublicPlayerStore.get(-9201).coatMax).to.equal(4)
	remove()
	expect(StateSyncPublicPlayerStore.get(-9201).coatMax).to.equal(3)
end)
it("a grab outside a running shift is refused", function()
	-- No shift runs in a test session.
	expect(Coat:grab(fake, Vector3.zero).outcome).to.equal("refused")
end)
it("rejects a malformed modifier", function()
	expect(function() Coat:addModifier({ stat = "maxLayers", scope = "server", kind = "add", value = math.huge }) end).to.throw()
end)
```

- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL (the module is missing).

- [ ] **Step 3: Implement `CoatDownSystem`** (an Instances shell). `down` does the following:
  - sets `DOWN_ATTRIBUTE` on the model;
  - takes network ownership of every unanchored part (`SetNetworkOwner(nil)`, in a `pcall`, as Death's `launchModel` does);
  - for every non-root Motor6D, adds a limited `BallSocketConstraint`, its two attachments and the `NoCollisionConstraint` pairs, all named `RAGDOLL_NAME`, using `DeathRagdollUtils` the way `DeathServiceServer.ragdollModel` does, then disables the Motor6D. The root joint stays on;
  - records each limb's `CanCollide` and sets it true. The root is never collidable;
  - calls `humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)` and `humanoid:ChangeState(Enum.HumanoidStateType.Physics)`;
  - applies `launch` to each part's `AssemblyLinearVelocity`.

  `up` reverses it: destroy everything named `RAGDOLL_NAME`, re-enable the Motor6Ds, restore `CanCollide`, re-enable GettingUp, `ChangeState(GettingUp)`, pivot the model upright at its current position and yaw, `SetNetworkOwner(player)` on the root, then clear the attribute. Header: "Not Death: the Humanoid never dies, so `dead`, voice routing and spectate are untouched. Spec-exempt shell; the decisions are CoatLadderRules."

- [ ] **Step 4: Implement `CoatServiceServer`.** Module state: one `CoatModifierTracker`, one `CoatWearerTracker`, and the five signals. It also keeps `publish(player)`, which sets `tracker:publicOf(userId, resolve(player).maxLayers)` and calls `StateSyncPublicPlayerStore.clearField` for each `CoatWearerTracker.cleared()` name that is absent. The behaviour:
  - `start`:
    - Return at once (and log it) unless `QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)`. In a hub, Coat must not make respawns manual. Set a module-local `started = true`.
    - `DeathServiceServer:configure({ respawn = "manual" })`.
    - `Observers.observePlayer`: publish an empty coat, so every roster shows 3 empty pips.
    - `Observers.observeCharacter`: a wearer with `outUntil` gets the new character as their rehire. Set `rehired()`, publish, fire `rehired`.
    - `DeathServiceServer.died`: a wearer who is down gets `gotUp`; else, when `CoatLadderRules.respawnDelay(info.cause, wearer.outUntil ~= nil)` returns a delay, `task.delay` it, then `DeathServiceServer:respawn(player)` if they are still dead.
    - Shift running edge: the tick compares `hooks.running()` with the last value it saw. On either edge it calls `resetAll()`, which runs `tracker:reset()`, then `CoatDownSystem.up` for the down ids, `DeathServiceServer:respawn` for the out ids, and a publish for every player. `configure(nil)` also calls `resetAll()`.
    - `PlayerRemoving`: `tracker:forget`, `modifiers:forget`. Then, if `afterLeave(present())`, rehire everyone now (set `outUntil = now`), with no penalty.
    - A Heartbeat loop every `TICK_INTERVAL` calls `tick(now)`.
  - `tick(now)`: for each player in `hooks.crew()`, when `getUpDue`, run `CoatDownSystem.up(character)`, then `gotUp`, then publish. When `rehireDue` and no respawn has been requested yet, call `DeathServiceServer:respawn(player)`. The character observer completes the rehire.
  - `grab(player, launch)`:
    - Refused unless `hooks.running()`.
    - `solo = #hooks.crew() <= 1`.
    - Get `decision = CoatLadderRules.grab(...)` and store `decision.wearer`.
    - On **down**: `CarryServiceServer:forceDrop(player, "forced")`, `CargoServiceServer:scatterPockets(player, root.CFrame)`, `AnimationServiceServer:stopAll(player)`, `CoatDownSystem.down(character, launch)`, `hooks.noteLayer(player)`, then toast `DOWN_TOAST` to `"all"`.
    - On **out**: `hooks.noteLayer(player)`, fire `knockedOut`. When `solo`: `noteSoloKnockout`, `hooks.cutClock(decision.soloCut)`, toast `SOLO_TOAST`. Otherwise, when `crewWiped(present())`: set every present wearer's `outUntil = now`, `hooks.cutClock(resolve(nil).crewPenalty)`, fire `crewWiped`, toast `WIPE_TOAST`.
    - Every non-refused grab fires `layerAdded(player, layers, maxLayers)` and publishes.
    - Return the `GrabResult`. The Death kill for an out player stays in Occupant (Task 6).
  - `clean(target, cleaners)`: when `CoatLadderRules.clean(wearer)` gives a wearer, store it. If the target was down, run `CoatDownSystem.up`. Then `hooks.noteCleaned(cleaners)`, fire `layerCleaned(target, cleaners[1])`, publish, and return true.
  - `addModifier` returns `tracker:add`'s remover, wrapped so that both adding and removing republish every player and call `cleanSystem:refresh` on every player once Task 7 exists.
  - `stop`: return unless `started`. Stand up everyone who is down, `configure({ respawn = "auto" })`, run the stoppers, and reset `started`.
  - Header comment: the ladder in five lines, then "Spec-exempt parts: the Instances/Death shell; the decisions are CoatLadderRules, CoatModifierFormulas and the two trackers."

  In `ShiftServiceServer.start`, call `CoatServiceServer:configure({ running = isRunning, crew = function() return trip:crew() end, cutClock = function(s) ShiftServiceServer:cutClock(s) end, noteLayer = noteLayer, noteCleaned = noteCleaned })`. In `stop`, call `configure(nil)`. Coat must not require `ShiftServiceServer` or `RoundServiceServer`. Grep Coat's requires to confirm.

  Add `["ServerScriptService.Features.Coat.Systems.CoatDownSystem"] = "Instances/Humanoid shell (ragdoll limits from DeathRagdollUtils; ladder decisions specced in CoatLadderRules)"` to `EXEMPT_MODULES`. Run `module_map.py --write`.

- [ ] **Step 5: Run to verify it passes, and lint** the service, the system and `SpecRoots.luau`. Expected: PASS, with no new failures elsewhere. `OccupantServiceServer` still configures `respawnDelay` until Task 6, which is harmless under the manual policy.
- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Coat src/ServerScriptService/Features/Shift/ShiftServiceServer.luau docs/project-structure.md
git add -p src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "Coat: service (modifiers, grab ladder, rehire, crew wipe, signals) and the down ragdoll"
```

---

### Task 6: The catch asks the coat

**Files:**
- Modify: `src/ServerScriptService/Features/Occupant/Systems/OccupantCatchSystem.luau` (Hooks, the SNAP branch, `reportFor`, `caught`, `rehired`; remove `clearDeadline`)
- Modify: `src/ServerScriptService/Features/Occupant/OccupantServiceServer.luau:152,173-179,423,437` (dependencies, `eligible`, `catchHooks`, remove the `respawnDelay` configure, header lines 28-29)
- Modify: `src/ServerScriptService/Features/Occupant/Rules/OccupantCatchRules.luau` (refuse `down`)
- Test: `src/ServerScriptService/Features/Occupant/Rules/OccupantCatchRules.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantTypes.luau` (`CatchInput.down: boolean`; `CatchReport.caughtAt: number`)
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau` (`LINES.coated`)
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.luau` (remove `caughtText`; the coat's toasts replace it)
- Test: `src/ReplicatedStorage/Shared/Features/Occupant/Utils/OccupantFeedbackUtils.spec.luau`

**Interfaces:**
- Consumes: `CoatServiceServer:grab/isDown` (Task 5), `CoatTypes.GrabResult`
- Produces: `OccupantCatchSystem.Hooks = { stillOn: () -> boolean, grab: (player: Player, launch: Vector3) -> CoatTypes.GrabResult, onCaught: (player: Player, result: CoatTypes.GrabResult) -> () }`

- [ ] **Step 1: Write the failing test.** In `OccupantCatchRules.spec.luau`: a fully catchable input with `down = true` returns `false, "down"`, and the existing fixtures gain `down = false`. In `OccupantFeedbackUtils.spec.luau`: remove the `caughtText` cases.
- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL, because the `down` case is still allowed.
- [ ] **Step 3: Implement.**
  - `OccupantCatchRules.canCatch` checks `input.down`, after `alive`, with reason `"down"`.
  - `OccupantCatchSystem.attempt` passes `down = CoatServiceServer:isDown(player)`.
  - In the SNAP delay, after the `stillOn` and alive checks:
    - compute `report` and `velocity` as today, then call `result = hooks.grab(player, velocity)`;
    - on `refused`, return (the player is just released);
    - on `down`, play `act(rig, "harlowThrow")` and `OccupantRigSystem.say(rig, OccupantConstants.LINES.coated)`. There is no kill and no report;
    - on `out`, play `act(rig, "harlowThrow")`, `DeathServiceServer:kill(victim, "caught", { launch = velocity })` and `say(LINES.caught)`. Set `report.backAt = result.outUntil` and `report.caughtAt = now`, send `CatchReport`, then call `hooks.onCaught(player, result)`.
  - Remove the `StateSyncPublicPlayerStore` caughtUntil write and `clearDeadline`. Coat owns `outUntil` now.
  - `caught(player, result)` sets `rehire[userId] = true` and calls `ShiftServiceServer:noteCatch(player)`. It sends no toast; Coat toasts.
  - `rehired(player)` only sends the `Rehired` packet. `dropRehires` only clears the table.
  - `OccupantServiceServer`: add `"CoatServiceServer"` to `dependencies`. `eligible` also requires `not CoatServiceServer:isDown(player)`, so he does not chase a downed player. `catchHooks.grab = function(p, v) return CoatServiceServer:grab(p, v) end`. Delete the `DeathServiceServer:configure({ respawnDelay = … })` line and its comment.
  - `LINES.coated = "Clean yourself up!"` is my call and tunable.
  - Update both module headers: a grab puts the player down with a layer; only the last layer kills; the wait is Coat's rehire.
- [ ] **Step 4: Run to verify it passes, and lint** the eight files. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Features/Occupant src/ReplicatedStorage/Shared/Features/Occupant
git commit -m "Occupant: a catch adds a coat layer and puts the player down; only the last layer is caught"
```

---

### Task 7: Vacuuming a teammate, and nothing while down

**Files:**
- Create: `src/ServerScriptService/Features/Coat/Systems/CoatCleanSystem.luau` (spec-exempt)
- Modify: `src/ServerScriptService/Features/Coat/CoatServiceServer.luau` (own a `CoatCleanSystem`; `refresh` on every coat or modifier change)
- Modify: `src/ReplicatedStorage/Client/Features/Vacuum/VacuumServiceClient.luau:43-90,186` (aim at coated teammates; no aim while down)
- Modify: `src/ReplicatedStorage/Shared/Features/Vacuum/Rules/VacuumEquipmentRules.luau:4` (`canVacuum(active, equipped, carrying, alive, down)`)
- Test: `src/ReplicatedStorage/Shared/Features/Vacuum/Rules/VacuumEquipmentRules.spec.luau`
- Modify: `src/ServerScriptService/Features/Vacuum/VacuumServiceServer.luau:208-220` (pass `down`)
- Modify: `src/ServerScriptService/Features/Cargo/Systems/CargoInventorySystem.luau:243` (route: down → handled, refused)
- Modify: `src/ServerScriptService/Features/Cargo/CargoServiceServer.luau:428` (`search`: down → `false, "down"`)
- Modify: `src/ServerScriptService/Features/Hide/HideServiceServer.luau:446` (`enter`: down → `false, "down"`)
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftClockOutSystem.luau:154` (`punch`: down → false)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `CoatLadderRules.canClean/channelKind`, `InteractionRegistry.hasChannel/registerChannel`, `InteractionServiceServer:channel(kind, { canChannel, onComplete })`, `InteractionConstants.CHANNEL_KIND_ATTRIBUTE`, `VacuumServiceServer:canVacuum(player, target)`, `HideServiceServer:isHidden(player)`, `CarryServiceServer:getCarried(player)`
- Produces:
  - `CoatCleanSystem.new(deps: { wearerOf: (player: Player) -> CoatTypes.Wearer, resolve: (player: Player) -> CoatTypes.Resolved, onCleaned: (target: Player, cleaners: { Player }) -> () }): CoatCleanSystem`
  - `refresh(self, player: Player)`. While the player has layers and is not out, their HumanoidRootPart carries `CLEAN_TAG` and `CHANNEL_KIND_ATTRIBUTE = channelKind(resolve(player).cleanSeconds)`; otherwise both are removed. A kind is registered the first time it is needed, with `{ duration, maxDistance = VacuumConstants.RANGE }` and one handler. A module set remembers the registered kinds, because Interaction asserts on a re-register.
  - `start(self): () -> ()`. Observes characters, so a new character is refreshed.
  - The handler's `canChannel(cleaner, root)` resolves the target player from `root.Parent`. It returns `canClean({ selfClean = cleaner == target, targetLayers, targetOut, cleanerHidden = HideServiceServer:isHidden(cleaner), cleanerCarrying = CarryServiceServer:getCarried(cleaner) ~= nil, cleanerDown = character attribute })` `and VacuumServiceServer:canVacuum(cleaner, root)`. `onComplete(players, root)` calls `deps.onCleaned(target, players)`, then `refresh(target)`.
  - The client aim keeps "several cleaners stack rate; progress kept on release" from Interaction unchanged.

- [ ] **Step 1: Write the failing test.** In `VacuumEquipmentRules.spec.luau`: `canVacuum(true, true, false, true, true)` is false, `canVacuum(true, true, false, true, false)` is true, and the existing cases gain `false` as the fifth argument.
- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL, because the down case returns true.
- [ ] **Step 3: Implement.**
  - The `down` parameter, with the server passing `character:GetAttribute(CoatConstants.DOWN_ATTRIBUTE) == true`.
  - The four server gates, each reading the same attribute. Cargo's route returns `true` with no toast (handled: a down player picks nothing up).
  - `CoatCleanSystem` as above, owned and started by the service.
  - `VacuumServiceClient.aimedPile`: return nil when the local character has `DOWN_ATTRIBUTE`. Also `consider` every `CollectionService:GetTagged(CoatConstants.CLEAN_TAG)` part that is not the local character's root. The radius comes from its Size through `VacuumTargetRules.radius`, so the same pick and server re-check apply.
  - Header lines in Vacuum (client and server): "a coated teammate's root is aimed at like a pile; vacuuming it cleans a layer (the Gloom coat)."
  - `EXEMPT_MODULES`: `["ServerScriptService.Features.Coat.Systems.CoatCleanSystem"] = "Interaction/CollectionService shell (who may clean specced in CoatLadderRules.canClean, the kind in channelKind)"`.
  - `module_map.py --write`.
- [ ] **Step 4: Run to verify it passes, and lint** the touched files. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Features/Coat src/ReplicatedStorage/Client/Features/Vacuum src/ReplicatedStorage/Shared/Features/Vacuum src/ServerScriptService/Features/Vacuum src/ServerScriptService/Features/Cargo src/ServerScriptService/Features/Hide src/ServerScriptService/Features/Shift/Systems/ShiftClockOutSystem.luau docs/project-structure.md
git add -p src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "Coat: vacuum a coated teammate to clean a layer; a down player can't act"
```

---

### Task 8: `outUntil`, crew pips and the CCTV retitle

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau` (remove `PUBLIC_CAUGHT_UNTIL` and `SPECTATE_SECONDS`)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCrewViewModel.luau`
- Test: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCrewViewModel.spec.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCompactHudPanel.luau:54,94-97` (+ its `.spec` and `.story` fixtures)
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftCrewList.luau` (pips + clean hint)
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/LayerPips.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchViewModel.luau`
- Test: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchViewModel.spec.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Occupant/Systems/OccupantCatchVfxSystem.luau` (watch `outUntil`)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Consumes: `CoatConstants.PUBLIC_*` (Task 1), `CatchReport.caughtAt` (Task 6)
- Produces:
  - `ShiftCrewViewModel.MemberView`. Gains `layers: number`, `maxLayers: number`, `cleanable: boolean`, `downUntil: number?`. `caughtUntil` is renamed to `outUntil: number?`.
  - `ShiftCrewViewModel.roster(crew, players, names, truck, clockingOut, now, punched?, me: number?)`. The new last parameter is the local userId, for `cleanable`.
  - `LayerPips` props: `{ layers: number, maxLayers: number, size: "small" | "large" }`.

- [ ] **Step 1: Write the failing tests**

`ShiftCrewViewModel.spec.luau`:

```lua
it("an out member reads OUT · back and is struck", function()
	local view = VM.roster({ 1 }, { ["1"] = { outUntil = 105, coatLayers = 3, coatMax = 3 } }, { [1] = "Sam" }, nil, false, 100)
	expect(view.members[1].status).to.equal("OUT · back 0:05")
	expect(view.members[1].struck).to.equal(true)
	expect(view.members[1].outUntil).to.equal(105)
end)
it("a down member reads DOWN · up and is not struck", function()
	local view = VM.roster({ 1 }, { ["1"] = { downUntil = 108, coatLayers = 1, coatMax = 3 } }, { [1] = "Sam" }, nil, false, 100)
	expect(view.members[1].status).to.equal("DOWN · up 0:08")
	expect(view.members[1].tone).to.equal("danger")
	expect(view.members[1].struck).to.equal(false)
end)
it("pips follow coatLayers / coatMax; 3 empty by default", function()
	local view = VM.roster({ 1, 2 }, { ["1"] = {}, ["2"] = { coatLayers = 2, coatMax = 4 } }, { [1] = "A", [2] = "B" }, nil, false, 0)
	expect(view.members[1].layers).to.equal(0); expect(view.members[1].maxLayers).to.equal(3)
	expect(view.members[2].layers).to.equal(2); expect(view.members[2].maxLayers).to.equal(4)
end)
it("a coated teammate is cleanable, never yourself or an out player", function()
	local players = { ["1"] = { coatLayers = 1, coatMax = 3 }, ["2"] = { coatLayers = 1, coatMax = 3 }, ["3"] = { coatLayers = 3, coatMax = 3, outUntil = 9 } }
	local view = VM.roster({ 1, 2, 3 }, players, { [1] = "A", [2] = "B", [3] = "C" }, nil, false, 0, nil, 1)
	expect(view.members[1].cleanable).to.equal(false)
	expect(view.members[2].cleanable).to.equal(true)
	expect(view.members[3].cleanable).to.equal(false)
end)
```

`CatchViewModel.spec.luau`: replace `caughtUntil` with `outUntil` in the fixtures. Add:
- The CCTV `back` reads `"OUT · BACK AT THE TRUCK IN 0:05"`.
- With a report of `clock = 300`, `caughtAt = 100` and `backAt = 110`, the rehired rows contain `"Re-hired: 4:50, no questions asked"`. Today they subtract 8.
- The footer reads `"Back at the truck…"`.

- [ ] **Step 2: Run to verify they fail.** Run a Studio test run. Expected: FAIL (old statuses, missing fields).
- [ ] **Step 3: Implement.**
  - `statusOf`, in priority order: `outUntil` → `OUT · back {clock}` (danger, struck, box `x`); `downUntil` → `DOWN · up {clock}` (danger, not struck); then today's order. `layers` and `maxLayers` read `coatLayers` and `coatMax`, defaulting to 0 and `CoatConstants.BASE.maxLayers`. `cleanable = layers > 0 and outUntil == nil and userId ~= me`.
  - `ShiftCompactHudPanel` ticks live on `outUntil or downUntil`.
  - `ShiftCrewList` draws `LayerPips` (small) after the name, and a small "VACUUM TO CLEAN" ink tag when `cleanable`. Use paper-kit tokens only (`game-ui-design`).
  - `ShiftHud` (or wherever `roster` is called) passes `Players.LocalPlayer.UserId`.
  - `CatchViewModel` reads `CoatConstants.PUBLIC_OUT_UNTIL` everywhere it read `caughtUntil`. The new `back` copy is as tested. Rehired `back = clock(report.clock - (report.backAt - report.caughtAt))`, footer as tested.
  - `OccupantCatchVfxSystem` watches `outUntil`.
  - Remove the two Occupant constants. Grep for zero hits on `PUBLIC_CAUGHT_UNTIL` and `SPECTATE_SECONDS` in `src/`.
  - `EXEMPT_MODULES`: `["ReplicatedStorage.Client.UI.React.Screens.Catch.LayerPips"] = "presentational React component (counts specced in ShiftCrewViewModel and CatchViewModel.layer; story in CatchLayerPanel.story)"`.
  - Check `ShiftCompactHudPanel.story` in UI Labs (EDIT mode) with 0/3, 2/3, 4/4, OUT and DOWN members.
- [ ] **Step 4: Run to verify they pass, and lint** the touched files. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Client/UI/React/Screens src/ReplicatedStorage/Client/Features/Occupant src/ReplicatedStorage/Shared/Features/Occupant/Data/OccupantConstants.luau
git add -p src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "Crew roster: layer pips, DOWN and OUT lines, clean hint; CCTV says back at the truck"
```

---

### Task 9: The layer card (catch landing and down timer)

**Files:**
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchViewModel.luau` (add `layer`, `layerTicks`)
- Test: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchViewModel.spec.luau`
- Create: `src/ReplicatedStorage/Client/UI/React/Screens/Catch/CatchLayerPanel.luau`, `CatchLayerPanel.story.luau`, `CatchLayerCard.luau`
- Create: `src/ReplicatedStorage/Client/Features/Coat/CoatServiceClient.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Produces:
  - `CatchViewModel.layer(input: { me: PublicPlayer?, nowServer: number, phone: boolean }): LayerView?`, where `LayerView = { title: string, detail: string, layers: number, maxLayers: number, danger: boolean }`
  - `CatchViewModel.layerTicks(me: PublicPlayer?, nowServer: number): boolean`
  - `CoatServiceClient` (`dependencies = {}`, `init` registers the widget, `start`, `stop`): `HudRegistry.register("coatLayer", CatchLayerCard, ShiftConstants.HUD_ORDER + 4)`

- [ ] **Step 1: Write the failing test**

```lua
it("down: title with the layer, detail with the get-up timer", function()
	local v = VM.layer({ me = { coatLayers = 1, coatMax = 3, downUntil = 108, coatLayeredAt = 96 }, nowServer = 100, phone = false })
	expect(v.title).to.equal("DOWN · LAYER 1 OF 3")
	expect(v.detail).to.equal("Up in 0:08 · or a teammate vacuums you")
	expect(v.danger).to.equal(false)
end)
it("phone keeps it short", function()
	local v = VM.layer({ me = { coatLayers = 1, coatMax = 3, downUntil = 108 }, nowServer = 100, phone = true })
	expect(v.detail).to.equal("Up in 0:08")
end)
it("one short of the max warns", function()
	local v = VM.layer({ me = { coatLayers = 2, coatMax = 3, downUntil = 108 }, nowServer = 100, phone = false })
	expect(v.danger).to.equal(true)
end)
it("a fresh layer while up shows for LAYER_BANNER_SECONDS", function()
	local me = { coatLayers = 1, coatMax = 3, coatLayeredAt = 99 }
	expect(VM.layer({ me = me, nowServer = 100, phone = false }).title).to.equal("LAYER 1 OF 3")
	expect(VM.layer({ me = me, nowServer = 103, phone = false })).to.equal(nil)
end)
it("nothing while out (the CCTV shows) or with a clean coat", function()
	expect(VM.layer({ me = { coatLayers = 3, coatMax = 3, outUntil = 105 }, nowServer = 100, phone = false })).to.equal(nil)
	expect(VM.layer({ me = { coatLayers = 0, coatMax = 3 }, nowServer = 100, phone = false })).to.equal(nil)
end)
it("ticks only while down or a banner shows", function()
	expect(VM.layerTicks({ downUntil = 108 }, 100)).to.equal(true)
	expect(VM.layerTicks({ coatLayers = 1 }, 100)).to.equal(false)
end)
```

- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL (`layer` is nil).
- [ ] **Step 3: Implement.**
  - `layer` and `layerTicks` as tested. `danger` is true when `layers >= maxLayers - 1`.
  - `CatchLayerPanel` (props = `LayerView`) is paper-kit, centred low on screen, with `LayerPips` (large). Mirror `CatchRehiredPanel` for kit usage and pass the `game-ui-design` red-flag check.
  - `CatchLayerCard` subscribes to the local public entry and the server clock (copy `CatchRehiredCard`'s wiring) and ticks on `layerTicks`.
  - `CoatServiceClient` registers it. Task 10 adds the goo system to its `start`.
  - `EXEMPT_MODULES`: `CatchLayerPanel` ("presentational React component (story in CatchLayerPanel.story)"), `CatchLayerCard` ("React HUD widget (card specced in CatchViewModel.layer)") and `ReplicatedStorage.Client.Features.Coat.CoatServiceClient` ("client shell registering the coat HUD card and starting CoatGooSystem (no logic)").
  - `module_map.py --write`.
  - Check the story in UI Labs: down 1/3, down 2/3, banner 1/3, 4/4 with the +1 perk, on phone and desktop.
- [ ] **Step 4: Run to verify it passes, and lint.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Client/UI/React/Screens/Catch src/ReplicatedStorage/Client/Features/Coat docs/project-structure.md
git add -p src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "Coat: layer card (Layer 2 of 3, DOWN with the get-up timer)"
```

---

### Task 10: Goo on the body

**Files:**
- Create: `src/ReplicatedStorage/Client/Features/Coat/Utils/CoatGooFormulas.luau`
- Test: `src/ReplicatedStorage/Client/Features/Coat/Utils/CoatGooFormulas.spec.luau`
- Create: `src/ReplicatedStorage/Client/Features/Coat/Data/CoatVfxConstants.luau`
- Create: `src/ReplicatedStorage/Client/Features/Coat/Systems/CoatGooSystem.luau`
- Modify: `src/ReplicatedStorage/Client/Features/Coat/CoatServiceClient.luau` (start/stop the system)
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`

**Interfaces:**
- Produces:
  - `CoatGooFormulas.stage(layers: number): number`. Returns an integer clamped to 0–6.
  - `CoatGooFormulas.change(before: number?, after: number): "added" | "cleaned" | nil`
  - `CoatVfxConstants.STAGES: { { blobs: { { part: string, offset: CFrame, size: Vector3 } }, drip: number } }` (index = stage, each a superset of the one before). Also `COLOUR` (the grime grape the kit already uses in `CargoVfxConstants`), `PUFF` (a `VfxBurstSystem` preset, like the Rehired puff in `OccupantCatchVfxSystem`) and `FOLDER_NAME = "CoatGoo"`.
  - `CoatGooSystem.start(): () -> ()`

- [ ] **Step 1: Write the failing spec**

```lua
it("one stage per layer, clamped", function()
	expect(G.stage(0)).to.equal(0); expect(G.stage(2)).to.equal(2)
	expect(G.stage(9)).to.equal(6); expect(G.stage(-1)).to.equal(0)
end)
it("names the change", function()
	expect(G.change(1, 2)).to.equal("added")
	expect(G.change(2, 1)).to.equal("cleaned")
	expect(G.change(nil, 0)).to.equal(nil)
	expect(G.change(2, 2)).to.equal(nil)
end)
```

- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `CoatGooSystem` (spec-exempt shell) observes every player's character and their public `coatLayers`. On a change, it rebuilds a `CoatGoo` folder of non-colliding, massless, welded blobs for `stage(layers)`, plus a drip `ParticleEmitter` at the drip rate, on everyone's client.
  - On `"cleaned"` it fires the `PUFF` burst at the root. It removes everything when the character is removed. While the player is `outUntil` it draws nothing; the porcelain crack already plays.
  - Functional and in the current style only. Write any polish idea as a line in the later VFX phase's log; do not build it.
  - `EXEMPT_MODULES`: `CoatVfxConstants` ("static goo stage looks (no logic)") and `CoatGooSystem` ("Instances/Charm shell (stage and change specced in CoatGooFormulas; looks in CoatVfxConstants)").
  - `module_map.py --write`.
- [ ] **Step 4: Run to verify it passes, and lint.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Client/Features/Coat docs/project-structure.md
git add -p src/ServerScriptService/Core/Testing/SpecRoots.luau
git commit -m "Coat: goo stages on the body for everyone, and a clean-off puff"
```

---

### Task 11: Results: "Crew caught" and "Layers cleaned"

**Files:**
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftReviewViewModel.luau:291,320`
- Test: `src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftReviewViewModel.spec.luau`

**Interfaces:**
- Consumes: `ShiftResults.catches` (knock-outs since Task 6), `ShiftResults.layersCleaned` (Task 4)

- [ ] **Step 1: Write the failing test.** For a results fixture with `catches = 2` and `layersCleaned = 5`, the card whose icon is `managerHunt` has `label == "Crew caught"` and `value == "2"`. `rows` contains `{ label = "CREW CAUGHT", value = "2" }`, followed directly by `{ label = "LAYERS CLEANED", value = "5" }`. An absent `layersCleaned` reads `"0"`. Update the existing "Times caught is the whole crew's catches" case (commit 9f7558f) to the new label.
- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL (old label, missing row).
- [ ] **Step 3: Implement** the two labels and the new row. Touch exactly these regions: the `cards` entry with `icon = "managerHunt"` (its label only), and the `rows` entry `"TIMES CAUGHT"` plus one new row inserted right after it. Change no other line, because the currencies plan edits the "Gleam earned" card and the earned row in this file.
- [ ] **Step 4: Run to verify it passes, and lint.** Expected: PASS. Check `ShiftReviewPanel`'s story (or its review story) in UI Labs for row overflow on phone.
- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftReviewViewModel.luau src/ReplicatedStorage/Client/UI/React/Screens/Shift/ShiftReviewViewModel.spec.luau
git commit -m "Shift review: Crew caught counts knock-outs, plus Layers cleaned"
```

---

### Task 12: Experiment variants as coat modifiers

**Depends on:** the analytics/experiments plan (spec §5) landing `ExperimentServiceServer:crewVariant(crewId: string, experimentId: string) -> string`. Do not start this task before that plan is merged into this branch.

**Files:**
- Create: `src/ServerScriptService/Features/Coat/Utils/CoatExperimentUtils.luau`
- Test: `src/ServerScriptService/Features/Coat/Utils/CoatExperimentUtils.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Features/Coat/Data/CoatConstants.luau` (add `EXPERIMENTS`)
- Modify: `src/ServerScriptService/Features/Coat/CoatServiceServer.luau` (apply on `running`, remove on leaving it; add `"ExperimentServiceServer"` to `dependencies`)

**Interfaces:**
- Consumes: `ExperimentServiceServer:crewVariant(crewId: string, experimentId: string) -> string`. The crew id is `ExperimentServiceServer:crewId()` (the shift server's JobId, "studio" in Studio). Coat still does not require Shift.
- Produces:
  - `CoatConstants.EXPERIMENTS = { clean = { id = "exp-clean", stat = "cleanSeconds", seconds = { ["1.5s"] = 1.5, ["3s"] = 3 } }, rehire = { id = "exp-rehire", stat = "rehireSeconds", seconds = { ["5s"] = 5, ["10s"] = 10 } } }`
  - `CoatExperimentUtils.modifiersFor(variants: { [string]: string }): { CoatTypes.Modifier }`. `variants` is keyed by experiment id. Each known variant gives one `{ stat, scope = "server", kind = "multiply", value = seconds / CoatConstants.BASE[stat] }`. An unknown experiment or variant gives nothing.

- [ ] **Step 1: Write the failing spec**

```lua
it("exp-clean 1.5s and 3s", function()
	local a = U.modifiersFor({ ["exp-clean"] = "1.5s" })
	expect(F.resolve(CoatConstants.BASE, a).cleanSeconds).to.equal(1.5)
	local b = U.modifiersFor({ ["exp-clean"] = "3s" })
	expect(F.resolve(CoatConstants.BASE, b).cleanSeconds).to.equal(3)
end)
it("exp-rehire 5s and 10s", function()
	expect(F.resolve(CoatConstants.BASE, U.modifiersFor({ ["exp-rehire"] = "5s" })).rehireSeconds).to.equal(5)
	expect(F.resolve(CoatConstants.BASE, U.modifiersFor({ ["exp-rehire"] = "10s" })).rehireSeconds).to.equal(10)
end)
it("unknown variants and experiments add nothing", function()
	expect(#U.modifiersFor({ ["exp-clean"] = "2s", ["exp-other"] = "1.5s" })).to.equal(0)
end)
it("every modifier is server-scoped", function()
	for _, m in U.modifiersFor({ ["exp-clean"] = "1.5s", ["exp-rehire"] = "10s" }) do
		expect(m.scope).to.equal("server")
	end
end)
```

- [ ] **Step 2: Run to verify it fails.** Run a Studio test run. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `CoatExperimentUtils` and the constant.
  - In the service, on the running edge into `running` (Task 5's tick): build `variants` from `ExperimentServiceServer:crewVariant(ExperimentServiceServer:crewId(), id)` for both experiment ids, then `addModifier` each result and keep the removers. Call the removers on the edge out of running, in `configure(nil)` and in `stop`.
  - Add one debug log line with the crew id and both variants.
  - `module_map.py --write`.
- [ ] **Step 4: Run to verify it passes, and lint.** Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Features/Coat src/ReplicatedStorage/Shared/Features/Coat/Data/CoatConstants.luau docs/project-structure.md
git commit -m "Coat: exp-clean and exp-rehire variants as server-scoped coat modifiers"
```

---

### Task 13: Studio verification, solo (owner-started)

**Files:** none. If anything fails, go back to the owning task, using `superpowers:systematic-debugging` first.

- [ ] **Step 1: Full test run.** Run a Studio test run. Expected: 0 failed. The count is 3828 plus the new cases. Stop, clear `RunTests`.
- [ ] **Step 2: Solo ladder.** The owner starts Play in the Odd Hours window under the playtest lock. Start a shift and let Harlow grab you. Expected:
  - the scare as today;
  - the throw line "Clean yourself up!";
  - you ragdoll and lie down;
  - your carried item and pockets drop;
  - 1 goo stage on the body;
  - the layer card reads "DOWN · LAYER 1 OF 3" with the timer counting from 0:12;
  - you cannot move, vacuum, hide or pick up;
  - the roster shows 1 of 3 pips and "DOWN · up …";
  - after 12 s you get up and the pip stays.
- [ ] **Step 3: Second grab.** The same as Step 2, with 2 pips and "danger" ink on the card.
- [ ] **Step 4: Solo knock-out.** Third grab. Expected:
  - "You're FIRED!", then a launch;
  - immediate respawn at the truck (loading bay) with 0 pips;
  - the Rehired card;
  - the toast "… Clock -0:15.";
  - the shift clock drops by 15 s;
  - a second knock-out cuts 30 s.
- [ ] **Step 5: Cut to zero.** In the server command bar, run `require(game.ServerScriptService.Features.Shift.ShiftServiceServer):cutClock(9999)`. Expected: the shift ends as a timeout, the review shows, and the "Crew caught" and "Layers cleaned" rows are there.
- [ ] **Step 6: +1 layer.** In the server command bar during a shift, run `require(game.ServerScriptService.Features.Coat.CoatServiceServer):addModifier({ stat = "maxLayers", scope = game.Players:GetPlayers()[1], kind = "add", value = 1 })`. Expected: the roster and the layer card show 4 pips, and only the fourth grab knocks out.
- [ ] **Step 7: Non-catch death.** Reset the character mid-shift. Expected: respawn after 8 s with the layers kept.
- [ ] **Step 8: Record the results.** Post a short pass/fail list with screenshots to the owner. Move the board item to "review" only when every step passes.

### Task 14: Studio verification, 2-player Local Server (owner-started)

**Files:** none.

- [ ] **Step 1: Revive.** The owner starts a 2-player Local Server. Player A is grabbed. Expected: both clients see A's goo stage, A's 1 pip and "DOWN · up …" on B's roster, and the "VACUUM TO CLEAN" tag. B equips the vacuum and holds it on A: the progress shows, and after 2 s A gets up with 0 pips. A puff plays for both, and both see the "Layers cleaned" count at the end. Two cleaners on one target finish faster.
- [ ] **Step 2: No rescue.** A is grabbed and B stays away. Expected: A gets up at 12 s and the pip stays.
- [ ] **Step 3: Knock-out with a crew.** A takes 3 layers. Expected:
  - "You're FIRED!";
  - CCTV spectate reading "OUT · BACK AT THE TRUCK IN 0:05";
  - B's roster shows "OUT · back 0:05";
  - A respawns at the truck at 0:00 with 0 pips;
  - the Rehired card's "Re-hired" time is the catch time minus 5 s;
  - the shift clock is not cut;
  - B can still hear A while A is down, but not while A is out (voice keys on `dead`).
- [ ] **Step 4: Crew wipe.** Knock out A, then B, inside A's countdown. Expected: both are rehired at once, the "Whole crew out!" toast shows, and the clock drops 30 s.
- [ ] **Step 5: Leave mid-countdown.** A is out and B leaves. Expected: A is rehired at once and the clock is not cut. Then B rejoins alone: B is now the only crew member, and B's next knock-out is a solo knock-out.
- [ ] **Step 6: Experiments** (only once Task 12 has landed). Force each crew variant through the experiment plan's debug path. Expected: `exp-clean` "1.5s" and "3s" clean in 1.5 s and 3 s; `exp-rehire` "5s" and "10s" rehire in 5 s and 10 s.
- [ ] **Step 7: XP.** Clock out with A knocked out once and B only revived. Expected: A shows "Incident Report filed" with no +5 clock-out XP. B gets the +5. "Whole crew out" is not paid, because A was caught.
- [ ] **Step 8: Record the results** as in Task 13. Then move the board item to "review", never "Done".

---

## Open questions (for the owner or the sibling plans)

1. **Which player's `cleanSeconds`?** This plan resolves it for the coated **target**. A "cleans faster" perk would want the cleaner's value instead. This doesn't matter in week 1, because the only source is the server-scoped experiment.
2. **"Clean yourself up!"** as Harlow's line for a non-final grab is a placeholder (my call).

## Coordinator decisions (2026-10-18)

- `cleanSeconds` resolves for the **target** (the coat's wearer); a cleaner-side perk, if ever wanted, is a separate stat.
- Harlow's line on a non-final grab: placeholder "Back to work!" — owner may rewrite.
- "Coat" as a new feature, one clean channel kind per clean time, and the combine math in Utils: accepted.
