# Week 1 Currencies + Data Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gloom and Credits replace the placeholder `coins` as saved currencies, a finished shift pays every crew member still present its full Credits and Gloom in one write, profiles migrate v2 → v3 (coins removed, a saved first-seen stamp added), currency writes raise one typed change event for economy analytics, and "Whole crew out +5" is paid only on a real clock-out.

**Architecture:** `CurrencyConstants` defines `gloom` and `credits`; `CurrencyServiceServer` gains `grant` (several currencies, one `mutate`) and a `changed` signal fired after every successful write; `MarketplaceServiceServer` fires the same payload as `premiumChanged` for Gleam (the existing `premium` slice). A new `ShiftPaySystem` follows `ShiftServiceServer.changed` exactly like `RankShiftSystem` and pays on the first "results" state of each shift. A new server-only account slice `firstSeen` is owned by `AnalyticsFirstSeenSystem`; `PlayerDataMigrationSystem` gets migration v2 → v3. Pay text flips from "Gleam" to "Credits" through `ShiftConstants.CURRENCY_NAME`.

**Tech Stack:** Luau `--!strict`, Rojo, ProfileStore via `PlayerDataServiceServer`, SignalTyped, TestEZ (Studio only).

**Spec:** `docs/superpowers/specs/2026-10-18-odd-hours-build-week-1-design.md` — §4 "Currencies + data migration", §5 (first-seen for new vs returning, economy events), and "Owner answers already given" (Whole crew out +5 only on a real clock-out).

## Approval needed

None. Both new modules use existing subfolder kinds (`Systems/`) and role words (`System`), and no feature gets a second service. (The Analytics server feature gets its first `Systems/` folder; that is an existing kind.)

## Global Constraints

- `--!strict` everywhere; no `any`, no `::` casts in product code (spec files stay untyped).
- Spec first: every new module has a `<Name>.spec.luau` sibling; no new `SpecRoots.EXEMPT_MODULES` entries.
- Server-authoritative: only the server writes balances; all writes go through `PlayerDataServiceServer` (`mutate` / `transaction`).
- Pay rule (owner, verbatim): "every crew member still in the shift at the end gets the **full** pay (contract fee + commission on recovered valuables, overtime included), knocked-out players too; players who left mid-shift get nothing; paid on any ending, timeout included. Saved Gloom = the shift's Gloom scrapings, same full-crew rule."
- Migration v2 → v3: remove `coins`, start Gloom and Credits at 0 (no carry-over), add the saved first-seen timestamp; `CURRENT_VERSION` reads 3.
- Gleam is the existing `premium` account slice; player-facing name "Gleam". Week 1 is the balance only (no products).
- Amounts: today's formulas are the starting numbers (`CREDITS_PER_GLOOM = 1`, valuables at their banked value, x1.5 overtime already in the banked value).
- HUD and results say "Credits" wherever they said Gleam pay. Art keys named `gleam` (icons, palette, button variants) are art, not currency text: leave them.
- Module placement per `docs/project-structure.md`; after adding a module run `python3 scripts/python/module_map.py --write`.
- Tests: Studio only. Select `Workspace`, set attribute `RunTests = true`, Play, read Output, stop, then remove `RunTests` (or set it false). Last full count: 3828.
- Lint/format changed files only: `selene <files>` and `stylua <files>`. Do not run `scripts/check.sh`, `wally` or `rojo build` (owner rule: no installs/builds while the owner is connected).
- Commits: plain messages, no `Co-Authored-By:` or `Claude-Session:` trailers. Game branch only; nothing here goes to base.

## Review Focus

- A v2 profile holding a large `coins` balance loads, migrates, and can be written straight away (the currency validator must never see `coins` again) — Task 3 migration spec + CurrencyUtils spec.
- A crew member who is knocked out (caught) when the shift ends is still present and gets the full pay — Task 5 spec "pays a knocked-out member in full".
- Shift's state changes more than once while in "results" (each `setState` fires `changed`); a shift must pay once — Task 5 spec "pays each shift once".
- A grant that reaches `MAX_CURRENCY` is clamped; the change event reports the real delta and ending balance, and a fully absorbed grant fires nothing — Task 4 spec "reports the clamped delta".
- A timeout with the whole crew present and nobody caught pays no "Whole crew out" line — Task 1 spec.

## New modules

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|
| Analytics | server | Systems | AnalyticsFirstSeenSystem | Owns the server-only `firstSeen` account slice, stamps it on a profile's first load, answers new vs returning for the session |
| Shift | server | Systems | ShiftPaySystem | On the first "results" state of each shift, pays every present crew member the shift's full Credits and Gloom through one write each |

## Interfaces other plans rely on

- `CurrencyServiceServer.changed: SignalTyped.Signal<CurrencyConstants.CurrencyChange>` (Task 4) — fired after every successful Gloom/Credits write.
- `MarketplaceServiceServer.premiumChanged: SignalTyped.Signal<CurrencyConstants.CurrencyChange>` (Task 4) — same payload, `currency = "gleam"`.
- `CurrencyConstants.CurrencyChange = { userId: number, currency: EconomyCurrency, flow: "source" | "sink", amount: number, balance: number, reason: ChangeReason }` — `amount` is the absolute applied delta (> 0), `balance` the ending balance.
- `CurrencyConstants.EconomyCurrency = CurrencyType | "gleam"`; `CurrencyConstants.ChangeReason = "shiftPay" | "admin" | "other"` (week 2 adds its own reasons).
- `AnalyticsFirstSeenSystem.isNew(userId: number): boolean?` and `AnalyticsFirstSeenSystem.firstSeenAt(userId: number): number?` (Task 2) — nil until the profile has loaded this session.
- Sequencing: Task 2 edits `AnalyticsServiceServer.luau`, which the analytics plan also edits. Land Task 2 before the analytics plan starts, or hand it that one wiring step.

---

### Task 1: "Whole crew out +5" only on a real clock-out

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Rank/Utils/RankFormulas.luau:92-120` (`factsFor`), and its header comment
- Test: `src/ReplicatedStorage/Shared/Features/Rank/Utils/RankFormulas.spec.luau`

**Interfaces:**
- Consumes: `ShiftConstants.OUTCOME_CLOCKOUT`.
- Produces: `RankFormulas.factsFor(...)` unchanged signature; `crewExtracted` is now false unless `outcome == ShiftConstants.OUTCOME_CLOCKOUT`.

- [ ] **Step 1: Write the failing test** (inside `describe("factsFor")`, using the spec's `results`, `line`, `amountOf` helpers)

```lua
it("pays the whole-crew line only when the shift ended through the clock-out", function()
	local entries = RankFormulas.entriesOf(results({ line(1), line(2) }, true))
	expect(RankFormulas.factsFor(entries, true, { 1, 2 }, 1, "clockout").crewExtracted).to.equal(true)
	for _, outcome in { "timeout", "abandoned", "wiped", "cancelled" } do
		local f = RankFormulas.factsFor(entries, true, { 1, 2 }, 1, outcome)
		expect(f.crewExtracted).to.equal(false)
		expect(amountOf(RankFormulas.award(f), "crewExtracted")).never.to.be.ok()
	end
end)
```

- [ ] **Step 2: Run tests to verify it fails** — Studio run (see Global Constraints). Expected: this `it` fails (`crewExtracted` is true on "timeout").
- [ ] **Step 3: Implement** — in `factsFor`, `crewExtracted = everyone and outcome == ShiftConstants.OUTCOME_CLOCKOUT`. Update the header comment's "Extracted" paragraph to say the whole-crew line follows the same clock-out rule.
- [ ] **Step 4: Run tests to verify they pass** — Studio run. Expected: 0 failures.
- [ ] **Step 5: Lint/format** — `selene` and `stylua` on the two files.
- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Rank/Utils/RankFormulas.luau src/ReplicatedStorage/Shared/Features/Rank/Utils/RankFormulas.spec.luau
git commit -m "Rank: pay Whole crew out only on a real clock-out"
```

---

### Task 2: Saved first-seen stamp (`firstSeen` account slice)

**Files:**
- Create: `src/ServerScriptService/Features/Analytics/Systems/AnalyticsFirstSeenSystem.luau`
- Test: `src/ServerScriptService/Features/Analytics/Systems/AnalyticsFirstSeenSystem.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Data/PlayerDataTypes.luau` (add `export type FirstSeen = { at: number }`; `PlayerAccount.firstSeen: FirstSeen`)
- Modify: `src/ServerScriptService/Features/PlayerData/Data/PlayerDataConstants.luau` (`emptyAccount` gets `firstSeen = { at = 0 }`; header comment names the owner)
- Modify: `src/ServerScriptService/Features/Analytics/AnalyticsServiceServer.luau` (require the system at the top so the slice registers before PlayerData init; `dependencies = { "PlayerDataServiceServer" }`; add `start` calling `AnalyticsFirstSeenSystem.start()` and `stop` calling the returned stopper; add both to the exported type)
- Modify spec fixtures that spell out every account slice (add `firstSeen = { at = 0 }`): `StateSyncSliceRegistry.spec`, `CurrencyServiceServer.spec`, `DailyRewardServiceServer.spec`, `EntitlementServiceServer.spec`, `MarketplaceServiceServer.spec`, `PlayerDataServiceServer.spec`, `SettingServiceServer.spec`, `StateSyncServerStore.spec`, `TitleServiceServer.spec`
- Modify: `docs/project-structure.md` (module map, via the script)

**Interfaces:**
- Consumes: `PlayerDataSliceSystem.registerAccount(slice, default, read, validate)`, `PlayerDataServiceServer.profileLoaded: SignalTyped.Signal<number>`.
- Produces:
  - `AnalyticsFirstSeenSystem.BEFORE_TRACKING: number` = `1` (what the v3 migration stamps on pre-v3 accounts; Task 3).
  - `AnalyticsFirstSeenSystem.validate(value: PlayerDataTypes.FirstSeen): (boolean, string?)` — a table whose `at` is a whole number ≥ 0.
  - `AnalyticsFirstSeenSystem.decide(at: number, now: number): (boolean, number)` — `(true, now)` when `at == 0`, else `(false, at)`.
  - `AnalyticsFirstSeenSystem.start(): () -> ()` — on `profileLoaded` (and for already-loaded players at start) mutates the slice with `decide(at, os.time())`, remembers `isNew` per userId for the session, forgets on `PlayerRemoving`.
  - `AnalyticsFirstSeenSystem.isNew(userId: number): boolean?`, `AnalyticsFirstSeenSystem.firstSeenAt(userId: number): number?`.
  - The slice is server-only: it is NOT added to `StateSyncSliceRegistry` (like `receipts`).

- [ ] **Step 1: Write the failing spec** `AnalyticsFirstSeenSystem.spec.luau`

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataConstants = require(ServerScriptService.Features.PlayerData.Data.PlayerDataConstants)
local AnalyticsFirstSeenSystem = require(script.Parent.AnalyticsFirstSeenSystem)

return function()
	describe("AnalyticsFirstSeenSystem", function()
		it("registers firstSeen as an account slice that starts unstamped", function()
			expect(PlayerDataConstants.PROFILE_TEMPLATE.account.firstSeen.at).to.equal(0)
			expect(PlayerDataConstants.getValidator("account.firstSeen")).to.be.ok()
		end)
		it("marks accounts from before tracking as 1", function()
			expect(AnalyticsFirstSeenSystem.BEFORE_TRACKING).to.equal(1)
		end)
		it("validates a whole, non-negative stamp", function()
			expect(AnalyticsFirstSeenSystem.validate({ at = 0 })).to.equal(true)
			expect(AnalyticsFirstSeenSystem.validate({ at = 1760000000 })).to.equal(true)
			expect(AnalyticsFirstSeenSystem.validate({ at = -1 })).to.equal(false)
			expect(AnalyticsFirstSeenSystem.validate({ at = 1.5 })).to.equal(false)
			expect(AnalyticsFirstSeenSystem.validate({ at = "x" })).to.equal(false)
			expect(AnalyticsFirstSeenSystem.validate(nil)).to.equal(false)
		end)
		it("stamps an unstamped account now and calls it new", function()
			local isNew, at = AnalyticsFirstSeenSystem.decide(0, 1760000000)
			expect(isNew).to.equal(true)
			expect(at).to.equal(1760000000)
		end)
		it("keeps an existing stamp and calls it returning, including pre-tracking accounts", function()
			local isNew, at = AnalyticsFirstSeenSystem.decide(1750000000, 1760000000)
			expect(isNew).to.equal(false)
			expect(at).to.equal(1750000000)
			expect((AnalyticsFirstSeenSystem.decide(AnalyticsFirstSeenSystem.BEFORE_TRACKING, 1760000000))).to.equal(false)
		end)
		it("knows nothing about a player whose profile has not loaded", function()
			expect(AnalyticsFirstSeenSystem.isNew(-987654)).to.equal(nil)
			expect(AnalyticsFirstSeenSystem.firstSeenAt(-987654)).to.equal(nil)
		end)
	end)
end
```

- [ ] **Step 2: Run tests to verify it fails** — Studio run. Expected: the new spec errors requiring `AnalyticsFirstSeenSystem` (module missing).
- [ ] **Step 3: Implement** the system with the signatures above; registration at module load: `PlayerDataSliceSystem.registerAccount("firstSeen", { at = 0 }, function(account) return account.firstSeen end, AnalyticsFirstSeenSystem.validate)`. Then the type, skeleton, `AnalyticsServiceServer` wiring and spec fixtures listed under Files. Run `python3 scripts/python/module_map.py --write`.
- [ ] **Step 4: Run tests to verify they pass** — Studio run. Expected: 0 failures (`PlayerDataConstants.assertAllSlicesOwned` passes because `firstSeen` is registered). In the same Play, the Output shows no "never registered" error and the Debugger (F4) profile view shows `account.firstSeen.at` as a current unix time.
- [ ] **Step 5: Lint/format** changed `.luau` files.
- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Analytics src/ReplicatedStorage/Shared/Data/PlayerDataTypes.luau src/ServerScriptService/Features/PlayerData/Data/PlayerDataConstants.luau docs/project-structure.md <the spec fixtures>
git commit -m "Analytics: save a first-seen stamp per account for new vs returning"
```

---

### Task 3: Gloom and Credits replace coins, with migration v2 → v3

Do this as one task: once `coins` leaves `CurrencyConstants`, the currency validator refuses any write to a profile that still holds it, so the migration must land in the same change.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Currency/Data/CurrencyConstants.luau` (`CurrencyType = "gloom" | "credits"`; `CURRENCIES` and `CURRENCY_TYPE_MEMBERS` hold both; doc comment: coins placeholder retired, Gleam is the `premium` account slice)
- Modify: `src/ServerScriptService/Features/Currency/CurrencyServiceServer.luau:21` (default `{ gloom = 0, credits = 0 }`; doc comments say gloom/credits)
- Modify: `src/ServerScriptService/Features/PlayerData/Systems/PlayerDataMigrationSystem.luau` (append migration 2; header example stays)
- Modify (rename `coins` → `credits` where the value reaches the real currency slice, validator or `CurrencyConstants`; synthetic local names in other features may stay): `CurrencyConstants.spec`, `CurrencyUtils.spec`, `CurrencyServiceServer.spec`, `CurrencyServiceClient.spec`, `StateSyncClientStore.spec`, `StateSyncSliceRegistry.spec`, `StateSyncServerStore.spec`, `StateSyncServiceServer.spec`, `DebuggerStore.spec`, `PlayerDataServiceServer.spec`, `InventoryServiceServer.spec`, `PlayerDataMigrationSystem.spec`, `CurrencyAddServer.spec`, `CurrencySetServer.spec`
- Modify (doc text only): `src/ReplicatedStorage/Shared/Core/ServiceController.luau:83-84`, `src/ServerScriptService/Features/PlayerData/PlayerDataServiceServer.luau:501,850-871`, `src/ServerScriptService/Features/PlayerData/Data/PlayerDataConstants.luau` (`{ coins = 100 }` mention), `src/ServerScriptService/Commands/CurrencyAdd.luau` and `CurrencySet.luau` (arg Description "The type of currency (gloom, credits)")
- Modify: `src/ReplicatedStorage/Client/UI/React/Screens/Depot/DepotHub.luau:80` reads `"credits"` (keeps compiling; the prop rename is Task 6)

**Interfaces:**
- Consumes: `AnalyticsFirstSeenSystem.BEFORE_TRACKING` (value 1, hard-coded in the migration like the v1 → v2 one; the spec compares them).
- Produces: `CurrencyConstants.CurrencyType = "gloom" | "credits"`; definitions `gloom = { name = "Gloom", icon = "🫧" }`, `credits = { name = "Credits", icon = "💵" }` (icons are only used by the unused `formatCurrency`; the game draws art icons). `PlayerDataMigrationSystem.CURRENT_VERSION == 3`.

- [ ] **Step 1: Write the failing tests**

In `PlayerDataMigrationSystem.spec.luau` (`apply (production list)`): change the version test to `"has CURRENT_VERSION = 3 (two migrations registered)"` / `equal(3)`; change the v1 → v2 case's `expect(data._schemaVersion).to.equal(2)` to `equal(PlayerDataMigrationSystem.CURRENT_VERSION)`; add:

```lua
it("v2 -> v3 removes coins and starts Gloom and Credits at 0 in every slot", function()
	local data = {
		slots = { { currency = { coins = 640 } }, { currency = { coins = 5, gloom = 9, credits = 3 } } },
		account = { firstSeen = { at = 0 } },
	}
	expect(PlayerDataMigrationSystem.apply(data, 2)).to.equal("ok")
	for _, slot in data.slots do
		expect(slot.currency.coins).to.equal(nil)
		expect(slot.currency.gloom).to.equal(0)
		expect(slot.currency.credits).to.equal(0)
		expect(CurrencyUtils.validateCurrency(slot.currency)).to.equal(true)
	end
	expect(data._schemaVersion).to.equal(3)
end)

it("v2 -> v3 marks the account as seen before first-seen tracking", function()
	local data = { slots = {}, account = { firstSeen = { at = 0 } } }
	expect(PlayerDataMigrationSystem.apply(data, 2)).to.equal("ok")
	expect(data.account.firstSeen.at).to.equal(AnalyticsFirstSeenSystem.BEFORE_TRACKING)
end)

it("v2 -> v3 is safe on a profile without slots, currency or account", function()
	local data = { slots = { {} } }
	expect(PlayerDataMigrationSystem.apply(data, 2)).to.equal("ok")
	expect(data.slots[1].currency.credits).to.equal(0)
	expect(PlayerDataMigrationSystem.apply({}, 2)).to.equal("ok")
end)

it("v1 -> v3 runs both migrations", function()
	local data = { account = { settings = { values = { uiVolume = 1 } } }, slots = { { currency = { coins = 1 } } } }
	expect(PlayerDataMigrationSystem.apply(data, 1)).to.equal("ok")
	expect(data.account.settings.values.uiVolume).to.equal(nil)
	expect(data.slots[1].currency.coins).to.equal(nil)
	expect(data.account.firstSeen.at).to.equal(AnalyticsFirstSeenSystem.BEFORE_TRACKING)
end)
```

In `CurrencyConstants.spec.luau`: replace the coins cases with "defines gloom and credits with a name and icon" (`CURRENCIES.gloom.name == "Gloom"`, `CURRENCIES.credits.name == "Credits"`, icons are strings), `isValidCurrencyType("coins") == false`, `toCurrencyType("coins") == nil`, `toCurrencyType("credits") == "credits"`.

In `CurrencyUtils.spec.luau`: `validateCurrency({ coins = 1 })` returns `false` with a reason containing `"coins"`; `validateCurrency({ gloom = 0, credits = 0 })` returns `true`.

In `CurrencyServiceServer.spec.luau`: "a fresh save starts with 0 Gloom and 0 Credits" — `PlayerDataConstants.PROFILE_TEMPLATE.slots[1].currency.gloom == 0` and `.credits == 0`, and `.coins == nil`.

- [ ] **Step 2: Run tests to verify they fail** — Studio run. Expected: the new cases fail (`CURRENT_VERSION` is 2, coins still valid, default still 100).
- [ ] **Step 3: Implement** the constants, default, and migration 2:

```lua
-- v2 -> v3: the placeholder `coins` is retired; Gloom and Credits start at 0 (no carry-over: coins were a placeholder
-- and shift pay was never saved). Pre-v3 accounts are stamped as seen before first-seen tracking
-- (AnalyticsFirstSeenSystem.BEFORE_TRACKING = 1), so analytics counts them as returning.
function(data)
	if type(data.slots) == "table" then
		for _, slot in data.slots do
			if type(slot) == "table" then
				local currency = if type(slot.currency) == "table" then slot.currency else {}
				currency.coins = nil
				currency.gloom = 0
				currency.credits = 0
				slot.currency = currency
			end
		end
	end
	if type(data.account) == "table" then
		data.account.firstSeen = { at = 1 }
	end
end,
```

Then the spec-fixture renames and doc-text edits listed under Files.
- [ ] **Step 4: Run tests to verify they pass** — Studio run. Expected: 0 failures; count ≥ 3828 plus this plan's new cases. Then a normal Play (RunTests off): Output shows no migration warning; Debugger (F4) State tab shows `currency = { gloom = 0, credits = 0 }`; Cmdr `currencyadd me credits 5` reports "Added 5 credits".
- [ ] **Step 5: Lint/format** changed `.luau` files.
- [ ] **Step 6: Commit**

```bash
git add -A src
git commit -m "Currency: Gloom and Credits replace coins; migrate profiles to v3"
```

---

### Task 4: Currency change events for economy analytics

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Currency/Data/CurrencyConstants.luau` (export the types below)
- Modify: `src/ServerScriptService/Features/Currency/CurrencyServiceServer.luau` (`changed`, `grant`, optional `reason` on add/remove/set)
- Modify: `src/ServerScriptService/Features/Marketplace/MarketplaceServiceServer.luau` (`premiumChanged`, optional `reason` on `addPremium` / `spendPremium`)
- Modify: `src/ServerScriptService/Commands/CurrencyAddServer.luau`, `CurrencySetServer.luau`, `MarketplacePremiumAddServer.luau` (pass `"admin"`)
- Test: `CurrencyServiceServer.spec.luau`, `MarketplaceServiceServer.spec.luau`, `CurrencyAddServer.spec.luau`, `CurrencySetServer.spec.luau`, `MarketplacePremiumAddServer.spec.luau`

**Interfaces:**
- Produces (in `CurrencyConstants`):
  - `export type EconomyCurrency = CurrencyType | "gleam"`
  - `export type ChangeReason = "shiftPay" | "admin" | "other"`
  - `export type Amounts = { [CurrencyType]: number }`
  - `export type CurrencyChange = { userId: number, currency: EconomyCurrency, flow: "source" | "sink", amount: number, balance: number, reason: ChangeReason }`
- Produces (in `CurrencyServiceServer`):
  - `changed: SignalTyped.Signal<CurrencyConstants.CurrencyChange>` — fired after the `mutate` returns changed, once per currency whose balance moved; `amount` = |new − old|, `flow` = "source" when it rose, `balance` = new.
  - `grant: (self, userId: number, amounts: CurrencyConstants.Amounts, reason: CurrencyConstants.ChangeReason) -> boolean` — `Guard.userId`; asserts every key is a valid currency and `Guard.nonNegativeAmount` on every value; adds all non-zero amounts in ONE `currencySlice.mutate`, each capped at `MAX_CURRENCY`; returns false (no write, no event) when nothing changes.
  - `addCurrency / removeCurrency / setCurrency` take a trailing `reason: CurrencyConstants.ChangeReason?` (default `"other"`). `currencyOp` stays event-free (documented: raw transaction ops do not report; use `grant`).
- Produces (in `MarketplaceServiceServer`): `premiumChanged: SignalTyped.Signal<CurrencyConstants.CurrencyChange>` with `currency = "gleam"`, fired from `addPremium` / `spendPremium` on success; both take a trailing `reason: CurrencyConstants.ChangeReason?` (default `"other"`). Product grants through `premiumOp` arrive with the week 2 shop and must fire it then.

- [ ] **Step 1: Write the failing tests** (`CurrencyServiceServer.spec`, using its fake-profile harness; collect events with `CurrencyService.changed:Connect` and disconnect in `afterEach`)

```lua
it("reports a source with the amount, ending balance and reason", function()
	_profiles[1] = makeProfile(100) -- credits = 100
	expect(CurrencyService:addCurrency(1, "credits", 40, "admin")).to.equal(true)
	expect(#events).to.equal(1)
	local e = events[1]
	expect(e.userId).to.equal(1); expect(e.currency).to.equal("credits"); expect(e.flow).to.equal("source")
	expect(e.amount).to.equal(40); expect(e.balance).to.equal(140); expect(e.reason).to.equal("admin")
end)
it("reports a sink on remove and defaults the reason to other", function()
	_profiles[1] = makeProfile(100)
	CurrencyService:removeCurrency(1, "credits", 30)
	expect(events[1].flow).to.equal("sink"); expect(events[1].amount).to.equal(30)
	expect(events[1].balance).to.equal(70); expect(events[1].reason).to.equal("other")
end)
it("reports nothing for a refused or no-change write", function()
	_profiles[1] = makeProfile(100)
	CurrencyService:removeCurrency(1, "credits", 500)
	CurrencyService:setCurrency(1, "credits", 100)
	expect(#events).to.equal(0)
end)
it("grants Credits and Gloom in one write, one event each", function()
	_profiles[1] = makeProfile(0)
	expect(CurrencyService:grant(1, { credits = 760, gloom = 340 }, "shiftPay")).to.equal(true)
	expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(760)
	expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(340)
	expect(#events).to.equal(2)
	expect(writes).to.equal(1) -- the harness counts mutate calls on the currency path
end)
it("reports the clamped delta at the cap, and nothing once fully absorbed", function()
	_profiles[1] = makeProfile(CurrencyConstants.MAX_CURRENCY - 10)
	CurrencyService:grant(1, { credits = 50 }, "shiftPay")
	expect(events[1].amount).to.equal(10); expect(events[1].balance).to.equal(CurrencyConstants.MAX_CURRENCY)
	expect(CurrencyService:grant(1, { credits = 50 }, "shiftPay")).to.equal(false)
	expect(#events).to.equal(1)
end)
it("grants nothing for all-zero amounts and refuses bad input", function()
	_profiles[1] = makeProfile(0)
	expect(CurrencyService:grant(1, { credits = 0, gloom = 0 }, "shiftPay")).to.equal(false)
	expect(function() CurrencyService:grant(1, { credits = -1 }, "shiftPay") end).to.throw()
	expect(function() CurrencyService:grant(1, { coins = 1 }, "shiftPay") end).to.throw()
	expect(#events).to.equal(0)
end)
```

If the spec's harness has no mutate counter, add one where it already stubs the data layer; if it runs the real data layer, replace `writes` with asserting both balances changed in the same event burst (both events fired before `grant` returned).

`MarketplaceServiceServer.spec`: `addPremium(id, 25, "admin")` fires one `premiumChanged` `{ currency = "gleam", flow = "source", amount = 25, balance = 25, reason = "admin" }`; a short `spendPremium` fires nothing; a successful spend fires a `"sink"`.
Command specs: the mocked method records the reason; assert it is `"admin"`.

- [ ] **Step 2: Run tests to verify they fail** — Studio run. Expected: `changed` / `grant` / `premiumChanged` are nil.
- [ ] **Step 3: Implement** per the Interfaces block. Capture old/new balances inside the mutator, fire after `mutate` returns (never inside the no-yield region).
- [ ] **Step 4: Run tests to verify they pass** — Studio run. Expected: 0 failures.
- [ ] **Step 5: Lint/format** changed `.luau` files.
- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Features/Currency src/ServerScriptService/Features/Currency src/ServerScriptService/Features/Marketplace src/ServerScriptService/Commands
git commit -m "Currency: grant and change events for Gloom, Credits and Gleam"
```

---

### Task 5: Pay the crew at the end of the shift (`ShiftPaySystem`)

**Files:**
- Create: `src/ServerScriptService/Features/Shift/Systems/ShiftPaySystem.luau`
- Test: `src/ServerScriptService/Features/Shift/Systems/ShiftPaySystem.spec.luau`
- Modify: `src/ServerScriptService/Features/Shift/ShiftServiceServer.luau` (start it in `start` beside the other `stoppers`; add `"CurrencyServiceServer"` to `dependencies`)
- Modify: `docs/project-structure.md` (module map, via the script)

**Interfaces:**
- Consumes: `CurrencyServiceServer:grant(userId, amounts, "shiftPay")` (Task 4); `ShiftQuotaFormulas.breakdown(gloom, dust, valuables)` (field names as of this task: `.gleam` is the total pay, `.gloom` the Gloom removed; Task 6 renames `.gleam` to `.credits` and updates this caller).
- Produces:
  - `export type Source = { changed: SignalTyped.Signal<ShiftTypes.ShiftState>, results: () -> ShiftTypes.ShiftResults?, present: () -> { number } }`
  - `export type Pay = (userId: number, amounts: CurrencyConstants.Amounts) -> boolean`
  - `ShiftPaySystem.start(source: Source, pay: Pay): () -> ()` — on the first `changed` state with `phase == "results"` for a given `state.shift` (any `outcome`), reads `source.results()`; if non-nil, computes `split = breakdown(results.cleared, results.dust or 0, results.bonus)`, `credits = split.gleam`, `gloom = split.gloom` (decision: saved Gloom = all Gloom the crew removed, the number on the contract gauge — see Open questions); skips when both are 0; else calls `pay(userId, { credits = credits, gloom = gloom })` once for every id in `source.present()` (deduplicated), each in its own `xpcall` that logs and continues. Returns the disconnect.
  - Wiring in `ShiftServiceServer.start`: `table.insert(stoppers, ShiftPaySystem.start({ changed = changed, results = function() return results end, present = function() return trip:crewIds() end }, function(userId, amounts) return CurrencyServiceServer:grant(userId, amounts, "shiftPay") end))`. `results` is assigned before `setState` in both endings (clock-out in `step`, timeout in `onRoundPhase`), so it is set when "results" is published; a reset never reaches "results" and pays nothing.

- [ ] **Step 1: Write the failing spec** (copy `fakeSignal` and `state(...)` helpers from `RankShiftSystem.spec.luau`)

```lua
-- review(cleared, dust, bonus): a ShiftResults with those counters and crew lines for 1, 2, 3.
-- Expected pay for review(340, 260, 420): credits = 340 * ShiftConstants.GLEAM_PER_GLOOM + 420 (= 760), gloom = 340.
it("pays every present crew member the full Credits and Gloom when the review opens", function()
	present = { 1, 2 } -- 3 left mid-shift
	reviewNow = review(340, 260, 420)
	changed:Fire(state("results", 1, true, "clockout"))
	expect(#calls).to.equal(2)
	for _, call in calls do
		expect(call.amounts.credits).to.equal(760)
		expect(call.amounts.gloom).to.equal(340)
		expect(call.userId).never.to.equal(3)
	end
end)
it("pays a knocked-out member in full", function()
	present = { 1, 2 }
	reviewNow = review(100, 100, 0, { [2] = { caught = 1 } })
	changed:Fire(state("results", 1, false, "clockout"))
	expect(#calls).to.equal(2)
end)
it("pays on a timeout too", function()
	present = { 1 }; reviewNow = review(50, 50, 0)
	changed:Fire(state("results", 1, false, "timeout"))
	expect(#calls).to.equal(1)
end)
it("pays each shift once, and the next shift again", function()
	present = { 1 }; reviewNow = review(50, 50, 0)
	changed:Fire(state("results", 1, false, "clockout"))
	changed:Fire(state("results", 1, false, "clockout"))
	expect(#calls).to.equal(1)
	changed:Fire(state("results", 2, false, "clockout"))
	expect(#calls).to.equal(2)
end)
it("pays nothing outside the review, without a review, or for an empty shift", function()
	present = { 1 }; reviewNow = review(50, 50, 0)
	changed:Fire(state("running", 1, false))
	reviewNow = nil
	changed:Fire(state("results", 2, false, "clockout"))
	reviewNow = review(0, 0, 0)
	changed:Fire(state("results", 3, false, "clockout"))
	expect(#calls).to.equal(0)
end)
it("keeps paying the rest when one payment throws", function()
	present = { 1, 2 }; reviewNow = review(50, 50, 0)
	failFor = 1
	changed:Fire(state("results", 1, false, "clockout"))
	expect(calls[#calls].userId).to.equal(2)
end)
it("stops paying once stopped", function()
	stop()
	present = { 1 }; reviewNow = review(50, 50, 0)
	changed:Fire(state("results", 9, false, "clockout"))
	expect(#calls).to.equal(0)
end)
```

- [ ] **Step 2: Run tests to verify it fails** — Studio run. Expected: the spec errors requiring `ShiftPaySystem`.
- [ ] **Step 3: Implement** `ShiftPaySystem` per Interfaces; wire it into `ShiftServiceServer`; run `python3 scripts/python/module_map.py --write`.
- [ ] **Step 4: Run tests to verify they pass** — Studio run. Expected: 0 failures. Then a normal solo Play: finish a shift by clock-out; Debugger (F4) State tab `currency.credits` equals the review's Gleam/Credits total and `currency.gloom` equals the Gloom removed; Output shows no "pay ... failed" error. Repeat ending by timeout (Cmdr or let the clock run out): paid again.
- [ ] **Step 5: Lint/format** changed `.luau` files.
- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Features/Shift docs/project-structure.md
git commit -m "Shift: pay Credits and Gloom to the crew still present at the review"
```

---

### Task 6: Pay reads "Credits" everywhere it read Gleam

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Data/ShiftConstants.luau:84-92` (`CURRENCY_NAME = "Credits"`; `GLEAM_PER_GLOOM` → `CREDITS_PER_GLOOM = 1`; comment: Credits are saved at shift end, Gleam is the premium balance)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftQuotaFormulas.luau` (Breakdown fields `dustGleam` → `dustCredits`, `grimeGleam` → `grimeCredits`, `gleam` → `credits`; doc comments)
- Modify: `src/ReplicatedStorage/Shared/Features/Shift/Utils/ShiftCurrencyUtils.luau` (doc: no longer "display only")
- Modify callers: `DepotBoardViewModel.luau:115`, `ShiftHudViewModel.luau:240`, `ShiftReviewViewModel.luau:289,317-318` (label `"Credits earned"`; detail uses the renamed fields), `DepotWorldViewModel.luau:236`, `ShiftPaySystem.luau` (`split.credits`)
- Modify copy: `src/ReplicatedStorage/Shared/Features/Depot/Data/DepotConstants.luau:31` → `"1 Credit per Gloom, plus valuables"`; `DepotHubViewModel.luau:143` ends `"... for Credits."`; `DepotHubViewModel.luau:151` says `"Every Gloom removed pays 1 Credit at clock-out."`; `ShiftServiceServer.luau:231` toast ends `"then bank them for Credits."`
- Modify: `DepotHub.luau` / `DepotHubPanel.luau` / `DepotHubPanel.story.luau` — prop `gleam` → `credits` (still the `"gleam"` coin art icon); header comments say the counter is the Credits balance
- Tests: `ShiftQuotaFormulas.spec`, `ShiftCurrencyUtils.spec`, `ShiftHudViewModel.spec`, `ShiftReviewViewModel.spec`, `ShiftHotbarViewModel.spec`, `DepotBoardViewModel.spec`, `DepotWorldViewModel.spec`, `CargoWorldViewModel.spec`, `CargoFeedbackUtils.spec`, `PaperToastViewModel.spec`, `ShiftPaySystem.spec` (`GLEAM_PER_GLOOM` → `CREDITS_PER_GLOOM`) — every expected `"N Gleam"` / `"??? Gleam"` / `"+N Gleam"` string becomes `"N Credits"` / `"??? Credits"` / `"+N Credits"`

**Interfaces:**
- Consumes: Task 5's `ShiftPaySystem` (caller of `breakdown`).
- Produces: `ShiftQuotaFormulas.Breakdown = { dust, grime, gloom, dustCredits, grimeCredits, valuables, credits }`; `ShiftConstants.CREDITS_PER_GLOOM`; `ShiftCurrencyUtils.amount(45) == "45 Credits"`.

- [ ] **Step 1: Write the failing tests** — in `ShiftCurrencyUtils.spec`: `amount(45) == "45 Credits"`, `unknown() == "??? Credits"`, `gain(40) == "+40 Credits"`. In `ShiftQuotaFormulas.spec`: the existing `breakdown(340, 260, 420)` case asserts `split.dustCredits == 260 * ShiftConstants.CREDITS_PER_GLOOM`, `split.grimeCredits == 80 * ShiftConstants.CREDITS_PER_GLOOM`, `split.credits == 340 * ShiftConstants.CREDITS_PER_GLOOM + 420`. In `ShiftReviewViewModel.spec`: the gold row's label is `"Credits earned"` and `rows[2].value == "577 Credits"`. In `DepotBoardViewModel.spec:57`: `"1 Credit per Gloom, plus valuables"`. Update every other listed spec's Gleam pay strings.
- [ ] **Step 2: Run tests to verify they fail** — Studio run. Expected: the edited cases fail on "Gleam".
- [ ] **Step 3: Implement** the renames and copy above. Then `grep -rn "Gleam" src --include=*.luau` and confirm every remaining hit is art (palette `P.gleam*`, icon keys `gleam`/`gleamPile`, button variant `gleam`, kit name "Gloom & Gleam") or a comment about the premium balance, not pay text.
- [ ] **Step 4: Run tests to verify they pass** — Studio run. Expected: 0 failures. In UI Labs (EDIT mode) `DepotHubPanel.story` renders the counter. Normal Play: price tags, the fee plate, load floaters and the review read "Credits"; the hub counter shows the saved Credits balance.
- [ ] **Step 5: Lint/format** changed `.luau` files.
- [ ] **Step 6: Commit**

```bash
git add -A src
git commit -m "Shift: pay text reads Credits; hub shows the Credits balance"
```

---

### Task 7: Whole-plan verification

**Files:** none new.

- [ ] **Step 1: Full suite** — Studio run. Expected: 0 failures; total = 3828 + the cases added by Tasks 1-6; no `SpecRoots` error.
- [ ] **Step 2: Solo Play** (RunTests off): clock out a shift → Credits and Gloom in the Debugger State tab match the review; run a second shift and let it time out → both grow again; Cmdr `currencyadd me gloom 5` works, `currencyadd me coins 5` is refused by the arg type.
- [ ] **Step 3: 2-player Local Server**: player 2 leaves mid-shift; player 1 clocks out → only player 1 is paid. Repeat with player 2 knocked out (or caught, before the coat plan lands) at the end → both paid in full. The rank card shows no "Whole crew out" line on a timeout.
- [ ] **Step 4: Persistence** — Studio Play uses ProfileStore's mock store, so "visible after rejoin" is checked on the published place (owner action): play one shift, leave, rejoin → the hub counter shows the same Credits. Record the result on the board item.
- [ ] **Step 5: Module map is current** — `python3 scripts/python/module_map.py --write` leaves no diff.
- [ ] **Step 6: Move the board item to "review".**

---

## Open questions

1. **Saved Gloom amount.** This plan saves all Gloom the crew removed (`results.cleared`: piles + grime, the contract gauge's number, ~1000 per shift). The board says "a little per pile cleared"; the alternative is piles only (`results.dust`) or a divisor. Owner to confirm before Locker key prices (week 2).
2. **Hub counters.** The hub pill shows Credits only. Should Gloom (and Gleam) get hub counters this week, or with the shop/Lockers in week 2?
3. **Who counts as "still in the shift".** Payees are the crew present when the review opens (`trip:crewIds()`). A player who leaves in the seconds between clock-out and the review gets nothing.
4. **File overlap.** Task 2 edits `AnalyticsServiceServer.luau` (analytics plan); Task 5/6 edit `ShiftServiceServer.luau` and Task 6 edits `ShiftReviewViewModel.luau` (coat-catch and polish plans also edit them). Schedule accordingly.
