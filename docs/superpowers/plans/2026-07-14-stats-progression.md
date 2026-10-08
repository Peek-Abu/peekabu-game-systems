# Stats & Progression (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The `stats` slot-scoped slice — `{ totalXp, investments }` — with level, point pools, and combat stats all DERIVED by one shared pure module; a server-authoritative `StatsService`; Humanoid application; and Cmdr admin commands as the test surface.

**Architecture:** Two stored fields, everything else computed. `level = levelOf(totalXp)` (no level-up loop; level and XP cannot disagree). `unspent = earned(level) − spent(investments)` (no counter to inflate — conservation of points is true by construction). Derived values are NEVER stored or replicated: charm-sync ships the slice, and both realms run the same pure `StatFormulas` on it. There is NO modifier-source engine in this phase — when equipment lands (Phase 3), `derive` grows a `sources` parameter; extension, not rewrite.

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, Cmdr, TestEZ.

Spec: `docs/superpowers/specs/2026-07-14-stats-progression-design.md`
Branch: `feat/stats`, stacked on `feat/player-data-slots` (PR #1, unmerged). PR for this phase targets `feat/player-data-slots` as its base.

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification and sign-off. If one seems forced, STOP and escalate.
- **Spec-first TDD.** `SpecRoots.assertAllModulesSpecced` fails the build for an unspecced first-party module. Spec files are intentionally untyped.
- **Server-authoritative.** The client never writes stats; it reads the replicated slice.
- **Service shape: lean annotated literal** (`export type X = {...}` + `local X: X = {...}`, methods as fields). Auto-discovered by `*ServiceServer` / `*ServiceClient` filename suffix.
- **Commits: plain messages.** No `Co-Authored-By:` / `Claude-Session:` trailers.
- **No headless test runner.** Gate = FULL `bash scripts/check.sh` (WITH wally install — `wally-package-types` is NOT idempotent; `--skip-install` on stale link files gives spurious `'REQUIRED_MODULE' is not a function call` errors). TestEZ runs on Open Cloud only on a PR / push to main. Baseline: **534 tests passing**. One accepted warning exists: `DeprecatedApi` on `Player:LoadCharacter`.
- **No migrations.** Data is wiped pre-launch.
- **All names and numbers are provisional** (`MAX_LEVEL = 30`, `xpToNext = level × 25`, pools `main`/`sub`, per-point values). They live in ONE config module so retuning is an edit, not a refactor.
- **HAND-TRACE every spec fixture you touch** through mutate → validator → mirror → manifest reader. This branch has been bitten FOUR times by fixtures that typechecked green and failed at runtime.

## The add-a-slice recipe (from SliceManifest's header — Task 3 follows it exactly)

1. Add the field to `PlayerDataTypes.PlayerSlot`.
2. Add ONE entry to `SliceManifest.DEFINITIONS` (reader projects the active slot).
3. Declare the client atom in `ClientStore` (atom + one `atoms` registry line).
4. Register via `SliceOwner.registerSlot` in the owning service (Task 4).

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Modules/Constants/StatConstants.luau` | **New.** The ONE config registry: stat definitions (pool/base/perPoint), `MAX_LEVEL`, XP curve constant, points-per-level. |
| `src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.luau` | **New.** Pure derive module: `levelOf`, `xpForLevel`, `progress`, `pointsEarned/Spent/Unspent`, `derive`. No dependencies beyond StatConstants. |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | `StatsSlice` type; `PlayerSlot` gains `stats`. |
| `src/ReplicatedStorage/Shared/State/SliceManifest.luau` | `stats` entry (active-slot reader). |
| `src/ReplicatedStorage/Client/State/ClientStore.luau` | `stats` atom + registry line. |
| `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` | **New.** Owns the slice (registerSlot + validator); addExperience/invest/respec/getters; Humanoid application. |
| `src/ReplicatedStorage/Client/Services/StatsService/StatsServiceClient.luau` | **New.** Read facade over the atom + StatFormulas. |
| `src/ServerScriptService/Commands/GiveXp{,Server}.luau`, `InvestStat{,Server}.luau`, `RespecStats{,Server}.luau` | **New.** Admin test surface. |

Each new module gets a `.spec.luau` sibling (Cmdr command files go in `SpecRoots.EXEMPT_MODULES`, same as the slot commands).

---

### Task 1: `StatConstants` — the config registry

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/Constants/StatConstants.luau`
- Test: `src/ReplicatedStorage/Shared/Modules/Constants/StatConstants.spec.luau`

**Interfaces (produces):**
- `StatConstants.MAX_LEVEL = 30`
- `StatConstants.XP_PER_LEVEL_FACTOR = 25` (curve: xp to go from level L to L+1 is `L * 25`)
- `StatConstants.POINTS_PER_LEVEL = { main = 1, sub = 3 }`
- `StatConstants.DEFINITIONS: { [string]: StatDefinition }` where `StatDefinition = { pool: "main" | "sub", base: number, perPoint: number }`
- `StatConstants.STAT_IDS: { string }` (sorted, derived from DEFINITIONS)
- `StatConstants.isValidStatId(id: string) -> boolean`
- `export type StatId = string` (dynamic registry — same documented rationale as `ProfilePath`, limitations.md #3)
- `export type PoolName = "main" | "sub"`

- [ ] **Step 1: Write the failing spec**

`StatConstants.spec.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatConstants = require(ReplicatedStorage.Shared.Modules.Constants.StatConstants)

return function()
	describe("StatConstants", function()
		it("registers the eight launch stats", function()
			expect(#StatConstants.STAT_IDS).to.equal(8)
		end)

		it("every definition has a valid pool, base, and perPoint", function()
			for id, def in StatConstants.DEFINITIONS do
				expect(def.pool == "main" or def.pool == "sub").to.equal(true)
				expect(type(def.base)).to.equal("number")
				expect(type(def.perPoint)).to.equal("number")
			end
		end)

		it("validates stat ids", function()
			expect(StatConstants.isValidStatId("health")).to.equal(true)
			expect(StatConstants.isValidStatId("mana")).to.equal(false) -- dropped from the old game
			expect(StatConstants.isValidStatId("")).to.equal(false)
		end)

		it("STAT_IDS is sorted and matches DEFINITIONS exactly", function()
			local count = 0
			for _ in StatConstants.DEFINITIONS do
				count += 1
			end
			expect(#StatConstants.STAT_IDS).to.equal(count)
			for index = 2, #StatConstants.STAT_IDS do
				expect(StatConstants.STAT_IDS[index - 1] < StatConstants.STAT_IDS[index]).to.equal(true)
			end
		end)

		it("exposes the provisional tuning constants", function()
			expect(StatConstants.MAX_LEVEL).to.equal(30)
			expect(StatConstants.XP_PER_LEVEL_FACTOR).to.equal(25)
			expect(StatConstants.POINTS_PER_LEVEL.main).to.equal(1)
			expect(StatConstants.POINTS_PER_LEVEL.sub).to.equal(3)
		end)
	end)
end
```

- [ ] **Step 2: Run the gate to see it fail** — `bash scripts/check.sh` → FAIL (module missing).

- [ ] **Step 3: Implement**

```lua
--!strict
--[=[
	StatConstants: the ONE declaration site for progression tuning and the stat registry.

	EVERY number here is provisional — carried from the old game as a starting point, expected to be
	retuned. That is the point of this module: retuning is an edit here, never a schema change. The
	persisted slice stores only { totalXp, investments }; everything a stat definition drives (max
	health, regen rates, point pools) is DERIVED by StatFormulas from these constants, so changing a
	base/perPoint/curve value re-derives everywhere with no migration.

	Adding or renaming a stat = one DEFINITIONS entry. The slice validator rejects unknown investment
	keys against this registry (same rule as CurrencyConstants), so a typo'd stat id fails loudly.

	@class StatConstants
]=]

--[=[
	One investable stat.
	@interface StatDefinition
	.pool PoolName -- Which point pool buys it ("main" = the big survivability stats, "sub" = fine-tuning)
	.base number -- The derived value at zero investment
	.perPoint number -- Derived-value gain per invested point (linear, like the old game)
]=]
export type PoolName = "main" | "sub"
export type StatDefinition = {
	pool: PoolName,
	base: number,
	perPoint: number,
}
-- Dynamic registry key — same documented rationale as ProfilePath being `string` (limitations.md #3).
export type StatId = string

local DEFINITIONS: { [string]: StatDefinition } = {
	-- main pool: raw survivability
	health = { pool = "main", base = 200, perPoint = 5 },
	stamina = { pool = "main", base = 100, perPoint = 2 },
	-- sub pool: fine-tuning + the Rot subsystem (Venture's signature mitigation mechanic:
	-- rotEndurance sizes the rot bar, rotStrength scales the spell shield, rotRejuvenation regens it)
	healthRegen = { pool = "sub", base = 1, perPoint = 1 },
	staminaRegen = { pool = "sub", base = 1, perPoint = 1 },
	rotStrength = { pool = "sub", base = 1, perPoint = 1 },
	rotEndurance = { pool = "sub", base = 1, perPoint = 1 },
	rotRejuvenation = { pool = "sub", base = 1, perPoint = 1 },
	strength = { pool = "sub", base = 1, perPoint = 1 },
}

local STAT_IDS: { string } = {}
for id in DEFINITIONS do
	table.insert(STAT_IDS, id)
end
table.sort(STAT_IDS)

local StatConstants = {
	DEFINITIONS = DEFINITIONS,
	STAT_IDS = STAT_IDS,

	-- Progression tuning (provisional; from the old game). XP to advance FROM level L is
	-- L * XP_PER_LEVEL_FACTOR — linear, like the old curve. levelOf/xpForLevel in StatFormulas are
	-- the only readers, so swapping the curve for a steeper one is a one-function change there.
	MAX_LEVEL = 30,
	XP_PER_LEVEL_FACTOR = 25,
	POINTS_PER_LEVEL = { main = 1, sub = 3 },
}

--[=[
	True if `id` names a registered stat. The slice validator uses this to reject unknown investment
	keys — the registry is the single source of truth for what stats exist.
	@param id string -- A candidate stat id
	@return boolean
]=]
function StatConstants.isValidStatId(id: string): boolean
	return DEFINITIONS[id] ~= nil
end

return StatConstants
```

- [ ] **Step 4: Run the gate to verify it passes** — `bash scripts/check.sh` → PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/Constants/StatConstants.luau src/ReplicatedStorage/Shared/Modules/Constants/StatConstants.spec.luau
git commit -m "feat(stats): add StatConstants config registry"
```

---

### Task 2: `StatFormulas` — the pure derive module

The heart of the design. Pure functions only; the heaviest test load in the phase.

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.luau`
- Test: `src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.spec.luau`

**Interfaces:**
- Consumes: `StatConstants` (Task 1).
- Produces (exact signatures later tasks call):
  - `StatFormulas.xpForLevel(level: number) -> number` — cumulative XP at which `level` BEGINS. `xpForLevel(1) == 0`.
  - `StatFormulas.levelOf(totalXp: number) -> number` — clamped to `1..MAX_LEVEL`.
  - `StatFormulas.maxTotalXp() -> number` — `xpForLevel(MAX_LEVEL)`; the addExperience clamp.
  - `StatFormulas.progress(totalXp: number) -> { level: number, xpIntoLevel: number, xpToNext: number? }` — `xpToNext` is nil at max level.
  - `StatFormulas.pointsEarned(level: number) -> { main: number, sub: number }` — `(level - 1) * POINTS_PER_LEVEL[pool]` (level 1 has earned nothing).
  - `StatFormulas.pointsSpent(investments: { [string]: number }) -> { main: number, sub: number }`
  - `StatFormulas.pointsUnspent(totalXp: number, investments: { [string]: number }) -> { main: number, sub: number }`
  - `StatFormulas.derive(investments: { [string]: number }) -> { [string]: number }` — `{ [statId] = base + points × perPoint }` for every registered stat (missing investment key = 0 points).

With the linear curve, `xpForLevel(L) = 25 * (L-1) * L / 2` (sum of `l*25` for `l = 1..L-1`). `levelOf` must be implemented as the inverse of `xpForLevel` by iteration or closed form — but the SPEC ONLY promises mutual inverses, so implement whichever is clearer; the tests pin the boundary behaviour, not the internals.

- [ ] **Step 1: Write the failing spec**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatFormulas = require(ReplicatedStorage.Shared.Modules.Utils.StatFormulas)
local StatConstants = require(ReplicatedStorage.Shared.Modules.Constants.StatConstants)

return function()
	describe("StatFormulas", function()
		describe("levelOf / xpForLevel", function()
			it("starts at level 1 with zero xp", function()
				expect(StatFormulas.xpForLevel(1)).to.equal(0)
				expect(StatFormulas.levelOf(0)).to.equal(1)
			end)

			it("levels up at exactly the threshold (level 1 -> 2 at 25 xp)", function()
				expect(StatFormulas.levelOf(24)).to.equal(1)
				expect(StatFormulas.levelOf(25)).to.equal(2)
			end)

			it("xpForLevel and levelOf are mutual inverses at EVERY level boundary", function()
				for level = 1, StatConstants.MAX_LEVEL do
					local threshold = StatFormulas.xpForLevel(level)
					expect(StatFormulas.levelOf(threshold)).to.equal(level)
					if threshold > 0 then
						expect(StatFormulas.levelOf(threshold - 1)).to.equal(level - 1)
					end
				end
			end)

			it("clamps at MAX_LEVEL", function()
				expect(StatFormulas.levelOf(math.huge)).to.equal(StatConstants.MAX_LEVEL)
				expect(StatFormulas.levelOf(StatFormulas.maxTotalXp() + 1e6)).to.equal(StatConstants.MAX_LEVEL)
			end)

			it("a single grant crossing SEVERAL levels lands on the right level", function()
				-- 0 xp + 160 xp: 25 (->2) + 50 (->3) + 75 (->4) = 150, with 10 into level 4.
				expect(StatFormulas.levelOf(160)).to.equal(4)
				local progress = StatFormulas.progress(160)
				expect(progress.level).to.equal(4)
				expect(progress.xpIntoLevel).to.equal(10)
				expect(progress.xpToNext).to.equal(4 * StatConstants.XP_PER_LEVEL_FACTOR)
			end)

			it("progress reports nil xpToNext at max level", function()
				expect(StatFormulas.progress(StatFormulas.maxTotalXp()).xpToNext).to.never.be.ok()
			end)
		end)

		describe("point pools", function()
			it("level 1 has earned nothing", function()
				local earned = StatFormulas.pointsEarned(1)
				expect(earned.main).to.equal(0)
				expect(earned.sub).to.equal(0)
			end)

			it("earns per level from the config", function()
				local earned = StatFormulas.pointsEarned(5)
				expect(earned.main).to.equal(4 * StatConstants.POINTS_PER_LEVEL.main)
				expect(earned.sub).to.equal(4 * StatConstants.POINTS_PER_LEVEL.sub)
			end)

			it("spent sums per pool", function()
				local spent = StatFormulas.pointsSpent({ health = 2, stamina = 1, rotEndurance = 3 })
				expect(spent.main).to.equal(3)
				expect(spent.sub).to.equal(3)
			end)

			it("unspent = earned - spent", function()
				local totalXp = StatFormulas.xpForLevel(5) -- level 5: earned 4 main / 12 sub
				local unspent = StatFormulas.pointsUnspent(totalXp, { health = 3, strength = 2 })
				expect(unspent.main).to.equal(1)
				expect(unspent.sub).to.equal(10)
			end)
		end)

		describe("derive", function()
			it("returns base values for an empty build", function()
				local derived = StatFormulas.derive({})
				expect(derived.health).to.equal(200)
				expect(derived.stamina).to.equal(100)
				expect(derived.rotEndurance).to.equal(1)
			end)

			it("adds perPoint per invested point", function()
				local derived = StatFormulas.derive({ health = 3, rotEndurance = 2 })
				expect(derived.health).to.equal(200 + 3 * 5)
				expect(derived.rotEndurance).to.equal(1 + 2 * 1)
			end)

			it("covers EVERY registered stat, invested or not", function()
				local derived = StatFormulas.derive({})
				for _, id in StatConstants.STAT_IDS do
					expect(type(derived[id])).to.equal("number")
				end
			end)
		end)
	end)
end
```

- [ ] **Step 2: Run the gate to see it fail** — FAIL (module missing).

- [ ] **Step 3: Implement**

```lua
--!strict
--[=[
	StatFormulas: the ONE place progression math lives — pure functions over the persisted stats
	slice ({ totalXp, investments }).

	NOTHING derived is ever stored or replicated. The server calls these to apply Humanoid values and
	answer queries; the client calls the SAME functions on the charm-synced slice for UI. Both realms
	always agree because there is exactly one implementation and its inputs are the synced slice.

	Level is DERIVED from totalXp (levelOf), so there is no level-up carry loop and level/xp cannot
	disagree. Unspent points are DERIVED (earned(level) - spent(investments)), so there is no pool
	counter to corrupt — conservation of points is true by construction.

	Phase 3 (equipment) will extend `derive` with a `sources` parameter (named modifier layers) —
	an extension of this module, not a parallel system.

	@class StatFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatConstants = require(ReplicatedStorage.Shared.Modules.Constants.StatConstants)

export type PoolTotals = { main: number, sub: number }
export type Progress = { level: number, xpIntoLevel: number, xpToNext: number? }

local StatFormulas = {}

--[=[
	Cumulative XP at which `level` begins. xpForLevel(1) == 0. With the linear curve (xp to advance
	FROM level L is L * FACTOR), this is the closed-form sum FACTOR * (L-1) * L / 2.
	@param level number -- 1..MAX_LEVEL
	@return number
]=]
function StatFormulas.xpForLevel(level: number): number
	return StatConstants.XP_PER_LEVEL_FACTOR * (level - 1) * level / 2
end

--[=[
	The clamp for addExperience: total XP at which MAX_LEVEL begins. XP beyond this is discarded by
	design (chosen over banking overflow) — raising MAX_LEVEL later does NOT retro-credit capped XP.
	@return number
]=]
function StatFormulas.maxTotalXp(): number
	return StatFormulas.xpForLevel(StatConstants.MAX_LEVEL)
end

--[=[
	The level a lifetime XP total corresponds to, clamped to 1..MAX_LEVEL. Iterative walk of the
	boundaries: MAX_LEVEL is small (30) and this is not hot-path code, so clarity wins over a
	closed-form inverse.
	@param totalXp number -- Lifetime XP (>= 0)
	@return number
]=]
function StatFormulas.levelOf(totalXp: number): number
	local level = 1
	while level < StatConstants.MAX_LEVEL and totalXp >= StatFormulas.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

--[=[
	UI-facing progress: the level, xp into it, and xp needed for the next (nil at max level).
	@param totalXp number
	@return Progress
]=]
function StatFormulas.progress(totalXp: number): Progress
	local level = StatFormulas.levelOf(totalXp)
	local xpIntoLevel = totalXp - StatFormulas.xpForLevel(level)
	local xpToNext: number? = if level >= StatConstants.MAX_LEVEL
		then nil
		else level * StatConstants.XP_PER_LEVEL_FACTOR
	return { level = level, xpIntoLevel = xpIntoLevel, xpToNext = xpToNext }
end

--[=[
	Points earned by reaching `level`: (level - 1) per-level grants — level 1 has earned nothing.
	@param level number
	@return PoolTotals
]=]
function StatFormulas.pointsEarned(level: number): PoolTotals
	local levelsGained = level - 1
	return {
		main = levelsGained * StatConstants.POINTS_PER_LEVEL.main,
		sub = levelsGained * StatConstants.POINTS_PER_LEVEL.sub,
	}
end

--[=[
	Points spent, summed per pool from the investments map. Unknown keys are ignored here — the slice
	validator rejects them before they can be stored, so tolerating them keeps this function total.
	@param investments { [string]: number }
	@return PoolTotals
]=]
function StatFormulas.pointsSpent(investments: { [string]: number }): PoolTotals
	local spent = { main = 0, sub = 0 }
	for id, points in investments do
		local definition = StatConstants.DEFINITIONS[id]
		if definition then
			spent[definition.pool] += points
		end
	end
	return spent
end

--[=[
	Unspent = earned(levelOf(totalXp)) - spent(investments). DERIVED, never stored: there is no pool
	counter to inflate, which is what makes point conservation structural rather than checked.
	@param totalXp number
	@param investments { [string]: number }
	@return PoolTotals
]=]
function StatFormulas.pointsUnspent(totalXp: number, investments: { [string]: number }): PoolTotals
	local earned = StatFormulas.pointsEarned(StatFormulas.levelOf(totalXp))
	local spent = StatFormulas.pointsSpent(investments)
	return { main = earned.main - spent.main, sub = earned.sub - spent.sub }
end

--[=[
	The derived stat values for a build: base + points * perPoint for EVERY registered stat (a
	missing investment key means zero points). This is the single funnel every consumer reads
	through — Humanoid application, future combat, and client UI all call this.
	@param investments { [string]: number }
	@return { [string]: number } -- keyed by stat id
]=]
function StatFormulas.derive(investments: { [string]: number }): { [string]: number }
	local derived: { [string]: number } = {}
	for id, definition in StatConstants.DEFINITIONS do
		local points = investments[id] or 0
		derived[id] = definition.base + points * definition.perPoint
	end
	return derived
end

return StatFormulas
```

- [ ] **Step 4: Run the gate to verify it passes** — PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.luau src/ReplicatedStorage/Shared/Modules/Utils/StatFormulas.spec.luau
git commit -m "feat(stats): add StatFormulas pure derive module"
```

---

### Task 3: The slice wiring (types, manifest, client atom)

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` (`StatsSlice`, `PlayerSlot.stats`)
- Modify: `src/ReplicatedStorage/Shared/State/SliceManifest.luau` (one `stats` entry)
- Modify: `src/ReplicatedStorage/Client/State/ClientStore.luau` (atom + registry line)
- Test: `SliceManifest.spec.luau`, plus EVERY spec fixture that builds a `PlayerSlot`

**Interfaces (produces):**
- `PlayerDataTypes.StatsSlice = { totalXp: number, investments: { [string]: number } }`
- `PlayerSlot` gains `stats: StatsSlice`
- `SliceManifest.DEFINITIONS.stats.read = function(profile) return profile.slots[profile.slotState.active].stats end`
- `ClientStore.stats` — `Charm.atom(nil :: PlayerDataTypes.StatsSlice?)` (nil until first sync, like `currency`)

**THE FIXTURE SWEEP IS THE RISK.** `PlayerSlot` gaining a required field means every spec fixture that constructs a slot must gain `stats = { totalXp = 0, investments = {} }`. Grep `slots = {` and `currency =` across `src/**/*.spec.luau` and update EVERY profile fixture. `SliceManifest`'s boot assert will also fail if `ClientStore` lacks the atom — that is by design; add both together.

**Fixture default rule:** non-active slots use the template default (`totalXp = 0, investments = {}`) — exactly what `registerSlot` (Task 4) stamps.

- [ ] **Step 1: Write the failing spec**

Add to `SliceManifest.spec.luau`'s slot-scoped-readers describe (extend the existing `profileWith` fixture with a `stats` field per slot):

```lua
it("reads stats from the ACTIVE slot", function()
	local profile = profileWith(2)
	profile.slots[2].stats = { totalXp = 777, investments = { health = 1 } }
	expect(SliceManifest.DEFINITIONS.stats.read(profile).totalXp).to.equal(777)
end)
```

- [ ] **Step 2: Gate** — FAIL (`stats` not a field of `PlayerSlot` / no manifest entry).

- [ ] **Step 3: Implement**

`PlayerDataTypes.luau`:

```lua
--[=[
	The persisted progression state — deliberately TWO fields. Level is DERIVED from totalXp
	(StatFormulas.levelOf) and unspent point pools are DERIVED (earned - invested), so neither can
	desync and neither can be inflated. Do not add stored level/pool counters back.
]=]
export type StatsSlice = {
	totalXp: number,
	investments: { [string]: number },
}
```

and `stats: StatsSlice` on `PlayerSlot`.

`SliceManifest.luau` — one entry, same shape as its siblings:

```lua
	stats = {
		read = function(profile)
			return profile.slots[profile.slotState.active].stats
		end,
	},
```

`ClientStore.luau` — atom + registry line, mirroring `currency` exactly:

```lua
local stats = Charm.atom(nil :: PlayerDataTypes.StatsSlice?)
```
plus `stats = stats` in BOTH the `ClientStore` table and the `atoms` registry.

Then the fixture sweep: every constructed `PlayerSlot` in every spec gains `stats = { totalXp = 0, investments = {} }`. Hand-trace each through the mirror (`syncFromProfile` → `stats` reader) — a slot missing `stats` makes the reader return nil and `setSlice`'s copyDeep THROW at runtime.

- [ ] **Step 4: Gate** — PASS. Paste `grep -rn "stats = {" src/ --include=*.spec.luau | wc -l` in the report to show the sweep happened.

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat(stats): wire the stats slice through types, manifest, and client store"
```

---

### Task 4: `StatsServiceServer`

**Files:**
- Create: `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau`
- Test: `src/ServerScriptService/Services/StatsService/StatsServiceServer.spec.luau`

**Interfaces:**
- Consumes: `SliceOwner.registerSlot`, `StatFormulas`, `StatConstants`, `Guard`.
- Produces:

```lua
export type StatsServiceServer = {
	dependencies: { string }, -- { "PlayerDataServiceServer" }
	init: (self) -> (),
	start: (self) -> (),  -- wires Humanoid application (see below)
	getStats: (self, userId: number) -> PlayerDataTypes.StatsSlice?,
	getProgress: (self, userId: number) -> StatFormulas.Progress?,
	getDerived: (self, userId: number) -> { [string]: number }?,
	getUnspentPoints: (self, userId: number) -> StatFormulas.PoolTotals?,
	addExperience: (self, userId: number, amount: number) -> (boolean, boolean), -- (changed, leveledUp)
	invest: (self, userId: number, statId: string, points: number) -> (boolean, string?),
	respec: (self, userId: number) -> boolean,
	applyToCharacter: (self, player: Player) -> (),
	statsOp: (self, userId: number, fn: (PlayerDataTypes.StatsSlice) -> boolean) -> PlayerDataService.TransactionOperation,
}
```

**The validator** (registered with the slice — holds for ANY write path, including raw transaction ops):

```lua
local function validateStats(stats: PlayerDataTypes.StatsSlice): (boolean, string?)
	-- totalXp: integer, 0 .. maxTotalXp (the no-overflow clamp is also a stored invariant)
	if type(stats.totalXp) ~= "number" or stats.totalXp ~= math.floor(stats.totalXp) then
		return false, `totalXp must be an integer, got {stats.totalXp}`
	end
	if stats.totalXp < 0 or stats.totalXp > StatFormulas.maxTotalXp() then
		return false, `totalXp out of range ({stats.totalXp})`
	end
	-- investments: registered ids only, non-negative integers
	for id, points in stats.investments do
		if not StatConstants.isValidStatId(id) then
			return false, `"{id}" is not a registered stat`
		end
		if type(points) ~= "number" or points ~= math.floor(points) or points < 0 then
			return false, `investment "{id}" must be a non-negative integer, got {points}`
		end
	end
	-- conservation: spent may not exceed earned, per pool — an over-invested build is
	-- unrepresentable in stored data no matter which code path wrote it
	local unspent = StatFormulas.pointsUnspent(stats.totalXp, stats.investments)
	if unspent.main < 0 or unspent.sub < 0 then
		return false, `investments exceed earned points (main {unspent.main}, sub {unspent.sub})`
	end
	return true
end
```

Registration (module scope, like CurrencyService):

```lua
local statsSlice = SliceOwner.registerSlot("stats", {
	totalXp = 0,
	investments = {},
}, function(slot)
	return slot.stats
end, validateStats)
```

**Method semantics (implement exactly):**
- `addExperience`: `Guard.userId` + assert `amount` is a positive integer. Mutate: `totalXp = math.min(totalXp + amount, StatFormulas.maxTotalXp())`; return false-change if already capped. `leveledUp = levelOf(after) ~= levelOf(before)` — computed around the mutate, no loop. Audit-log level-ups.
- `invest`: validate statId (`StatConstants.isValidStatId` — return `(false, reason)` not throw, this will eventually be player-driven), `Guard` the points (positive integer). Check `pointsUnspent` for the stat's pool BEFORE mutating (friendly error); the data-layer validator is the backstop. Mutate: `investments[statId] = (investments[statId] or 0) + points`.
- `respec`: mutate `investments = {}` — wipe every key in place (`for id in stats.investments do stats.investments[id] = nil end`), return whether anything was cleared. NOTE: mutate the TABLE in place; do not assign a fresh table over the slice field you were handed (the mutator receives the value — reassigning the local would write nothing).
- `applyToCharacter(player)`: read `getDerived`; set `character.Humanoid.MaxHealth = derived.health`, and clamp `Humanoid.Health` to the new max only if it now exceeds it. Guard every instance access (`FindFirstChildOfClass("Humanoid")`), no-op if absent.
- `start()`: wire Humanoid application — on `Players.PlayerAdded`/`CharacterAdded` (use the `Observers` package if PlayerDataService uses it — READ how PlayerDataService wires `observePlayer` and mirror it), apply on spawn. Also re-apply after `invest`/`respec`/`addExperience` change the build (call `applyToCharacter` from those methods when the player is present — `Players:GetPlayerByUserId`).
- `statsOp`: SliceOwner's `op` surfaced, like `currencyOp`.

**Spec cases (write them ALL — this is the phase's core coverage):** follow `CurrencyServiceServer.spec.luau`'s mock pattern exactly (mocked PlayerDataService with `getActiveSlot`/`getSlotEpoch`/`_getSlotShell`/dotted-path `mutate`).
- addExperience: accumulates; clamps at maxTotalXp (and returns false-change once capped); reports leveledUp exactly when a boundary is crossed, including a single grant crossing several levels; rejects non-positive/non-integer amounts.
- invest: succeeds and decrements derived-unspent; refuses unknown statId with a reason; refuses when the pool lacks points AND WRITES NOTHING; accumulates onto an existing investment.
- respec: clears all investments; unspent == earned afterwards; false when nothing to clear.
- validator (call it directly, like validateCurrency's spec does): rejects unknown id, negative investment, fractional totalXp, totalXp above cap, over-invested build; accepts a maximal legal build.
- slot isolation: invest on slot 1, `getForSlot(userId, 2)` build untouched (re-proves the Phase 1 guarantee on a second domain).
- applyToCharacter: with a fake player+character table, MaxHealth becomes `derive(investments).health`.

- [ ] **Steps: spec first → gate FAIL → implement → gate PASS → commit**

```bash
git add src/ServerScriptService/Services/StatsService/
git commit -m "feat(stats): add StatsServiceServer with derived progression and conservation validator"
```

---

### Task 5: `StatsServiceClient`

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/StatsService/StatsServiceClient.luau`
- Test: `src/ReplicatedStorage/Client/Services/StatsService/StatsServiceClient.spec.luau`

**Interfaces:**
- Consumes: `ClientStore.stats` (Task 3), `StatFormulas` (Task 2).
- Produces — a thin read facade, mirroring `CurrencyServiceClient` exactly (no listeners, no cache):

```lua
export type StatsServiceClient = {
	dependencies: { string }, -- {}
	getStats: (self) -> PlayerDataTypes.StatsSlice?,
	getProgress: (self) -> StatFormulas.Progress?,   -- StatFormulas.progress over the atom, nil before first sync
	getDerived: (self) -> { [string]: number }?,
	getUnspentPoints: (self) -> StatFormulas.PoolTotals?,
	getState: (self) -> { [string]: any },
}
```

Reactive UI reads `ClientStore.stats` directly with `useAtom` and calls `StatFormulas` in render — this facade is for imperative callers, same doc rationale as CurrencyServiceClient. Every getter returns nil until the first sync lands (read the atom once, compute from it).

Spec: seed the atom directly (`ClientStore.stats({ totalXp = 160, investments = { health = 2 } })`), assert `getProgress().level == 4`, `getDerived().health == 210`, `getUnspentPoints()` matches `StatFormulas.pointsUnspent`; nil-before-sync case (`ClientStore.stats(nil)` → all getters nil). Restore the atom to nil in `afterEach`.

- [ ] **Steps: spec first → gate FAIL → implement → gate PASS → commit**

```bash
git add src/ReplicatedStorage/Client/Services/StatsService/
git commit -m "feat(stats): add StatsServiceClient read facade"
```

---

### Task 6: Cmdr commands + docs touch-up

**Files:**
- Create: `src/ServerScriptService/Commands/GiveXp.luau` + `GiveXpServer.luau`
- Create: `src/ServerScriptService/Commands/InvestStat.luau` + `InvestStatServer.luau`
- Create: `src/ServerScriptService/Commands/RespecStats.luau` + `RespecStatsServer.luau`
- Create: `src/ReplicatedStorage/Shared/CmdrTypes/statId.luau` (enum type from `StatConstants.STAT_IDS` — copy `currencyType.luau`'s `MakeEnumType` shape exactly)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (exempt the six command files + the CmdrTypes file, same precedent as the slot commands)

All `Group = "Admins"` (fail-closed hook covers permissions). Definitions copy `AddCurrency.luau`'s shape. Implementations are one-line passthroughs that surface the service's rejection reason:

`GiveXpServer.luau`:
```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StatsService = require(ServerScriptService.Services.StatsService.StatsServiceServer)

return function(_context, target: Player, amount: number): string
	local changed, leveledUp = StatsService:addExperience(target.UserId, amount)
	if not changed then
		return `{target.Name} is already at max level`
	end
	local progress = StatsService:getProgress(target.UserId)
	local level = if progress then progress.level else 0
	return if leveledUp
		then `Gave {amount} XP - {target.Name} is now level {level}!`
		else `Gave {amount} XP to {target.Name} (level {level})`
end
```

`InvestStatServer.luau` surfaces `invest`'s `(ok, reason)`; `RespecStatsServer.luau` reports whether anything was refunded. `InvestStat.luau`'s stat argument uses the `statId` Cmdr type; amounts use `integer`.

- [ ] **Steps: definitions + implementations → SpecRoots exemptions (with reasons) → gate PASS → commit**

```bash
git add src/ServerScriptService/Commands/ src/ReplicatedStorage/Shared/CmdrTypes/statId.luau src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(stats): add givexp/investstat/respecstats admin commands"
```

---

## Done when

- `bash scripts/check.sh` fully green (the `LoadCharacter` warning is the only accepted output).
- Full TestEZ suite green **on the PR** (base = `feat/player-data-slots`). Baseline 534 + this phase's new tests.
- No `::` casts added.
- In Studio: `givexp <you> 160` → level 4; `investstat <you> health 3` → MaxHealth rises to 215 on respawn AND immediately; `respecstats <you>` → points back; switching slots shows each slot's own build.
- Slot isolation re-proven: slot 2's stats untouched by slot 1's investments.

## Deliberately NOT in this phase (from the spec)

Modifier-source engine (Phase 3 extends `derive`); skill points/tree; XP sources (domains call `addExperience` when they port); telemetry (FUTURE NOTE only — not scheduled); per-point uninvest (respec covers it); stamina/rot runtime resource loops (combat phase consumes the derived values this phase produces).
