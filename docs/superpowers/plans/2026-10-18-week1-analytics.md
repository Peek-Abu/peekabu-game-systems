# Week 1 Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every launch experiment gets a stable 50/50 variant (per player from userId, per crew from the crew id). The first-time funnel, the economy and the Gloom coat each send Roblox analytics events, and every event carries its relevant variants, platform, party size, new vs returning, and build.

**Architecture:** A new server feature **Experiment** owns the registry and the assignment: a pure hash over `experimentId:unit`, plus a Workspace override for testing. Other systems read it through `ExperimentServiceServer:crewVariant` / `:playerVariant`. The Analytics feature gets a game-branch session layer, `AnalyticsSessionSystem`, started by `AnalyticsServiceServer`, which runs in both places. It owns the context field, platform intake, the cohort, the once-per-session assignment log, the first-time funnel and the economy watch. Shift's existing 13 events switch from `ShiftVariantRules`' single A/B to that context, and Shift adds the funnel steps and coat events that happen in a shift.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ (`.spec.luau` siblings), Roblox AnalyticsService (custom, funnel, economy), SignalTyped, ByteNet (the existing `Platform` packet).

**Spec:** `docs/superpowers/specs/2026-10-18-odd-hours-build-week-1-design.md` §5 "Analytics events". Also read `AGENTS.md`, `docs/project-structure.md`, `docs/testing.md`.

## Approval needed

Nothing here is approval-gated. There is no new subfolder kind, no new role word, and no second service in a feature. The developer may still want to veto two placement calls:

1. **New feature `Experiment`** (server only), added on the game branch `game/cleanup-crew`, not in base. Experiments are generic enough for base, but the game branch never merges into base, so a base port would be a separate `base/*` PR later.
2. **`AnalyticsServiceServer` (a base module) gets game-branch code.** It gains `dependencies`, `start` and `stop`, and starts the new Analytics systems. This is the only cycle-free starter in both places. `ShiftAnalyticsSystem` requires `AnalyticsServiceServer`, and Shift is shift-place-only after week-1 part 1, so the hub cannot rely on Shift.

## Global Constraints

- `--!strict` everywhere. No `any`, no `::` casts.
- Spec-first: write each module's `<Name>.spec.luau` before the module, or add a `SpecRoots.EXEMPT_MODULES` line with a reason (Systems shells only).
- Module placement follows the "New modules" table below. After adding any module, run `python3 scripts/python/module_map.py --write`.
- Server-authoritative. The client only *reports* its platform, through the existing rate-limited `Platform` packet.
- Roblox custom events take **3 custom fields**, each capped at **50 characters** (`AnalyticsRules.MAX_NAME_LENGTH`).
- No player name, user id or chat text ever reaches a field. Shift events keep `ShiftAnalyticsUtils.token`'s vocabulary.
- Assignment is **50/50 and stable**. Per-player experiments key on `userId`. Per-crew experiments key on the crew id. Mechanics a crew shares (`exp-clean`, `exp-rehire`, `exp-friendskip`) are per crew. Everything else is per player.
- Each player's assignment is logged **once per server session** as its own event. Every other event carries only the experiments that affect it (at most **2**).
- "New vs returning" reads the saved first-seen timestamp from `2026-10-18-week1-currencies.md`'s v3 migration. This plan consumes it and never adds it.
- Tests run in Studio only: set Workspace attribute `RunTests = true`, press Play, read Output, stop, then remove `RunTests`. The last full count was **3828 passing**. Never run `check.sh`, `rojo`, or `wally` while the owner is connected.
- Lint and format only the files you changed: `selene <files>` and `stylua --check <files>`.
- Commits use plain messages with no `Co-Authored-By:` or other trailers. Never merge into base.

## Review Focus

1. **A typo'd experiment id, or the wrong unit,** passed to `crewVariant`/`playerVariant` must fail loudly in specs. It must not silently hand everyone variant 1. Test: Task 2 "errors on an unknown id / a per-player id asked per crew".
2. **Studio runs** have an empty JobId and negative test userIds. They must still assign deterministically: the crew id is `"studio"` and the key is `tostring(-1)`. Test: Task 2 "Studio crew id" and Task 1 "negative user ids".
3. **A long context field** would be cut silently at 50 characters by `AnalyticsRules`, which drops the build off the end. The longest possible field must fit. Test: Task 3 "the longest field fits in 50".
4. **A malformed `ExperimentOverride` attribute** (a number, garbage, an unknown id or variant) must be ignored, not thrown on, and must never yield a variant outside the registry. Test: Task 2, `ExperimentOverrideRules`.
5. **A zero change, a migration or admin reason, or an unknown currency** must send no economy event, and a sink's `amount` must be positive. Test: Task 8, `AnalyticsEconomyUtils.call`.

---

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Experiment | server | (root) | `ExperimentServiceServer` | The one door to variants: `crewVariant`, `playerVariant`, `variantOf`, `crewId`, `assignments`. |
| Experiment | server | Data | `ExperimentRegistry` | The launch experiments: id, name, unit, two variants. |
| Experiment | server | Utils | `ExperimentAssignUtils` | Pure stable hash and 50/50 bucket → variant. |
| Experiment | server | Rules | `ExperimentOverrideRules` | Parses and validates the developer's `ExperimentOverride` Workspace attribute. |
| Analytics | server | Data | `AnalyticsTypes` | Types: Cohort, Context, Sender, EconomyCall, CurrencyChange (spec-exempt, types only). |
| Analytics | server | Data | `AnalyticsConstants` | Build label, funnel name and steps, the new-player window, which experiments tag funnel and economy events. |
| Analytics | server | Utils | `AnalyticsContextUtils` | Pure: cohort from first-seen, tag string, build string, packed context field. |
| Analytics | server | Utils | `AnalyticsEconomyUtils` | Pure: one currency change → one economy call, or nil. |
| Analytics | server | State | `AnalyticsContextTracker` | Per-player platform and cohort, plus funnel-step and assignment-log dedupe. |
| Analytics | server | Systems | `AnalyticsSessionSystem` | Both places: platform intake, assignment log, context, funnel steps, hub funnel triggers (spec-exempt shell). |
| Analytics | server | Systems | `AnalyticsEconomySystem` | Watches the currency change signal and sends economy events (spec-exempt shell). |
| Shift | server | Systems | `ShiftAnalyticsCoatSystem` | Turns CoatServiceServer's signals into the 5 coat events (spec-exempt shell). |

Placement notes:
- Experiment is server-only (YAGNI): no client reads a variant in week 1.
- The hub-side analytics sits in **Analytics**, not Shift, because Shift is inert in the hub place (spec §1).
- The coat watcher sits in **Shift**, beside `ShiftAnalyticsWatchSystem`, because Shift owns the shift event vocabulary. It is a separate module so the watch stays under the 400-code-line cap.

Also add `Experiment` to the Cleanup Crew feature-name line in `docs/project-structure.md` ("Cleanup Crew … adds Cargo, Depot, …").

## Dependency order

```
AnalyticsServiceServer → AnalyticsSessionSystem → ExperimentServiceServer, QueueServiceServer, PlayerDataServiceServer
                       → AnalyticsEconomySystem → CurrencyServiceServer (Task 8), AnalyticsSessionSystem
ShiftAnalyticsSystem   → AnalyticsServiceServer, AnalyticsSessionSystem
ShiftAnalyticsCoatSystem → CoatServiceServer (Task 9), ShiftAnalyticsSystem
```

`ExperimentServiceServer` must never require anything in Analytics, and `AnalyticsSessionSystem` must never require `AnalyticsServiceServer` (it gets a `Sender` at `start`). Breaking either rule creates a require cycle.

Tasks 1–6 depend on nothing outside this plan. Task 7 needs the currencies plan's first-seen field. Task 8 needs the currencies plan's change signal. Task 9 needs the coat plan's signals. Tasks 7–9 are last and are blocked until those land.

---

### Task 1: Experiment registry and stable assignment

**Files:**
- Create: `src/ServerScriptService/Features/Experiment/Data/ExperimentRegistry.luau`
- Create: `src/ServerScriptService/Features/Experiment/Data/ExperimentRegistry.spec.luau`
- Create: `src/ServerScriptService/Features/Experiment/Utils/ExperimentAssignUtils.luau`
- Create: `src/ServerScriptService/Features/Experiment/Utils/ExperimentAssignUtils.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ExperimentRegistry.Unit = "player" | "crew"`
  - `ExperimentRegistry.Definition = { id: string, name: string, unit: Unit, variants: { string } }` (exactly 2 variants)
  - `ExperimentRegistry.get(id: string): Definition?`
  - `ExperimentRegistry.ids(): { string }` (board order)
  - `ExperimentRegistry.list(): { Definition }`
  - `ExperimentAssignUtils.fnv1a(text: string): number`
  - `ExperimentAssignUtils.mix(hash: number): number`
  - `ExperimentAssignUtils.hash(text: string): number`
  - `ExperimentAssignUtils.bucket(experimentId: string, unitKey: string): number` (returns 1 or 2)
  - `ExperimentAssignUtils.variantFor(definition: ExperimentRegistry.Definition, unitKey: string): string`

The registry data, in this order. `variants[1]` is the option listed first on the board. Coat and other plans must use these exact variant strings:

| id | name | unit | variants |
|---|---|---|---|
| `exp-rehire` | Rehire countdown after the 3rd layer | crew | `"5s"`, `"10s"` |
| `exp-clean` | Time to clean a layer off a teammate | crew | `"1.5s"`, `"3s"` |
| `exp-tutorial` | Tutorial length | player | `"3beats"`, `"5beats"` |
| `exp-friendskip` | Friends skip the tutorial | crew | `"skip"`, `"forced"` |
| `exp-unlock` | Site unlock pace | player | `"after3"`, `"after6"` |
| `exp-employee2` | Second employee timing | player | `"first"`, `"day2"` |
| `exp-stars` | Premium (Gleam) price ladder | player | `"steep"`, `"flat"` |
| `exp-coffee` | Coffee for the crew | player | `"1shift"`, `"10min"` |
| `exp-starter` | Starter pack placement | player | `"success"`, `"hubonly"` |
| `exp-timecard` | Timecard | player | `"5of7"`, `"streak7"` |
| `exp-locker` | Locker pity | player | `"pity10-50"`, `"pity8-40"` |

- [ ] **Step 1: Write the failing specs**

`ExperimentRegistry.spec.luau`:

```lua
local ExperimentRegistry = require(script.Parent.ExperimentRegistry)

return function()
	describe("ExperimentRegistry", function()
		it("lists the eleven launch experiments in board order", function()
			local ids = ExperimentRegistry.ids()
			expect(#ids).to.equal(11)
			expect(ids[1]).to.equal("exp-rehire")
			expect(ids[10]).to.equal("exp-timecard")
			expect(ids[11]).to.equal("exp-locker")
		end)

		it("gives every experiment a unique id, a unit and two distinct short variants", function()
			local seen = {}
			for _, def in ExperimentRegistry.list() do
				expect(seen[def.id]).to.equal(nil)
				seen[def.id] = true
				expect(string.match(def.id, "^exp%-%l[%l%d]*$")).to.be.ok()
				expect(def.unit == "player" or def.unit == "crew").to.equal(true)
				expect(#def.variants).to.equal(2)
				expect(def.variants[1]).never.to.equal(def.variants[2])
				for _, variant in def.variants do
					expect(#variant <= 8).to.equal(true)
					expect(string.match(variant, "^[%w%.]+$")).to.be.ok()
				end
			end
		end)

		it("assigns the crew-shared mechanics per crew and the rest per player", function()
			expect(ExperimentRegistry.get("exp-clean").unit).to.equal("crew")
			expect(ExperimentRegistry.get("exp-rehire").unit).to.equal("crew")
			expect(ExperimentRegistry.get("exp-friendskip").unit).to.equal("crew")
			expect(ExperimentRegistry.get("exp-stars").unit).to.equal("player")
			expect(ExperimentRegistry.get("exp-clean").variants[1]).to.equal("1.5s")
			expect(ExperimentRegistry.get("exp-rehire").variants[2]).to.equal("10s")
		end)

		it("is nil for an unknown id", function()
			expect(ExperimentRegistry.get("exp-nope")).to.equal(nil)
		end)
	end)
end
```

`ExperimentAssignUtils.spec.luau`. The golden values are FNV-1a 32-bit followed by the murmur3 `fmix32` finaliser. Changing them would reassign every live player, so they are pinned on purpose:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local ExperimentAssignUtils = require(script.Parent.ExperimentAssignUtils)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

return function()
	describe("hash", function()
		it("matches the FNV-1a reference values", function()
			expect(ExperimentAssignUtils.fnv1a("")).to.equal(2166136261)
			expect(ExperimentAssignUtils.fnv1a("a")).to.equal(3826002220)
		end)

		it("is pinned: changing it would reassign every player", function()
			expect(ExperimentAssignUtils.hash("exp-clean:1")).to.equal(2514140076)
			expect(ExperimentAssignUtils.hash("exp-clean:2")).to.equal(1450326417)
			expect(ExperimentAssignUtils.hash("exp-rehire:studio")).to.equal(2903978199)
			expect(ExperimentAssignUtils.hash("exp-stars:3000000001")).to.equal(3522039271)
		end)
	end)

	describe("bucket", function()
		it("is 1 for an even hash and 2 for an odd one", function()
			expect(ExperimentAssignUtils.bucket("exp-clean", "1")).to.equal(1)
			expect(ExperimentAssignUtils.bucket("exp-clean", "2")).to.equal(2)
		end)

		it("is stable for the same key", function()
			for _ = 1, 5 do
				expect(ExperimentAssignUtils.bucket("exp-tutorial", "156")).to.equal(2)
			end
		end)

		it("splits 10,000 sequential user ids close to 50/50", function()
			local ones = 0
			for userId = 1, 10000 do
				if ExperimentAssignUtils.bucket("exp-tutorial", tostring(userId)) == 1 then
					ones += 1
				end
			end
			expect(ones >= 4700 and ones <= 5300).to.equal(true)
		end)

		it("keeps two experiments independent for the same players", function()
			local combos = { 0, 0, 0, 0 }
			for userId = 1, 10000 do
				local key = tostring(userId)
				local index = (ExperimentAssignUtils.bucket("exp-tutorial", key) - 1) * 2
					+ ExperimentAssignUtils.bucket("exp-stars", key)
				combos[index] += 1
			end
			for _, count in combos do
				expect(count >= 2200 and count <= 2800).to.equal(true)
			end
		end)

		it("handles Studio's negative user ids", function()
			local bucket = ExperimentAssignUtils.bucket("exp-coffee", tostring(-1))
			expect(bucket == 1 or bucket == 2).to.equal(true)
		end)
	end)

	describe("variantFor", function()
		it("returns the definition's variant for the bucket", function()
			local def = ExperimentRegistry.get("exp-clean")
			expect(ExperimentAssignUtils.variantFor(def, "1")).to.equal("1.5s")
			expect(ExperimentAssignUtils.variantFor(def, "2")).to.equal("3s")
		end)
	end)
end
```

- [ ] **Step 2: Run the specs and confirm they fail**

Run them in Studio (Workspace `RunTests = true`, Play, read Output).
Expected: FAIL. Output shows a require error for `ExperimentRegistry` / `ExperimentAssignUtils`.

- [ ] **Step 3: Implement `ExperimentRegistry`**

The data comes from the table above. Build it as a frozen list, plus a frozen `{ [id]: Definition }` map for `get`. `ids()` and `list()` return copies.

- [ ] **Step 4: Implement `ExperimentAssignUtils`**

The bucket key is `` `{experimentId}:{unitKey}` ``. `bucket = (hash(key) % 2) + 1`. `variantFor(def, unitKey) = def.variants[bucket(def.id, unitKey)]`.

Luau numbers are doubles, so a 32-bit multiply must be split to stay exact (`a * b` can reach 2^56). Use this helper and these steps:

```lua
local TWO_32 = 4294967296
-- (a * b) mod 2^32 without losing precision: each partial product stays below 2^49.
local function mul32(a: number, b: number): number
	local aLow = a % 65536
	local aHigh = (a - aLow) / 65536
	return (aLow * b + ((aHigh * b) % 65536) * 65536) % TWO_32
end
-- fnv1a: h = 2166136261; for each byte: h = mul32(bit32.bxor(h, byte), 16777619)
-- mix (murmur3 fmix32): h ^= h >> 16; h = mul32(h, 0x85EBCA6B); h ^= h >> 13; h = mul32(h, 0xC2B2AE35); h ^= h >> 16
-- (use bit32.bxor and bit32.rshift)
```

- [ ] **Step 5: Run the specs and confirm they pass**

Run them in Studio.
Expected: all `ExperimentRegistry` and `ExperimentAssignUtils` cases PASS with 0 failures. The total rises by the cases added (baseline 3828).

- [ ] **Step 6: Lint, format, module map**

Run `selene` and `stylua --check` on the four files, then `python3 scripts/python/module_map.py --write`.
Expected: no findings; `docs/project-structure.md` gains an `### Experiment` block.

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Features/Experiment docs/project-structure.md
git commit -m "Experiment: launch registry and stable 50/50 assignment"
```

---

### Task 2: Overrides and ExperimentServiceServer

**Files:**
- Create: `src/ServerScriptService/Features/Experiment/Rules/ExperimentOverrideRules.luau`
- Create: `src/ServerScriptService/Features/Experiment/Rules/ExperimentOverrideRules.spec.luau`
- Create: `src/ServerScriptService/Features/Experiment/ExperimentServiceServer.luau`
- Create: `src/ServerScriptService/Features/Experiment/ExperimentServiceServer.spec.luau`
- Modify: `docs/project-structure.md`: add `Experiment` to the Cleanup Crew feature-name line.

**Interfaces:**
- Consumes: `ExperimentRegistry.get/ids/list`, `ExperimentAssignUtils.variantFor` (Task 1).
- Produces (other plans depend on these, so keep the exact names):
  - `ExperimentOverrideRules.parse(raw: unknown): { [string]: string }`
  - `ExperimentServiceServer.Source = "hash" | "override"`
  - `ExperimentServiceServer.Assignment = { experimentId: string, unit: ExperimentRegistry.Unit, variant: string, source: Source }`
  - `ExperimentServiceServer:crewVariant(crewId: string, experimentId: string) -> string`
  - `ExperimentServiceServer:playerVariant(player: Player, experimentId: string) -> string`
  - `ExperimentServiceServer:variantOf(player: Player, experimentId: string) -> string`: picks by the experiment's unit; crew experiments use `self:crewId()`.
  - `ExperimentServiceServer:crewId() -> string`: this server's crew, `if game.JobId == "" then "studio" else game.JobId`. A reserved Shift server holds exactly one crew, so it is stable through that crew's Another-shift replays.
  - `ExperimentServiceServer:assignments(player: Player, includeCrew: boolean) -> { Assignment }`: in registry order; crew experiments are included only when `includeCrew`.
  - `ExperimentServiceServer:getState() -> { [string]: any }`
  - Constant `ExperimentServiceServer.OVERRIDE_ATTRIBUTE = "ExperimentOverride"`. This is a Workspace string attribute such as `"exp-clean=3s, exp-rehire=10s"`, and it wins over the hash in any place.

- [ ] **Step 1: Write the failing specs**

`ExperimentOverrideRules.spec.luau`:

```lua
local ExperimentOverrideRules = require(script.Parent.ExperimentOverrideRules)

return function()
	describe("parse", function()
		it("reads id=variant pairs, trimming spaces", function()
			local parsed = ExperimentOverrideRules.parse(" exp-clean=3s , exp-rehire = 10s ")
			expect(parsed["exp-clean"]).to.equal("3s")
			expect(parsed["exp-rehire"]).to.equal("10s")
		end)

		it("drops unknown ids, unknown variants and malformed pairs", function()
			local parsed = ExperimentOverrideRules.parse("exp-nope=3s,exp-clean=4s,garbage,exp-stars=flat")
			expect(parsed["exp-nope"]).to.equal(nil)
			expect(parsed["exp-clean"]).to.equal(nil)
			expect(parsed["exp-stars"]).to.equal("flat")
		end)

		it("is empty for nil, a number or an empty string", function()
			expect(next(ExperimentOverrideRules.parse(nil))).to.equal(nil)
			expect(next(ExperimentOverrideRules.parse(42))).to.equal(nil)
			expect(next(ExperimentOverrideRules.parse(""))).to.equal(nil)
		end)
	end)
end
```

`ExperimentServiceServer.spec.luau`. It saves the attribute in `beforeAll`, restores it in `afterAll`, and uses fake players `{ UserId = n }`:

```lua
local Workspace = game:GetService("Workspace")

local ExperimentServiceServer = require(script.Parent.ExperimentServiceServer)

return function()
	local saved
	beforeAll(function()
		saved = Workspace:GetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE)
		Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, nil)
	end)
	afterAll(function()
		Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, saved)
	end)

	describe("playerVariant", function()
		it("is the hash variant for the player's user id", function()
			-- exp-clean is per crew; use a per-player one with a pinned key
			expect(ExperimentServiceServer:playerVariant({ UserId = 156 }, "exp-tutorial")).to.equal("5beats")
		end)

		it("errors on an unknown id", function()
			expect(function()
				ExperimentServiceServer:playerVariant({ UserId = 1 }, "exp-nope")
			end).to.throw()
		end)

		it("errors when asked per player for a per-crew experiment", function()
			expect(function()
				ExperimentServiceServer:playerVariant({ UserId = 1 }, "exp-clean")
			end).to.throw()
		end)
	end)

	describe("crewVariant", function()
		it("is the same for every member of one crew", function()
			expect(ExperimentServiceServer:crewVariant("studio", "exp-rehire")).to.equal("10s")
			expect(ExperimentServiceServer:crewVariant("studio", "exp-rehire")).to.equal("10s")
		end)

		it("errors when asked per crew for a per-player experiment", function()
			expect(function()
				ExperimentServiceServer:crewVariant("studio", "exp-stars")
			end).to.throw()
		end)
	end)

	describe("crewId", function()
		it("is studio when there is no JobId", function()
			if game.JobId == "" then
				expect(ExperimentServiceServer:crewId()).to.equal("studio")
			end
		end)
	end)

	describe("overrides", function()
		it("win over the hash, for both units", function()
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, "exp-rehire=5s,exp-tutorial=3beats")
			expect(ExperimentServiceServer:crewVariant("studio", "exp-rehire")).to.equal("5s")
			expect(ExperimentServiceServer:playerVariant({ UserId = 156 }, "exp-tutorial")).to.equal("3beats")
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, nil)
		end)
	end)

	describe("assignments", function()
		it("lists per-player experiments, plus crew ones only when asked, with their source", function()
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, "exp-stars=flat")
			local player = { UserId = 7 }
			local personal = ExperimentServiceServer:assignments(player, false)
			expect(#personal).to.equal(7)
			local all = ExperimentServiceServer:assignments(player, true)
			expect(#all).to.equal(10)
			for _, assignment in all do
				if assignment.experimentId == "exp-stars" then
					expect(assignment.variant).to.equal("flat")
					expect(assignment.source).to.equal("override")
				else
					expect(assignment.source).to.equal("hash")
				end
			end
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, nil)
		end)
	end)
end
```

The pinned expectations `exp-tutorial:156 → "5beats"` and `exp-rehire:studio → "10s"` follow from Task 1's pinned hashes (both odd → variant 2).

- [ ] **Step 2: Run the specs and confirm they fail**

Run them in Studio.
Expected: FAIL with require errors for `ExperimentOverrideRules` and `ExperimentServiceServer`.

- [ ] **Step 3: Implement `ExperimentOverrideRules.parse(raw: unknown): { [string]: string }`**

If `raw` is not a string, return `{}`. Split on `,`, then on `=`. Trim both sides. Keep a pair only when `ExperimentRegistry.get(id)` exists and `table.find(def.variants, variant)` succeeds.

- [ ] **Step 4: Implement `ExperimentServiceServer`**

Use the lean annotated literal (`export type ExperimentServiceServer = {...}` with methods as fields), with `dependencies = {}` and no `init` or `start`. The overrides are read fresh on each call, through `ExperimentOverrideRules.parse(Workspace:GetAttribute(OVERRIDE_ATTRIBUTE))`; when the attribute is unset this is one attribute read. Keep a local `resolve(def, unitKey): (string, Source)` that applies the override, then the hash.

Unknown ids and unit mismatches `error()` with the id and the unit in the message. These are programmer errors, and specs catch them. `getState` returns `{ crewId, overrides = <the parsed map> }` for the Debugger.

- [ ] **Step 5: Run the specs and confirm they pass**

Run them in Studio.
Expected: all cases PASS with 0 failures.

- [ ] **Step 6: Lint, format, module map, docs**

Run `selene` and `stylua --check` on the four files and `module_map.py --write`. Add `Experiment` to the Cleanup Crew feature line in `docs/project-structure.md`.

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Features/Experiment docs/project-structure.md
git commit -m "Experiment: service with crew and player variants and a Workspace override"
```

---

### Task 3: Analytics context building blocks

**Files:**
- Create: `src/ServerScriptService/Features/Analytics/Data/AnalyticsTypes.luau` (spec-exempt)
- Create: `src/ServerScriptService/Features/Analytics/Data/AnalyticsConstants.luau` and `AnalyticsConstants.spec.luau`
- Create: `src/ServerScriptService/Features/Analytics/Utils/AnalyticsContextUtils.luau` and `AnalyticsContextUtils.spec.luau`
- Create: `src/ServerScriptService/Features/Analytics/State/AnalyticsContextTracker.luau` and `AnalyticsContextTracker.spec.luau`
- Modify: `src/ServerScriptService/Features/Analytics/Rules/AnalyticsRules.luau` (+ its spec): add `describe`
- Modify: `src/ServerScriptService/Features/Analytics/AnalyticsServiceServer.luau`: the debug line shows the fields
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`: exempt `ServerScriptService.Features.Analytics.Data.AnalyticsTypes` with "type definitions only (no runtime logic)"

**Interfaces:**
- Consumes: `ExperimentRegistry.get` (Task 1, used by the constants spec).
- Produces:
  - `AnalyticsTypes.Cohort = "new" | "ret" | "unk"`
  - `AnalyticsTypes.Context = { tags: string, platform: string, party: number, cohort: Cohort, build: string }`
  - `AnalyticsTypes.EconomyCall = { flow: "source" | "sink", currency: string, amount: number, endingBalance: number, transactionType: string, sku: string? }`
  - `AnalyticsTypes.CurrencyChange = { currencyId: string, delta: number, balance: number, reason: string }`
  - `AnalyticsTypes.Sender = { custom: (player: Player, event: string, value: number?, fields: { string }?) -> (), funnel: (player: Player, step: number, stepName: string, fields: { string }?) -> (), economy: (player: Player, call: EconomyCall, fields: { string }?) -> () }` (plain functions, no `self`)
  - `AnalyticsConstants`:
    - `BUILD_LABEL = "w1"`
    - `FUNNEL = "first_time"`
    - `FUNNEL_STEPS = { "joined_hub", "boarded_truck", "shift_started", "first_cleanup", "first_pickup", "first_bank", "quota_met", "clocked_out", "results_viewed", "next_shift" }`
    - `NEW_WINDOW = 86400`
    - `ASSIGNMENT_EVENT = "experiment_assigned"`
    - `MAX_TAGS = 2`
    - `FUNNEL_EXPERIMENTS = { "exp-tutorial", "exp-friendskip" }`
    - `CURRENCY_EXPERIMENTS: { [string]: { string } } = { gleam = { "exp-stars", "exp-starter" }, credits = { "exp-unlock", "exp-employee2" }, gloom = { "exp-timecard" } }`
    - `stepNumber(name: string): number?`
  - `AnalyticsContextUtils.cohort(firstSeen: number?, now: number): Cohort`: `"unk"` when nil; `"new"` when `now - firstSeen < NEW_WINDOW`; otherwise `"ret"`.
  - `AnalyticsContextUtils.tags(variants: { string }): string`: joined with `"+"`, or `"-"` when empty.
  - `AnalyticsContextUtils.build(label: string, placeVersion: number): string`: `"w1-v42"`, or `"w1-dev"` when the place version is 0.
  - `AnalyticsContextUtils.field(context: Context): string`: `"{tags}|{platform}|{party}|{cohort}|{build}"`, with party floored and clamped to 0..99.
  - `AnalyticsContextTracker.new(): AnalyticsContextTracker` with methods:
    - `setPlatform(userId: number, platform: string): boolean`: the first non-`"unknown"` report wins.
    - `platformOf(userId: number): string`: default `"unknown"`.
    - `setCohort(userId: number, cohort: Cohort)`
    - `cohortOf(userId: number): Cohort`: default `"unk"`.
    - `markStep(userId: number, step: number): boolean`: true only the first time.
    - `markAssigned(userId: number): boolean`: true only the first time.
    - `forget(userId: number)`
  - `AnalyticsRules.describe(fields: { string }?): string`: `"[a|b|c]"`, or `""` for none.

- [ ] **Step 1: Write the failing specs**

`AnalyticsConstants.spec.luau`:
- "has the ten funnel steps in order, unique": `#FUNNEL_STEPS == 10`, `stepNumber("joined_hub") == 1`, `stepNumber("next_shift") == 10`, `stepNumber("nope") == nil`.
- "tags only known experiments, at most MAX_TAGS per event": every id in `FUNNEL_EXPERIMENTS` and every `CURRENCY_EXPERIMENTS` list is found by `ExperimentRegistry.get`, and every list is at most 2 long.

`AnalyticsContextUtils.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsContextUtils = require(script.Parent.AnalyticsContextUtils)
local AnalyticsRules = require(ServerScriptService.Features.Analytics.Rules.AnalyticsRules)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

return function()
	describe("cohort", function()
		it("is new inside the first day, returning after, unknown without a timestamp", function()
			expect(AnalyticsContextUtils.cohort(1000, 1000 + 86399)).to.equal("new")
			expect(AnalyticsContextUtils.cohort(1000, 1000 + 86400)).to.equal("ret")
			expect(AnalyticsContextUtils.cohort(nil, 5)).to.equal("unk")
		end)
	end)

	describe("tags", function()
		it("joins variants with + and is - for none", function()
			expect(AnalyticsContextUtils.tags({ "1.5s", "10s" })).to.equal("1.5s+10s")
			expect(AnalyticsContextUtils.tags({})).to.equal("-")
		end)
	end)

	describe("field", function()
		it("packs tags, platform, party, cohort and build", function()
			local field = AnalyticsContextUtils.field({
				tags = "1.5s+10s", platform = "phone", party = 3, cohort = "new", build = "w1-v12",
			})
			expect(field).to.equal("1.5s+10s|phone|3|new|w1-v12")
		end)

		it("clamps the party to 0..99", function()
			local field = AnalyticsContextUtils.field({ tags = "-", platform = "pc", party = 250, cohort = "ret", build = "w1-dev" })
			expect(field).to.equal("-|pc|99|ret|w1-dev")
		end)

		it("the longest field fits in the engine's 50 characters", function()
			local longest = 0
			for _, def in ExperimentRegistry.list() do
				for _, variant in def.variants do
					longest = math.max(longest, #variant)
				end
			end
			local tags = string.rep("x", longest) .. "+" .. string.rep("x", longest)
			local field = AnalyticsContextUtils.field({
				tags = tags, platform = "unknown", party = 99, cohort = "unk", build = "w1-v99999",
			})
			expect(#field <= AnalyticsRules.MAX_NAME_LENGTH).to.equal(true)
		end)
	end)

	describe("build", function()
		it("appends the place version, or dev", function()
			expect(AnalyticsContextUtils.build("w1", 42)).to.equal("w1-v42")
			expect(AnalyticsContextUtils.build("w1", 0)).to.equal("w1-dev")
		end)
	end)
end
```

`AnalyticsContextTracker.spec.luau`:
- "first platform report wins and unknown is refused": `setPlatform(1, "unknown") == false`; `setPlatform(1, "phone") == true`; `setPlatform(1, "pc") == false`; `platformOf(1) == "phone"`; `platformOf(2) == "unknown"`.
- "cohort defaults to unk": `cohortOf(1) == "unk"`; after `setCohort(1, "new")` it is `"new"`.
- "a funnel step and the assignment log count once per player": `markStep(1, 3) == true`, then `false`; `markStep(2, 3) == true`; `markAssigned(1) == true`, then `false`.
- "forget clears everything for that player": after `forget(1)`, `platformOf(1) == "unknown"`, `markStep(1, 3) == true`, `markAssigned(1) == true`.

`AnalyticsRules.spec.luau` (add):
- "describes fields for the debug log": `describe({ "a", "b" }) == "[a|b]"`, `describe(nil) == ""`, `describe({}) == ""`.

- [ ] **Step 2: Run the specs and confirm they fail**

Run them in Studio.
Expected: FAIL with require errors for the three new modules, and `AnalyticsRules.describe` is nil.

- [ ] **Step 3: Implement the four modules and `AnalyticsRules.describe`**

The bodies follow from the interfaces above. `AnalyticsConstants` is frozen data, and `stepNumber` is `table.find(FUNNEL_STEPS, name)`.

- [ ] **Step 4: Show fields in Studio's debug line**

In `AnalyticsServiceServer`, append `AnalyticsRules.describe(fields)` to the `label` that `custom`, `economy` and `funnel` pass to `send`, so Studio's `(studio, not sent)` line shows the context. Do not change `send`'s live path.

- [ ] **Step 5: Run the specs and confirm they pass**

Run them in Studio.
Expected: all cases PASS with 0 failures.

- [ ] **Step 6: Lint, format, module map**

Run `selene` and `stylua --check` on the changed files and `module_map.py --write`.

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Features/Analytics src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "Analytics: context field, cohort, funnel steps and per-player context tracker"
```

---

### Task 4: AnalyticsSessionSystem (both places): platform, assignment log, hub funnel

**Files:**
- Create: `src/ServerScriptService/Features/Analytics/Systems/AnalyticsSessionSystem.luau`
- Modify: `src/ServerScriptService/Features/Analytics/AnalyticsServiceServer.luau`: add `dependencies = { "PlayerDataServiceServer", "ExperimentServiceServer", "QueueServiceServer" }`, `start` and `stop`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau`:
  - Exempt `ServerScriptService.Features.Analytics.Systems.AnalyticsSessionSystem` with "Players/ByteNet/Queue/PlayerData shell (context, cohort, tags and dedupe are specced in AnalyticsContextUtils, AnalyticsContextTracker, ExperimentServiceServer)".
  - Update the `AnalyticsServiceServer` exemption reason to "AnalyticsService shell; starts AnalyticsSessionSystem (AnalyticsRules is specced)".

**Interfaces:**
- Consumes:
  - `ExperimentServiceServer:variantOf`, `:assignments`, `ExperimentRegistry.get` (Tasks 1–2)
  - Everything from Task 3
  - `QueueServiceServer:runsRole(role)`, `.departing: Signal<BasePart, { Player }>`, `.returned: Signal<Player, QueuePayload>`
  - `DepotConstants.ROLE_DEPOT / ROLE_SHIFT`
  - `PlayerDataServiceServer.profileLoaded: Signal<number>`
  - `ShiftEvents.packets.Platform`, `ShiftPlatformRules.parse`, `RequestHandler.wrap`
- Produces:
  - `AnalyticsSessionSystem.start(sender: AnalyticsTypes.Sender): () -> ()`: returns the stopper.
  - `AnalyticsSessionSystem.contextOf(player: Player, experimentIds: { string }, party: number): AnalyticsTypes.Context`
  - `AnalyticsSessionSystem.field(player: Player, experimentIds: { string }, party: number): string`
  - `AnalyticsSessionSystem.funnelStep(player: Player, stepName: string, detail: string?): boolean`: false for an unknown step, a repeat, or before `start`.
  - `AnalyticsSessionSystem.setParty(resolver: ((Player) -> number)?)`
  - `AnalyticsSessionSystem.partyOf(player: Player): number`: the resolver's answer, or 1.
  - `AnalyticsSessionSystem.tracker: AnalyticsContextTracker`: exposed for Task 7.
  - `AnalyticsSessionSystem.build(): string`

Behaviour (the shell; every decision is a specced module):
- **Tags** in `contextOf`: for each id, `ExperimentServiceServer:variantOf(player, id)`. A crew-unit experiment contributes `"-"` unless `QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)` is true: a hub server is not a crew. The list goes through `AnalyticsContextUtils.tags`.
- **Platform**: move the existing `RequestHandler.wrap` platform intake here, named `"AnalyticsPlatform"` with the same rate limit and `onReject = "count"`, writing to `tracker:setPlatform`. Shift's copy is removed in Task 5. Until then both listen, which is harmless.
- **On `profileLoaded(userId)`** (resolve the player with `Players:GetPlayerByUserId`; skip if nil):
  1. Task 7 sets the cohort here, first.
  2. If `tracker:markAssigned(userId)`, send `sender.custom(player, ASSIGNMENT_EVENT, nil, { experimentId, variant, `{unit}:{source}` })` for each entry of `ExperimentServiceServer:assignments(player, runsRole(ROLE_SHIFT))`.
  3. If `runsRole(ROLE_DEPOT)`, call `funnelStep(player, "joined_hub")`.
- **`departing(pad, party)`**: `funnelStep(member, "boarded_truck")` for each member.
- **`returned(player, payload)`**: `funnelStep(player, "next_shift", "hub")`.
- **`funnelStep`**: if `tracker:markStep`, call `sender.funnel(player, number, stepName, { field(player, FUNNEL_EXPERIMENTS, partyOf(player)), detail or "-" })`.
- **`PlayerRemoving`**: `tracker:forget(userId)`.

`AnalyticsServiceServer.start` builds the `Sender` from closures over its own `custom`, `funnel` and `economy`, then calls `AnalyticsSessionSystem.start(sender)` and keeps the stopper. `stop` runs it.

- [ ] **Step 1: Check the cycle-free rule before writing**

Run `grep -rn "Features.Analytics" src/ServerScriptService/Features/Experiment src/ServerScriptService/Features/Queue src/ServerScriptService/Features/PlayerData`.
Expected: no matches. Any match is a require cycle; stop and fix the dependency direction.

- [ ] **Step 2: Implement `AnalyticsSessionSystem` and the service's `start` and `stop`**

Build it as described above. The decisions are already specced in Tasks 1–3, so this shell is exempt.

- [ ] **Step 3: Run the full suite**

Run it in Studio.
Expected: 0 failures. `SpecRoots` raises no "unspecced module" error.

- [ ] **Step 4: Studio check: hub funnel and assignment log**

Play solo in Studio (not a test session). Set the Output filter to `AnalyticsServiceServer`.
Expected `(studio, not sent)` debug lines:
- eleven `custom experiment_assigned [exp-…|<variant>|player:hash]` / `[…|crew:hash]` lines;
- `funnel first_time 1 [<tags>|<platform>|1|unk|w1-dev|-]`;
- after boarding the truck, `funnel first_time 2 …`.

(The cohort reads `unk` until Task 7.)

- [ ] **Step 5: Lint, format, module map**

Run `selene` and `stylua --check` on the changed files and `module_map.py --write`.

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Analytics src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "Analytics: session system with platform intake, assignment log and hub funnel steps"
```

---

### Task 5: Shift events switch from the per-shift A/B to experiment context

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau` (+ spec)
- Modify: `src/ServerScriptService/Features/Shift/State/ShiftAnalyticsTracker.luau` (+ spec): drop `setPlatform`/`platformOf` and the platform half of `forget`
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsSystem.luau`
- Modify: `src/ServerScriptService/Features/Shift/Data/ShiftAnalyticsConstants.luau`: add `EXPERIMENTS = { "exp-clean", "exp-rehire" }`; remove `BUILD_LABEL`
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau:17`: `VARIANT_MODE` changes from `"alternate"` to `"fixed"`

**Interfaces:**
- Consumes:
  - `AnalyticsSessionSystem.contextOf`, `.setParty`, `.build` (Task 4)
  - `AnalyticsContextUtils.field` (Task 3)
- Produces:
  - `ShiftAnalyticsUtils.Context = { session: string, tags: string, platform: string, party: number, cohort: AnalyticsTypes.Cohort, build: string }` (`variant` is removed).
  - `ShiftAnalyticsUtils.Record`: `variant: string` is replaced by `tags: string` and `cohort: string`.
  - `ShiftAnalyticsUtils.contextField(context: Context): string` delegates to `AnalyticsContextUtils.field`.
  - `ShiftAnalyticsUtils.build` is removed (moved to `AnalyticsContextUtils.build`).

Why `VARIANT_MODE = "fixed"`: per spec §5, the per-crew experiments replace `ShiftVariantRules`' per-shift alternation as the analytics unit. The salvage-spawn A/B stays on its default B, and the `CleanupCrewVariant` Workspace override stays as a developer tool. `contract_started`'s target still reports `variantSource()` (now `"fixed"` or `"override"`).

- [ ] **Step 1: Update the failing specs**

In `ShiftAnalyticsUtils.spec.luau`, change the `context` fixture to `{ session = "job-1", build = "w1-v12", tags = "1.5s+10s", platform = "phone", party = 3, cohort = "new" }`. In the contextField, fields and record cases, assert:
- `ShiftAnalyticsUtils.contextField(context()) == "1.5s+10s|phone|3|new|w1-v12"`
- `fields(context(), details)[1] == "1.5s+10s|phone|3|new|w1-v12"`
- `record.tags == "1.5s+10s"` and `record.cohort == "new"`, replacing the old `record.variant == "B"`

Move the `build` cases to `AnalyticsContextUtils.spec` (they already exist there from Task 3) and delete them here.

Add a case "tags each shift event with the two crew experiments":
- `#ShiftAnalyticsConstants.EXPERIMENTS == 2`
- each id is found by `ExperimentRegistry.get`
- each has `unit == "crew"`

In `ShiftAnalyticsTracker.spec.luau`, delete the platform cases.

- [ ] **Step 2: Run the specs and confirm they fail**

Run them in Studio.
Expected: FAIL. The contextField and record expectations don't match, and `EXPERIMENTS` is nil.

- [ ] **Step 3: Implement**

- `ShiftAnalyticsUtils`: apply the new `Context` and `Record`; `contextField` delegates.
- `ShiftAnalyticsTracker`: drop the platform map.
- `ShiftAnalyticsSystem`:
  - `send` builds `context` from `AnalyticsSessionSystem.contextOf(player, ShiftAnalyticsConstants.EXPERIMENTS, party)` plus `session`.
  - `build` comes from `AnalyticsSessionSystem.build()`.
  - Delete `onPlatform` and the `Platform` listener from `start`.
  - In `start`, call `AnalyticsSessionSystem.setParty(function() return math.max(#ShiftAnalyticsSystem.crew(), 1) end)`; in `stop`, call `setParty(nil)`.
  - The log line prints `tags={record.tags} cohort={record.cohort}` in place of `variant=`.
  - `getState` drops `variant` but keeps `variantSource`.
- `ShiftConstants.VARIANT_MODE = "fixed"`, and update its comment.

- [ ] **Step 4: Run the full suite**

Run it in Studio.
Expected: 0 failures, including `ShiftVariantRules.spec` (unchanged; it is pure).

- [ ] **Step 5: Studio check**

Play solo through a shift start. Expected:
- a `ShiftAnalyticsSystem` info line, `contract_started target=fixed … tags=<1.5s|3s>+10s platform=pc party=1 cohort=unk build=w1-dev`;
- `grep -n "Platform" src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsSystem.luau` finds nothing (only Analytics takes the report now).

- [ ] **Step 6: Lint, format, file length**

Run `selene` and `stylua --check` on the changed files, then `python3 scripts/python/check_file_length.py`.
Expected: no findings, and every file is at most 400 code lines.

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Features/Shift src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau
git commit -m "Shift analytics: tag events with the crew experiments instead of the per-shift A/B"
```

---

### Task 6: Funnel steps in the shift

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau` (+ spec): add `newlyPunched`
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsSystem.luau` (`banked`)

**Interfaces:**
- Consumes: `AnalyticsSessionSystem.funnelStep(player, stepName, detail?)` (Task 4).
- Produces: `ShiftAnalyticsUtils.newlyPunched(before: { number }?, after: { number }?): { number }`, which returns the user ids in `after` that are not in `before`.

The steps and their triggers. "Crew" means each player in `ShiftAnalyticsSystem.crew()`. Dedupe is the tracker's, so "first_*" needs no extra state:

| Step | Trigger (in the watch unless noted) |
|---|---|
| `shift_started` | `onChanged` run begins → crew |
| `first_cleanup` | `onVacuumStarted` (running) → player |
| `first_pickup` | `onPickedUp` (running, cargo) → player |
| `first_bank` | `ShiftAnalyticsSystem.banked` → loader |
| `quota_met` | `onChanged` quota newly met → crew |
| `clocked_out` | `onChanged`: each id in `newlyPunched(previous.punched, state.punched)` → that player |
| `results_viewed` | `onChanged`: phase becomes `"results"` → crew present (server proxy: the review opens for everyone present) |
| `next_shift` detail `"replay"` | `onChanged` replay branch (beside `replay_started`) → crew |

`onChanged` returns early when the phase is not `running`. Move the `results` check above that return, and make `clocked_out` run in any phase where `punched` changes. Keep `before = state` first.

- [ ] **Step 1: Write the failing spec**

Add to `ShiftAnalyticsUtils.spec.luau`:

```lua
describe("newlyPunched", function()
	it("returns ids in after but not before", function()
		local ids = ShiftAnalyticsUtils.newlyPunched({ 1 }, { 1, 2, 3 })
		table.sort(ids)
		expect(#ids).to.equal(2)
		expect(ids[1]).to.equal(2)
		expect(ids[2]).to.equal(3)
	end)

	it("treats nil as nobody", function()
		expect(#ShiftAnalyticsUtils.newlyPunched(nil, nil)).to.equal(0)
		expect(#ShiftAnalyticsUtils.newlyPunched(nil, { 4 })).to.equal(1)
		expect(#ShiftAnalyticsUtils.newlyPunched({ 4 }, nil)).to.equal(0)
	end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

Run it in Studio.
Expected: FAIL, `newlyPunched` is nil.

- [ ] **Step 3: Implement `newlyPunched` and the triggers in the table**

- [ ] **Step 4: Run the full suite**

Run it in Studio.
Expected: 0 failures.

- [ ] **Step 5: Studio check: the whole funnel**

Play solo: join, board the truck, clean, pick up, bank, meet the quota, punch out, see results, then vote Another shift. Then repeat with Back to depot in a fresh Play.
Expected: `funnel first_time 1` through `10` each appear once per Play, in order. Step 10's last field is `replay` in the first run and `hub` in the second.

- [ ] **Step 6: Lint, format, file length, commit**

Run `selene`, `stylua --check` and `check_file_length.py` on the changed files.

```bash
git add src/ServerScriptService/Features/Shift
git commit -m "Shift analytics: first-time funnel steps from shift start to the next shift"
```

---

### Task 7: New vs returning from the saved first-seen timestamp

**Depends on:** the first-seen timestamp added by `docs/superpowers/plans/2026-10-18-week1-currencies.md`'s v2→v3 migration. Before Step 1, read that plan and note:
- the field's name and unit (expected `firstSeen: number`, `os.time()` seconds);
- the getter it exports.

If it exports no getter, stop and ask. Do not read the raw profile path.

**Files:**
- Modify: `src/ServerScriptService/Features/Analytics/Systems/AnalyticsSessionSystem.luau`
- Modify: `src/ServerScriptService/Features/Analytics/AnalyticsServiceServer.luau`: add the dependency of the service that owns the getter, if it is not already listed

**Interfaces:**
- Consumes:
  - the currencies plan's first-seen getter, written here as `readFirstSeen(userId: number): number?`
  - `AnalyticsContextUtils.cohort` (Task 3)
  - `AnalyticsSessionSystem.tracker` (Task 4)
- Produces: `tracker:cohortOf(userId)` reads `"new"` or `"ret"` once the profile has loaded. Every context field carries it.

- [ ] **Step 1: Add the specced decision for the edge cases**

Add to `AnalyticsContextUtils.spec.luau` a case "a first-seen in the future reads new, not negative-returning": `cohort(2000, 1000) == "new"`. Run it in Studio and expect it to PASS already (`1000 - 2000 < NEW_WINDOW`). It pins clock skew between servers.

- [ ] **Step 2: Implement**

In the `profileLoaded` handler, before the assignment log and `joined_hub`, call `tracker:setCohort(userId, AnalyticsContextUtils.cohort(readFirstSeen(userId), os.time()))`.

- [ ] **Step 3: Run the full suite**

Run it in Studio.
Expected: 0 failures.

- [ ] **Step 4: Studio check**

Play solo with a fresh test profile. Expected: `funnel first_time 1 [...|new|w1-dev|-]`. With a profile whose first-seen is more than a day old, the cohort reads `ret`.

- [ ] **Step 5: Lint, format, commit**

```bash
git add src/ServerScriptService/Features/Analytics
git commit -m "Analytics: new vs returning from the saved first-seen time"
```

---

### Task 8: Economy events for Gloom, Credits and Gleam

**Depends on:** the CurrencyServiceServer change signal from `2026-10-18-week1-currencies.md`. Before Step 1, read that plan and fill in this mapping (adapt only `AnalyticsEconomySystem`'s handler if the shape differs):
- the signal's name and arguments. Expected: `CurrencyServiceServer.changed: Signal<Player, string, number, number, string>`, meaning (player, currencyId, delta, balanceAfter, reason).
- the currency ids for Gloom, Credits and Gleam. Expected: `"gloom"`, `"credits"`, `"gleam"`. If Gleam (the `premium` slice) does not fire on that signal, record it under Open questions and ship Gloom and Credits.
- the reason vocabulary.

**Files:**
- Create: `src/ServerScriptService/Features/Analytics/Utils/AnalyticsEconomyUtils.luau` and `AnalyticsEconomyUtils.spec.luau`
- Create: `src/ServerScriptService/Features/Analytics/Systems/AnalyticsEconomySystem.luau` (spec-exempt: "CurrencyServiceServer signal shell (the event decision is specced in AnalyticsEconomyUtils)")
- Modify: `src/ServerScriptService/Features/Analytics/Data/AnalyticsConstants.luau` (+ spec): add `CURRENCY_NAMES = { gloom = "Gloom", credits = "Credits", gleam = "Gleam" }` and `TRANSACTION_TYPES: { [string]: string }`, mapping each currencies-plan reason to a Roblox `Enum.AnalyticsEconomyTransactionType` name (`"Gameplay"`, `"IAP"`, `"Shop"`, `"Onboarding"`, `"TimedReward"`, `"ContextualPurchase"`). Reasons that must not be logged (e.g. `"migration"`, `"admin"`) are absent.
- Modify: `AnalyticsServiceServer.luau`: add `"CurrencyServiceServer"` to `dependencies`, and start/stop `AnalyticsEconomySystem` with the same `Sender`.
- Modify: `SpecRoots.luau`: add the exemption.

**Interfaces:**
- Consumes:
  - `AnalyticsTypes.CurrencyChange`, `EconomyCall`, `Sender` (Task 3)
  - `AnalyticsSessionSystem.field`, `.partyOf` (Task 4)
  - the currencies plan's signal
- Produces:
  - `AnalyticsEconomyUtils.call(change: AnalyticsTypes.CurrencyChange): AnalyticsTypes.EconomyCall?`
  - `AnalyticsEconomySystem.start(sender: AnalyticsTypes.Sender): () -> ()`

- [ ] **Step 1: Write the failing spec**

`AnalyticsEconomyUtils.spec.luau`. Use the reasons you recorded; these examples assume `shift_pay → Gameplay` and `robux → IAP`:
- "a gain is a source at the display name": `call({ currencyId = "credits", delta = 120, balance = 340, reason = "shift_pay" })` returns `{ flow = "source", currency = "Credits", amount = 120, endingBalance = 340, transactionType = "Gameplay", sku = "shift_pay" }` (check each field).
- "a spend is a sink with a positive amount": `delta = -50` gives `flow == "sink"` and `amount == 50`.
- "nothing for a zero change, an unlogged reason, an unknown currency or an unknown reason":
  - `delta = 0` → nil
  - `reason = "migration"` → nil
  - `currencyId = "coins"` → nil
  - `reason = "who-knows"` → nil
- "non-finite deltas are dropped": `delta = 0/0` → nil.

Add to `AnalyticsConstants.spec`: "every currency with a name has its experiments, and every transaction type is a Roblox name". Every `CURRENCY_NAMES` key has a `CURRENCY_EXPERIMENTS` entry, and each `TRANSACTION_TYPES` value is found by `Enum.AnalyticsEconomyTransactionType:FromName(value)` (wrap it in `pcall`; it must succeed).

- [ ] **Step 2: Run the spec and confirm it fails**

Run it in Studio.
Expected: FAIL, `AnalyticsEconomyUtils` is not found.

- [ ] **Step 3: Implement `AnalyticsEconomyUtils.call` and `AnalyticsEconomySystem`**

The system:
- subscribes to the signal;
- for each non-nil `call(change)`, runs `sender.economy(player, call, { AnalyticsSessionSystem.field(player, CURRENCY_EXPERIMENTS[currencyId], AnalyticsSessionSystem.partyOf(player)) })`.

`AnalyticsServiceServer.economy`'s public signature is unchanged. The `Sender.economy` closure unpacks `EconomyCall` into it.

- [ ] **Step 4: Run the full suite**

Run it in Studio.
Expected: 0 failures.

- [ ] **Step 5: Studio check**

Finish a shift solo. Expected: `economy source Credits [<unlock>+<employee2>|pc|1|new|w1-dev]` and `economy source Gloom [...]` debug lines, one per change.

- [ ] **Step 6: Lint, format, module map, commit**

```bash
git add src/ServerScriptService/Features/Analytics src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "Analytics: economy events for Gloom, Credits and Gleam"
```

---

### Task 9: Gloom coat events (last)

**Depends on:** the coat plan's `CoatServiceServer` signals:
- `layerAdded(player: Player, layers: number, maxLayers: number)`
- `layerCleaned(target: Player, cleaner: Player)`
- `knockedOut(player: Player)`
- `rehired(player: Player)`
- `crewWiped()`

Before Step 1, confirm these exact names and arguments in the coat plan. Then run `grep -n "require(" src/ServerScriptService/Features/Coat/CoatServiceServer.luau`. It must not require `ShiftServiceServer`, `ShiftAnalyticsWatchSystem` or `ShiftAnalyticsCoatSystem`, or the require chain `ShiftServiceServer → ShiftAnalyticsWatchSystem → ShiftAnalyticsCoatSystem → CoatServiceServer` loops back. If it does, stop and raise it with the coat plan's owner.

**Files:**
- Modify: `src/ServerScriptService/Features/Shift/Data/ShiftAnalyticsConstants.luau`:
  - append `"layer_added"`, `"layer_cleaned"`, `"knocked_out"`, `"rehired"`, `"crew_wiped"` to `EVENTS` (13 → 18);
  - add WORDS `"down"`, `"out"`, `"teammate"`, `"truck"`, `"crew"`;
  - add `knocked_out` and `crew_wiped` to `INFO_EVENTS`.
- Modify: `src/ServerScriptService/Features/Shift/Utils/ShiftAnalyticsUtils.luau` (+ spec): add `layerOutcome`
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsCoatSystem.luau` (spec-exempt: "CoatServiceServer signal shell (event names, tokens and the layer outcome are specced in ShiftAnalyticsUtils)")
- Modify: `src/ServerScriptService/Features/Shift/Systems/ShiftAnalyticsWatchSystem.luau`: `keep(ShiftAnalyticsCoatSystem.start())` in `start`
- Modify: `SpecRoots.luau`: add the exemption

**Interfaces:**
- Consumes:
  - `ShiftAnalyticsSystem.emit`, `.shift`, `.quotaTag`, `.elapsed`, `.crew` (existing)
  - the coat signals listed above
- Produces:
  - `ShiftAnalyticsUtils.layerOutcome(layers: number, maxLayers: number): string`: `"out"` when `layers >= maxLayers`, else `"down"`.
  - `ShiftAnalyticsCoatSystem.start(): () -> ()`

Each event is sent only while the shift is `running`, and goes through `ShiftAnalyticsSystem.emit`, so it carries the `exp-clean` and `exp-rehire` tags automatically:

| Event | Scope | target | outcome | reason | value |
|---|---|---|---|---|---|
| `layer_added` | player | `"harlow"` | `layerOutcome(layers, maxLayers)` | — | `layers` |
| `layer_cleaned` | cleaner | `"teammate"` | `quotaTag()` | — | `elapsed()` |
| `knocked_out` | player | `"harlow"` | `quotaTag()` | `"solo"` if `#crew() <= 1` else `"crew"` | `elapsed()` |
| `rehired` | player | `"truck"` | `quotaTag()` | — | `elapsed()` |
| `crew_wiped` | `"crew"` | `"harlow"` | `"wiped"` | — | `elapsed()` |

- [ ] **Step 1: Update and write the failing specs**

In `ShiftAnalyticsUtils.spec.luau`:
- change "knows exactly the 13 spec events" to 18, and assert `isEvent("knocked_out") == true` and `isEvent("crew_wiped") == true`;
- add "keeps the coat words": `token("teammate") == "teammate"`, `token("out") == "out"`, `token("truck") == "truck"`, `token("crew") == "crew"`, `outcomeField({ outcome = "after_quota", reason = "solo" }) == "after_quota:solo"`;
- add "layerOutcome is out on the last layer": `layerOutcome(1, 3) == "down"`, `layerOutcome(3, 3) == "out"`, `layerOutcome(4, 4) == "out"` (the "+1 layer" modifier).

- [ ] **Step 2: Run the specs and confirm they fail**

Run them in Studio.
Expected: FAIL. `#EVENTS` is 13, and `layerOutcome` is nil.

- [ ] **Step 3: Implement the constants, `layerOutcome`, `ShiftAnalyticsCoatSystem`, and the watch hook-up**

- [ ] **Step 4: Run the full suite**

Run it in Studio.
Expected: 0 failures.

- [ ] **Step 5: Studio check: the spec's "Done when" for §5**

First, a 2-player Local Server shift with `ExperimentOverride = "exp-clean=3s,exp-rehire=10s"`. Run the coat ladder: grab, revive, grab with no rescue, then the last layer, out, and rehire.

Expected `ShiftAnalyticsSystem` lines:
- `layer_added target=harlow outcome=down … tags=3s+10s`, then `outcome=out`;
- `layer_cleaned target=teammate`;
- `knocked_out … reason=crew`;
- `rehired target=truck`;
- with both players out at once, `crew_wiped outcome=wiped`.

Then clear the override and repeat solo. Expected: `knocked_out … reason=solo`, and the tags are crew `studio`'s hash variants (`exp-rehire` = `10s`, per Task 1's pinned hash).

- [ ] **Step 6: Lint, format, file length, module map, commit**

```bash
git add src/ServerScriptService/Features/Shift src/ServerScriptService/Core/Testing/SpecRoots.luau docs/project-structure.md
git commit -m "Shift analytics: Gloom coat events (layer added, cleaned, knocked out, rehired, crew wiped)"
```

---

## Open questions (for the owner; defaults are in the plan)

1. ~~12 experiments~~ — resolved: the board has 11; `exp-locker` (Locker pity: Rare+ at 10 / Odd at 50 vs 8 / 40, per player) added to the registry.
2. **The salvage A/B** (`ShiftVariantRules`: salvage hidden under piles vs exposed) is set to fixed **B** by this plan. Should it be retired, or kept as an 11th registry experiment?
3. **The crew id = the shift server's JobId.** A crew keeps its variant across Another-shift replays on that server, and gets a fresh one on its next trip from the hub. The alternative is per shift (`JobId:shift`), which flips the variant between replays.
4. **"Results viewed"** is a server proxy: the results phase began while the player was present. A true "viewed" needs a client report packet.
5. **"New"** = first seen less than 24 h ago (`NEW_WINDOW`), the D0 definition.
6. **Currencies plan:** do Gleam (`premium`) changes fire on the Currency change signal, and what is the reason vocabulary? Task 8 maps reasons to Roblox transaction types.
7. **Coat plan:** `CoatServiceServer` must not require `ShiftServiceServer` (Task 9's cycle check). Shift should listen to Coat, not the reverse.

## Coordinator decisions (2026-10-18)

- Salvage A/B stays fixed to B and is not registered (not a board experiment).
- Crew id = the shift server's JobId (variant holds across replays on that server).
- "Results viewed" as a server proxy is fine for week 1.
- Gleam changes arrive on `MarketplaceServiceServer.premiumChanged` (currencies plan); subscribe to both signals.
