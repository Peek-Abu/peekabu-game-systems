# SlotService — Character Slot Switching (Phase 1b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A server-authoritative `SlotService` that switches a player's active character slot, with the guards that make it safe — proving the slot foundation end-to-end. Driven by a Cmdr admin command; **no UI, no network packet** (both land with the slot-select screen, once there is character data worth previewing).

**Architecture:** A switch is not a persistence event — every slot already lives in one ProfileStore key. It is: validate → `mutate("slotState")` → re-mirror every slice → `LoadCharacter()`. No DataStore call, no lock, no crash window.

Two structural problems surfaced while planning, and this phase fixes both:
- **The active slot is currently impossible to change.** `mutate` hands a mutator the *value* at a path and expects in-place mutation, so a scalar (`activeSlot: number`) is **read-only through the data layer**. It becomes `slotState: { active: number }` — a table, which is mutable in place — leaving the atomicity core's contract untouched (Task 4).
- **`unlockedSlots` is seeded in the profile skeleton but owned by nobody** — no service registers it, so nothing can read or validate it. `SlotService` takes ownership via `registerAccount` (Task 3).

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, Cmdr, TestEZ, Rojo, selene + StyLua.

Design: `docs/superpowers/specs/2026-07-12-player-data-slots-design.md`
Builds on: `docs/superpowers/plans/2026-07-12-player-data-slots-foundation.md` (Phase 1a — merged into this branch)

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification, a comment at the site, and sign-off. If you think one is forced, STOP and escalate.
- **Spec-first TDD.** Write `<Name>.spec.luau` BEFORE the implementation. `SpecRoots.assertAllModulesSpecced` fails the build if a first-party module has no `.spec` sibling.
- **Server-authoritative always.** The client may only *request* a switch; it never writes state.
- **Service shape: lean annotated literal** — `export type X = {...}` + `local X: X = {...}`, methods as fields, `dependencies = {...}`. No `function X:method()` statements, no `self` casts. Auto-discovered by the `*ServiceServer` filename suffix.
- **Commits: plain messages only.** No `Co-Authored-By:` / `Claude-Session:` trailers.
- **No headless test runner.** Local gate = `bash scripts/check.sh` (run the FULL command WITH its wally install step — `wally-package-types` is NOT idempotent, and `--skip-install` on stale link files produces spurious `'REQUIRED_MODULE' is not a function call` errors that are not real). TestEZ runs on Open Cloud in CI, and **only on a PR into main or a push to main** — a feature-branch push SKIPS it.
- **No migrations.** Data is wiped pre-launch; change the shape and wipe.
- `MAX_SLOTS = 3`. Slot 1 is unlocked by default.

## Decisions already made (do not relitigate)

- **Switching happens only at a safe hub / character-select screen.** There is no hub yet, so this plan does not implement a location check — but the switch API must be written so one can be added as a guard without reshaping it.
- **Slot deletion is deferred entirely.** Do NOT build it. (This is also why `resolvePath`'s leaf-key limitation stays deferred — only deletion needed it.)
- **Slots 2-3 are unlocked by a dev product today, possibly earnable later.** This plan does NOT build the purchase flow. It builds the *slice* (`unlockedSlots`) and the *check*; granting is a separate concern that can write the slice later.
- **No UI and no ByteNet packet in this phase.** The Cmdr command is the test surface. (`RequestHandler` explicitly forbids request/response, so a switch RPC needs a new `wrapQuery` variant — that design belongs with the UI that consumes it.)

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ReplicatedStorage/Shared/Modules/Guard.luau` | Add `Guard.slotIndex` — integer, in `1..MAX_SLOTS`. The runtime boundary validator. |
| `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` | Add public `isInTransaction(userId)`. Today the only way to observe it is a debug blob. |
| `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` | Remove the hardcoded `account.unlockedSlots` from the skeleton (`SlotService` owns it now); template gains `slotState`. |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | `activeSlot: number` → `slotState: { active: number }`, so the active slot is writable at all. |
| `src/ReplicatedStorage/Shared/State/SliceManifest.luau` | Both readers follow the moved active slot (`profile.slots[profile.slotState.active]`). |
| `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau` | **New.** Owns the `unlockedSlots` account slice; `switchSlot`, `getActiveSlot`, `getUnlockedSlots`, `isSlotUnlocked`, `unlockSlot`. |
| `src/ServerScriptService/Commands/SwitchSlot.luau` + `SwitchSlotServer.luau` | **New.** Cmdr admin command — the test surface. |
| `src/ServerScriptService/Commands/UnlockSlot.luau` + `UnlockSlotServer.luau` | **New.** Cmdr admin command to grant a slot (stands in for the dev-product grant). |
| `docs/limitations.md` | Cleanup: still documents the removed `registerProfilePath` API. |

Each new module needs a `.spec.luau` sibling (Cmdr command files are exempt — check `SpecRoots.EXEMPT_MODULES` for how the existing `Commands/` files are handled and follow that precedent).

---

### Task 1: `Guard.slotIndex`

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/Guard.luau`
- Test: `src/ReplicatedStorage/Shared/Modules/Guard.spec.luau`

**Interfaces:**
- Produces: `Guard.slotIndex(value: unknown, maxSlots: number): number` — asserts a number, an integer, and `1 <= value <= maxSlots`; returns the narrowed number.

`maxSlots` is a parameter rather than a `PlayerDataConstants` import: `Guard` lives in `ReplicatedStorage/Shared` and must not depend on a server-only module. The caller passes `PlayerDataConstants.MAX_SLOTS`.

- [ ] **Step 1: Write the failing spec**

Add to `src/ReplicatedStorage/Shared/Modules/Guard.spec.luau`, following the file's existing test style:

```lua
describe("slotIndex", function()
	it("returns the value for a valid slot", function()
		expect(Guard.slotIndex(1, 3)).to.equal(1)
		expect(Guard.slotIndex(3, 3)).to.equal(3)
	end)

	it("rejects a non-number", function()
		expect(function()
			Guard.slotIndex("2", 3)
		end).to.throw()
	end)

	it("rejects a non-integer", function()
		expect(function()
			Guard.slotIndex(2.5, 3)
		end).to.throw()
	end)

	it("rejects a slot below 1", function()
		expect(function()
			Guard.slotIndex(0, 3)
		end).to.throw()
	end)

	it("rejects a slot above maxSlots", function()
		expect(function()
			Guard.slotIndex(4, 3)
		end).to.throw()
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh`
Expected: FAIL — typecheck: `slotIndex` is not a field of `Guard`.

- [ ] **Step 3: Write the implementation**

Add to `src/ReplicatedStorage/Shared/Modules/Guard.luau`, matching the existing validators' shape exactly (each takes `unknown`, asserts, returns the narrowed value):

```lua
--[=[
	Validates a character slot index at the runtime boundary (a networked payload, a Cmdr arg).
	A slot index addresses a table in the profile's `slots` array, so a non-integer or out-of-range
	value must be rejected HERE — `ProfilePath.forSlot` would otherwise build a path
	(`slots.2.5.currency`) that silently resolves to nothing.

	`maxSlots` is passed in rather than imported: Guard is shared-realm and must not depend on the
	server-only PlayerDataConstants. Callers pass `PlayerDataConstants.MAX_SLOTS`.

	@param value unknown -- The untrusted value
	@param maxSlots number -- The number of slots a profile carries
	@return number -- The validated slot index
]=]
function Guard.slotIndex(value: unknown, maxSlots: number): number
	assert(type(value) == "number", `slotIndex must be a number, got {type(value)}`)
	assert(value == math.floor(value), `slotIndex must be an integer, got {value}`)
	assert(value >= 1 and value <= maxSlots, `slotIndex must be between 1 and {maxSlots}, got {value}`)
	return value
end
```

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh`
Expected: PASS (lint, format, typecheck all clean).

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/Guard.luau src/ReplicatedStorage/Shared/Modules/Guard.spec.luau
git commit -m "feat(guard): add slotIndex validator"
```

---

### Task 2: `PlayerDataService:isInTransaction`

**Files:**
- Modify: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` (the `export type` interface + the table literal)
- Test: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau`

**Interfaces:**
- Produces: `PlayerDataService:isInTransaction(userId: number) -> boolean`

**Why this exists.** A slot switch is multi-step (validate → mutate → re-mirror → respawn). `mutate` already refuses while a profile is locked by a transaction, but discovering that *at the mutate* means we would already have despawned the character. The switch must refuse **before** it touches anything. Today the only way to observe the flag is `getState()`, a stringly-keyed debug blob — not an API.

`profilesInTransaction` is a module-local upvalue (`PlayerDataServiceServer.luau:101`). This adds a read-only accessor over it; do NOT expose the table itself.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau`. Follow the file's existing fixture pattern (`makeSlotData`, `seed`, `CURRENCY_PATH`):

```lua
describe("isInTransaction", function()
	it("is false for a loaded profile with no transaction running", function()
		expect(PlayerDataService:isInTransaction(USER_ID)).to.equal(false)
	end)

	it("is false for a userId with no profile", function()
		expect(PlayerDataService:isInTransaction(999)).to.equal(false)
	end)

	it("is true while a transaction is mid-flight for that user", function()
		local observed = nil
		PlayerDataService:transaction({
			{
				userId = USER_ID,
				path = CURRENCY_PATH,
				mutator = function(currency)
					-- Observed from INSIDE the locked region: this is exactly the state a slot
					-- switch must refuse on.
					observed = PlayerDataService:isInTransaction(USER_ID)
					currency.gold += 1
					return true
				end,
			},
		})
		expect(observed).to.equal(true)
	end)

	it("is false again after the transaction commits", function()
		PlayerDataService:transaction({
			{
				userId = USER_ID,
				path = CURRENCY_PATH,
				mutator = function(currency)
					currency.gold += 1
					return true
				end,
			},
		})
		expect(PlayerDataService:isInTransaction(USER_ID)).to.equal(false)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh`
Expected: FAIL — typecheck: `isInTransaction` is not a field of `PlayerDataServiceServer`.

- [ ] **Step 3: Write the implementation**

Add to the `export type PlayerDataServiceServer = { ... }` interface:

```lua
	isInTransaction: (self: PlayerDataServiceServer, userId: number) -> boolean,
```

And to the table literal, next to `getActiveSlot`:

```lua
	--[=[
		True while a transaction holds this profile's lock.

		Exists for callers whose operation is MULTI-STEP and must refuse BEFORE taking a visible
		side effect — a slot switch despawns the character before it mutates `activeSlot`, so
		discovering the lock at the mutate would leave the player characterless. `mutate()` already
		refuses a locked profile on its own; this is the pre-flight check, not a substitute for it.

		Read-only: the underlying `profilesInTransaction` table stays private.

		@param userId number -- The user to check
		@return boolean -- True if a transaction is in flight for this profile
	]=]
	isInTransaction = function(_self, userId)
		Guard.userId(userId)
		return profilesInTransaction[userId] ~= nil
	end,
```

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau
git commit -m "feat(data): add public isInTransaction accessor"
```

---

### Task 3: `SlotServiceServer` — own `unlockedSlots`, read the active slot

Split from the switch itself (Task 4) so the slice ownership lands and is reviewable on its own.

**Files:**
- Create: `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau`
- Test: `src/ServerScriptService/Services/SlotService/SlotServiceServer.spec.luau`
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` — remove the hardcoded `unlockedSlots` from the template skeleton
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau` — its template test asserts `account.unlockedSlots`; that assertion moves to `SlotServiceServer.spec`

**Interfaces:**
- Consumes: `SliceOwner.registerAccount` (Phase 1a), `PlayerDataService:getActiveSlot`, `PlayerDataConstants.MAX_SLOTS`.
- Produces:
  - `SlotServiceServer.getActiveSlot(self, userId: number) -> number?`
  - `SlotServiceServer.getUnlockedSlots(self, userId: number) -> { number }?`
  - `SlotServiceServer.isSlotUnlocked(self, userId: number, slotIndex: number) -> boolean`
  - `SlotServiceServer.unlockSlot(self, userId: number, slotIndex: number) -> boolean`

**Why the skeleton loses `unlockedSlots`.** `PlayerDataConstants`'s template is meant to be a bare skeleton that domain services hang their slices off. Today `account = { unlockedSlots = { 1 } }` is hardcoded there, so the field exists but **no service owns it** — nothing can read or validate it. `SlotService` registers it properly, which also gives it a data-layer validator.

The validator is the point: `unlockedSlots` must always contain slot 1, hold only integers in `1..MAX_SLOTS`, and never contain duplicates. Registered on the slice, that holds for *any* path into it — including a raw `transaction()` op.

- [ ] **Step 1: Write the failing spec**

Create `src/ServerScriptService/Services/SlotService/SlotServiceServer.spec.luau`. **Read `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.spec.luau` first and follow its mocking pattern exactly** (it fakes `PlayerDataService` with `getActiveSlot` / `_getSlotShell` / `_getAccountShell` / a dotted-path `mutate`) — do not invent a second style.

```lua
describe("SlotServiceServer", function()
	describe("getUnlockedSlots", function()
		it("starts with only slot 1 unlocked", function()
			local unlocked = SlotService:getUnlockedSlots(USER_ID)
			expect(#unlocked).to.equal(1)
			expect(unlocked[1]).to.equal(1)
		end)
	end)

	describe("isSlotUnlocked", function()
		it("is true for slot 1 by default", function()
			expect(SlotService:isSlotUnlocked(USER_ID, 1)).to.equal(true)
		end)

		it("is false for a locked slot", function()
			expect(SlotService:isSlotUnlocked(USER_ID, 2)).to.equal(false)
		end)

		it("is false for a userId with no profile", function()
			expect(SlotService:isSlotUnlocked(999, 1)).to.equal(false)
		end)
	end)

	describe("unlockSlot", function()
		it("unlocks a locked slot", function()
			expect(SlotService:unlockSlot(USER_ID, 2)).to.equal(true)
			expect(SlotService:isSlotUnlocked(USER_ID, 2)).to.equal(true)
		end)

		it("is idempotent — unlocking an already-unlocked slot is a no-op, not a duplicate", function()
			SlotService:unlockSlot(USER_ID, 2)
			SlotService:unlockSlot(USER_ID, 2)
			local unlocked = SlotService:getUnlockedSlots(USER_ID)
			local count = 0
			for _, slot in unlocked do
				if slot == 2 then
					count += 1
				end
			end
			expect(count).to.equal(1)
		end)

		it("rejects an out-of-range slot", function()
			expect(function()
				SlotService:unlockSlot(USER_ID, 4)
			end).to.throw()
		end)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh`
Expected: FAIL — `SlotServiceServer` does not exist.

- [ ] **Step 3: Write the implementation**

Create `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau`. Mirror `CurrencyServiceServer`'s structure: module-scope validator → `SliceOwner.registerAccount` at module load → `local log` → `export type` → annotated table literal with methods as fields.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Guard = require(ReplicatedStorage.Shared.Modules.Guard)
local SliceOwner = require(ServerScriptService.Modules.SliceOwner)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)

local MAX_SLOTS = PlayerDataConstants.MAX_SLOTS

-- The unlockedSlots invariant, enforced by the DATA LAYER on every write (see SliceOwner's
-- `validate`). Registering it here makes it hold for ANY path into the slice — including a raw
-- transaction() op (e.g. a future dev-product grant) that never goes through unlockSlot().
-- Slot 1 is always unlocked: a profile that lost it would have no playable character.
local function validateUnlockedSlots(unlocked: { number }): (boolean, string?)
	local seen: { [number]: boolean } = {}
	local hasSlotOne = false
	for _, slot in unlocked do
		if type(slot) ~= "number" or slot ~= math.floor(slot) then
			return false, `unlockedSlots must contain integers, got {slot}`
		end
		if slot < 1 or slot > MAX_SLOTS then
			return false, `unlockedSlots entry {slot} is out of range (1..{MAX_SLOTS})`
		end
		if seen[slot] then
			return false, `unlockedSlots contains duplicate slot {slot}`
		end
		seen[slot] = true
		if slot == 1 then
			hasSlotOne = true
		end
	end
	if not hasSlotOne then
		return false, "unlockedSlots must always contain slot 1"
	end
	return true
end

-- Registers the "unlockedSlots" ACCOUNT slice: which character slots this player owns is an
-- entitlement — it belongs to the account, not to any one character (see the character-slots design).
local unlockedSlotsSlice = SliceOwner.registerAccount("unlockedSlots", { 1 }, function(account)
	return account.unlockedSlots
end, validateUnlockedSlots)

local log = Logger.new("SlotServiceServer")

export type SlotServiceServer = {
	dependencies: { string },

	init: (self: SlotServiceServer) -> (),
	getActiveSlot: (self: SlotServiceServer, userId: number) -> number?,
	getUnlockedSlots: (self: SlotServiceServer, userId: number) -> { number }?,
	isSlotUnlocked: (self: SlotServiceServer, userId: number, slotIndex: number) -> boolean,
	unlockSlot: (self: SlotServiceServer, userId: number, slotIndex: number) -> boolean,
}

local SlotServiceServer: SlotServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	init = function(_self)
		log:info("SlotServiceServer initialized")
	end,

	--[=[
		The slot the player is currently playing, or nil if their profile isn't loaded.
		@param userId number
		@return number?
	]=]
	getActiveSlot = function(_self, userId)
		Guard.userId(userId)
		return PlayerDataService:getActiveSlot(userId)
	end,

	--[=[
		The slots this account owns. Account-wide: an entitlement, not a per-character fact.
		@param userId number
		@return { number }? -- The unlocked slot indices, or nil if the profile isn't loaded
	]=]
	getUnlockedSlots = function(_self, userId)
		Guard.userId(userId)
		return unlockedSlotsSlice.get(userId)
	end,

	--[=[
		True if the player owns this slot. False (not an error) when the profile isn't loaded, so a
		caller gating on this fails CLOSED.
		@param userId number
		@param slotIndex number -- 1..MAX_SLOTS
		@return boolean
	]=]
	isSlotUnlocked = function(_self, userId, slotIndex)
		Guard.userId(userId)
		Guard.slotIndex(slotIndex, MAX_SLOTS)

		local unlocked = unlockedSlotsSlice.get(userId)
		if not unlocked then
			return false
		end
		return table.find(unlocked, slotIndex) ~= nil
	end,

	--[=[
		Grants a slot to this account. IDEMPOTENT — granting an already-owned slot is a no-op that
		returns false ("no change"), never a duplicate entry. That matters because the eventual caller
		is a Robux receipt, and receipt processing is at-least-once: a double-delivered grant must not
		corrupt the slice.

		This is the GRANT primitive only. What causes a grant (a dev product today, possibly a
		progression unlock later) is deliberately not this service's concern.

		@param userId number
		@param slotIndex number -- 1..MAX_SLOTS
		@return boolean -- True if the slot was newly unlocked
	]=]
	unlockSlot = function(_self, userId, slotIndex)
		Guard.userId(userId)
		Guard.slotIndex(slotIndex, MAX_SLOTS)

		local changed = unlockedSlotsSlice.mutate(userId, function(unlocked)
			if table.find(unlocked, slotIndex) then
				return false -- already owned: no change, and NOT a duplicate insert
			end
			table.insert(unlocked, slotIndex)
			return true
		end)

		if changed then
			log:audit(`userId={userId}`, "SLOT_UNLOCKED", `slot={slotIndex}`)
		end
		return changed
	end,
}

return SlotServiceServer
```

Then remove `unlockedSlots` from the skeleton in `PlayerDataConstants.luau` — `account` becomes an empty table that registration fills:

```lua
		account = {},
```

(Follow whatever typing approach the existing `emptySlots()` helper used to keep this a valid `PlayerAccount` without a cast; if `PlayerAccount`'s `unlockedSlots` field being required makes `{}` fail to typecheck, that is the same tension `PlayerSlot` had — solve it the same way the slots skeleton did, and do NOT add a cast.)

Move the template's `unlockedSlots` assertion out of `PlayerDataConstants.spec.luau` (it no longer owns that field) and into `SlotServiceServer.spec.luau`, where the slice's default is now asserted.

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/SlotService/ src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau
git commit -m "feat(slots): add SlotService owning the unlockedSlots account slice"
```

---

### Task 4: Make the active slot WRITABLE (`activeSlot` → `slotState.active`)

**This task exists because the active slot is currently impossible to change.** Verify the problem yourself first (5 minutes, and do not skip it — the rest of the task only makes sense once you have seen it):

`PlayerDataServiceServer.luau:683` runs the mutator as `coroutine.resume(co, data)`, where `data` is the **value** at the path. A mutator mutates that value **in place**; its return value is only a boolean "did this change anything" flag. `activeSlot` is a **number**, and a number cannot be mutated by reference — so there is **no way to write a scalar path through `mutate`**. `activeSlot` is read-only. The switch cannot work until this is fixed.

Two ways out, and we are taking the second:

  **(a) Teach `mutate` to set a scalar** (e.g. a mutator's returned value replaces a scalar slice). **Rejected** — it changes the contract of the atomicity core, which every domain write funnels through, to serve one field. Not worth it.

  **(b) Make the active slot a TABLE — CHOSEN.** `activeSlot: number` becomes `slotState: { active: number }`, which a mutator can mutate in place. The `mutate` contract is untouched.

It must live in the **core profile skeleton**, NOT in a domain slice: `PlayerDataService:getActiveSlot`, `SliceManifest`'s readers, and `mutate`/`transaction`'s mirror gates all read it, and none of them can depend on `SlotService` (that would invert the dependency — `SlotService` depends on `PlayerDataService`). It is core profile state, like `_schemaVersion`.

This is cheap right now precisely because data is wiped and nothing is published — **no migration**. It gets expensive the moment we ship.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` — `activeSlot: number` → `slotState: { active: number }`
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` — template skeleton
- Modify: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` — `getActiveSlot`, and BOTH mirror gates (`mutate` and `transaction`)
- Modify: `src/ReplicatedStorage/Shared/State/SliceManifest.luau` — both readers
- Test: every spec with a profile fixture

**Interfaces:**
- Produces: `PlayerProfile.slotState = { active: number }`; the mutate path for a switch is the bare root key `"slotState"` (a table, so it is mutable in place).
- `PlayerDataService:getActiveSlot(userId) -> number?` — signature UNCHANGED; only its body changes. This is the point of routing every reader through it.

- [ ] **Step 1: Find every reader**

Run: `grep -rn "activeSlot" src/`
Expected hits (confirm against the real output — do not trust this list): `PlayerDataTypes`, `PlayerDataConstants` (template), `PlayerDataServiceServer` (`getActiveSlot`, `mutate`'s mirror gate, `transaction`'s mirror gate), `SliceManifest` (both readers), `SliceOwner` (via `getActiveSlot` — should need no change), and the spec fixtures.

**Every one must be updated.** A missed mirror gate means a write silently mirrors the wrong slot to the client.

- [ ] **Step 2: Write the failing spec**

Add to `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau` — the test that proves the whole point of this task:

```lua
describe("slotState", function()
	it("the active slot is WRITABLE through mutate (a scalar path is not)", function()
		local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState)
			slotState.active = 2
			return true
		end)
		expect(ok).to.equal(true)
		expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(2)
	end)

	it("changing the active slot changes which slot a slice read resolves to", function()
		PlayerDataService:mutate(USER_ID, "slotState", function(slotState)
			slotState.active = 2
			return true
		end)
		-- SliceOwner resolves the active slot at call time, so currency now reads slot 2's value.
		expect(CurrencyService:getCurrencyAmount(USER_ID, "gold")).to.equal(SLOT_2_GOLD)
	end)
end)
```

- [ ] **Step 3: Run the gate to see it fail**

Run: `bash scripts/check.sh`
Expected: FAIL — `slotState` is not a field of `PlayerProfile`.

- [ ] **Step 4: Implement**

In `PlayerDataTypes.luau`:

```lua
--[=[
	Which character the player is currently playing.

	A TABLE, not a bare `activeSlot: number`, for a load-bearing reason: `mutate` hands a mutator the
	VALUE at a path and expects in-place mutation (its return value is only a "did anything change"
	flag). A number cannot be mutated by reference, so a scalar path is READ-ONLY through the data
	layer — a bare `activeSlot` could never be switched. Wrapping it in a table makes it writable
	without changing the atomicity core's contract.

	Core profile state, not a domain slice: PlayerDataService and SliceManifest both read it, and
	neither can depend on SlotService.
]=]
export type SlotState = {
	active: number,
}
```

and on `PlayerProfile`, replace `activeSlot: number` with `slotState: SlotState`.

Then update, in order: the template (`slotState = { active = 1 }`), `getActiveSlot` (`return if profile then profile.Data.slotState.active else nil`), BOTH mirror gates (`slotIndex == profile.Data.slotState.active`), and both `SliceManifest` readers (`profile.slots[profile.slotState.active].currency`). Then fix every spec fixture — grep for `activeSlot =` across `src/`.

- [ ] **Step 5: Run the gate to verify it passes**

Run: `bash scripts/check.sh`
Expected: PASS. Then confirm `grep -rn "\.activeSlot\b" src/` returns nothing outside comments — no reader may still expect the old scalar.

- [ ] **Step 6: Commit**

```bash
git add src/
git commit -m "feat(data): make the active slot writable (activeSlot -> slotState.active)"
```

---

### Task 5: `switchSlot` — the switch flow

**Files:**
- Modify: `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau`
- Test: `src/ServerScriptService/Services/SlotService/SlotServiceServer.spec.luau`

**Interfaces:**
- Consumes: `PlayerDataService:isInTransaction` (Task 2), `SlotService:isSlotUnlocked` (Task 3), the writable `slotState` (Task 4), `PlayerDataService:mutate`, `ServerStore.syncFromProfile`.
- Produces: `SlotServiceServer.switchSlot(self, player: Player, slotIndex: number) -> (boolean, string?)` — returns success plus a rejection reason.

**THE FLOW** (from the design spec):
1. **Validate** — slot in range; slot unlocked; profile loaded; **no transaction in flight**; not already the active slot.
2. `mutate("activeSlot")`.
3. **Re-mirror every slot-scoped slice** — `ServerStore.syncFromProfile(userId, profileData)`. This is the step that makes the client see the new character.
4. `player:LoadCharacter()` — respawn.

**Order matters, and here is why.** Validate FULLY before any side effect. In particular, refusing on `isInTransaction` must happen *before* the respawn — otherwise we despawn a character and then discover the mutate is refused, leaving the player characterless.

**Why the transaction guard is a correctness requirement, not caution.** `SliceOwner`'s `op` captures the active slot at **MINT** time (see its doc comment). An op minted for slot 1 and held across a yield — a trade that awaits confirmation, say — would, after a switch, commit against the character the player has left. And because `mutate`'s mirror gate skips non-active-slot writes, that write would be **invisible to the client**. Refusing a switch while a transaction is in flight is what closes that window.

**`activeSlot` is a bare root key** — the mutate path is the literal string `"activeSlot"` (not a dotted path). It is not a synced slice, so the mutate does NOT re-mirror anything on its own; step 3 is mandatory and must not be skipped.

**Take `player`, not `userId`.** The switch has to call `LoadCharacter()`, which needs the `Player` instance. Deriving it from a userId inside the service would mean a `Players:GetPlayerByUserId` that can return nil.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Services/SlotService/SlotServiceServer.spec.luau`. You will need a fake `Player` (a table with `UserId` and a `LoadCharacter` function that records that it was called) — the spec is untyped, so this is straightforward:

```lua
describe("switchSlot", function()
	it("switches to an unlocked slot and respawns the character", function()
		SlotService:unlockSlot(USER_ID, 2)
		local player = fakePlayer(USER_ID)

		local ok, reason = SlotService:switchSlot(player, 2)

		expect(ok).to.equal(true)
		expect(reason).to.never.be.ok()
		expect(SlotService:getActiveSlot(USER_ID)).to.equal(2)
		expect(player.loadCharacterCalls).to.equal(1)
	end)

	it("re-mirrors every slice so the client sees the new character's data", function()
		SlotService:unlockSlot(USER_ID, 2)
		-- slot 1 and slot 2 hold different currency; after the switch the atom must show slot 2's.
		SlotService:switchSlot(fakePlayer(USER_ID), 2)
		expect(ServerStore.snapshot("currency")[USER_ID].gold).to.equal(SLOT_2_GOLD)
	end)

	it("REFUSES a locked slot, and changes nothing", function()
		local player = fakePlayer(USER_ID)
		local ok, reason = SlotService:switchSlot(player, 3) -- never unlocked

		expect(ok).to.equal(false)
		expect(reason).to.be.ok()
		expect(SlotService:getActiveSlot(USER_ID)).to.equal(1)
		expect(player.loadCharacterCalls).to.equal(0) -- did NOT despawn
	end)

	it("REFUSES while a transaction is in flight, without respawning", function()
		SlotService:unlockSlot(USER_ID, 2)
		local player = fakePlayer(USER_ID)
		setInTransaction(USER_ID, true) -- test hook on the PlayerDataService fake

		local ok, reason = SlotService:switchSlot(player, 2)

		expect(ok).to.equal(false)
		expect(reason).to.be.ok()
		expect(SlotService:getActiveSlot(USER_ID)).to.equal(1)
		expect(player.loadCharacterCalls).to.equal(0)
	end)

	it("REFUSES a switch to the slot already active (no pointless respawn)", function()
		local player = fakePlayer(USER_ID)
		local ok = SlotService:switchSlot(player, 1)

		expect(ok).to.equal(false)
		expect(player.loadCharacterCalls).to.equal(0)
	end)

	it("REFUSES an out-of-range slot", function()
		expect(function()
			SlotService:switchSlot(fakePlayer(USER_ID), 4)
		end).to.throw()
	end)

	it("REFUSES when the profile is not loaded", function()
		local player = fakePlayer(999)
		local ok = SlotService:switchSlot(player, 1)
		expect(ok).to.equal(false)
		expect(player.loadCharacterCalls).to.equal(0)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh`
Expected: FAIL — `switchSlot` is not a field of `SlotServiceServer`.

- [ ] **Step 3: Write the implementation**

Add `ServerStore` to the requires:

```lua
local ServerStore = require(ServerScriptService.State.ServerStore)
```

Add to the `export type`:

```lua
	switchSlot: (self: SlotServiceServer, player: Player, slotIndex: number) -> (boolean, string?),
```

And to the table literal:

```lua
	--[=[
		Switches the player to another character slot.

		A switch is NOT a persistence event: every slot already lives in the same ProfileStore key, so
		this is zero DataStore calls, no session lock, and no crash window. If the server dies
		mid-switch the player simply wakes up in whichever slot the last save recorded — nothing is
		duplicated or lost.

		EVERY rejection is decided BEFORE the first side effect. The character is despawned only once
		the switch is certain: discovering a refusal after `LoadCharacter()` would leave the player
		standing in the wrong body, or in none.

		The transaction guard is load-bearing, not caution. `SliceOwner`'s `op` captures the active
		slot at MINT time, so an op held across a yield (a trade awaiting confirmation) would, after a
		switch, commit against the character the player just left — and `mutate`'s mirror gate skips
		non-active-slot writes, so that write would be INVISIBLE to the client. Refusing to switch
		while a transaction is in flight is what closes that window.

		@param player Player -- The switching player (needed for LoadCharacter)
		@param slotIndex number -- The slot to switch to, 1..MAX_SLOTS
		@return (boolean, string?) -- Success, plus a reason when refused
	]=]
	switchSlot = function(self, player, slotIndex)
		Guard.slotIndex(slotIndex, MAX_SLOTS)
		local userId = player.UserId

		-- ---- validate: everything that can refuse, refuses HERE, before any side effect ----
		local activeSlot = PlayerDataService:getActiveSlot(userId)
		if not activeSlot then
			return false, "Your data is still loading - try again in a moment"
		end
		if activeSlot == slotIndex then
			return false, "You are already playing that character"
		end
		if not self:isSlotUnlocked(userId, slotIndex) then
			return false, "You do not own that character slot"
		end
		if PlayerDataService:isInTransaction(userId) then
			-- See the header: an in-flight op holds a path minted against the CURRENT slot.
			return false, "Something is still in progress - try again in a moment"
		end

		-- ---- commit ----
		-- `slotState` is a TABLE (Task 4), which is what makes this writable at all: mutate hands the
		-- mutator the value and expects in-place mutation, so a bare `activeSlot` number could never
		-- be set. It is a bare ROOT key (core profile state, not a slice), so this mutate replicates
		-- NOTHING on its own — the re-mirror below is mandatory.
		local switched = PlayerDataService:mutate(userId, "slotState", function(slotState)
			slotState.active = slotIndex
			return true
		end)
		if not switched then
			return false, "Could not switch character - try again"
		end
```

After the mutate succeeds, finish the flow:

```lua
		-- Re-mirror EVERY slice: `activeSlot` is not itself a synced slice, so the mutate above
		-- replicated nothing. This one call is what swaps the client's view to the new character —
		-- every manifest reader projects `slots[activeSlot]`, so re-reading them all is the switch,
		-- as far as the client is concerned.
		local profile = PlayerDataService:getProfile(userId)
		if profile then
			ServerStore.syncFromProfile(userId, profile)
		end

		log:audit(`userId={userId}`, "SLOT_SWITCHED", `from={activeSlot} to={slotIndex}`)

		-- Respawn LAST: the profile and the mirror already describe the new character, so the fresh
		-- character loads into correct state rather than briefly showing the old one's.
		player:LoadCharacter()
		return true
```

Check `getProfile`'s real signature/return before using it (it returns a deep-frozen copy — confirm that is what `syncFromProfile` wants; if it needs the live table, use whatever accessor gives that, and note it).

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/SlotService/
git commit -m "feat(slots): add switchSlot with pre-flight guards and full re-mirror"
```

---

### Task 6: Cmdr commands — the test surface

**Files:**
- Create: `src/ServerScriptService/Commands/SwitchSlot.luau` + `src/ServerScriptService/Commands/SwitchSlotServer.luau`
- Create: `src/ServerScriptService/Commands/UnlockSlot.luau` + `src/ServerScriptService/Commands/UnlockSlotServer.luau`

**Interfaces:**
- Consumes: `SlotServiceServer:switchSlot`, `SlotServiceServer:unlockSlot`.

These are how a human drives the switch until the UI exists. Commands land in `ServerScriptService/Commands/` and are auto-registered by `AdminServiceServer.init()` (`Cmdr:RegisterCommandsIn`). **Any `Group` not in `OPEN_GROUPS` requires admin** via the fail-closed `beforeRunHook` — so `Group = "Admins"` is all the permission wiring needed. Read `Commands/AddCurrency.luau` + `AddCurrencyServer.luau` and copy their shape exactly.

- [ ] **Step 1: Write the command definitions**

`src/ServerScriptService/Commands/SwitchSlot.luau`:

```lua
--!strict
return {
	Name = "switchslot",
	Aliases = { "slot" },
	Description = "Switches a player to another character slot.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to switch" },
		{ Type = "integer", Name = "slot", Description = "The slot to switch to (1-3)" },
	},
}
```

`src/ServerScriptService/Commands/UnlockSlot.luau`:

```lua
--!strict
return {
	Name = "unlockslot",
	Description = "Grants a character slot to a player (stands in for the dev-product grant).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to grant a slot to" },
		{ Type = "integer", Name = "slot", Description = "The slot to unlock (1-3)" },
	},
}
```

- [ ] **Step 2: Write the implementations**

`src/ServerScriptService/Commands/SwitchSlotServer.luau` — note it returns a **string** shown to the invoker, and it must surface `switchSlot`'s rejection reason rather than swallowing it:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local SlotService = require(ServerScriptService.Services.SlotService.SlotServiceServer)

return function(_context, target: Player, slot: number): string
	local ok, reason = SlotService:switchSlot(target, slot)
	if not ok then
		return `Could not switch {target.Name} to slot {slot}: {reason or "unknown reason"}`
	end
	return `Switched {target.Name} to slot {slot}`
end
```

`src/ServerScriptService/Commands/UnlockSlotServer.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local SlotService = require(ServerScriptService.Services.SlotService.SlotServiceServer)

return function(_context, target: Player, slot: number): string
	local unlocked = SlotService:unlockSlot(target, slot)
	if not unlocked then
		return `{target.Name} already owns slot {slot}`
	end
	return `Unlocked slot {slot} for {target.Name}`
end
```

Cmdr passes an untrusted integer, but `switchSlot`/`unlockSlot` both run `Guard.slotIndex`, so an out-of-range slot throws with a clear message rather than corrupting anything. Confirm Cmdr's `integer` type exists in this repo (check `Commands/AddCurrency.luau`'s arg types and `ReplicatedStorage/Shared/CmdrTypes/`); if it does not, use `number` and let `Guard.slotIndex` reject non-integers.

- [ ] **Step 3: Check the spec-sibling rule**

`SpecRoots.assertAllModulesSpecced` fails the build when a first-party module has no `.spec` sibling. Check how the EXISTING `Commands/` files satisfy this (they are almost certainly listed in `SpecRoots.EXEMPT_MODULES` with a reason, since a Cmdr command is a thin adapter). Follow that same precedent for the four new files — **add them to the exempt list with a reason if that is what the existing commands do; do NOT invent tests for a thin adapter just to satisfy the gate.**

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Commands/ src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(slots): add switchslot and unlockslot admin commands"
```

---

### Task 7: Cleanups

**Files:**
- Modify: `docs/limitations.md`
- Modify: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau` (one mangled comment)

- [ ] **Step 1: Fix the stale docs**

`docs/limitations.md` section 3 still documents `PlayerDataConstants.registerProfilePath(path, defaultData)`, which no longer exists — it was replaced by `registerSlotPath` / `registerAccountPath`. Update the section (including its code block) to describe the current API: paths are dotted, registration is per-slot or per-account, and validators are pattern-keyed so one registration covers every slot. Grep the whole file for `registerProfilePath` and fix every hit.

- [ ] **Step 2: Fix the mangled comment**

`src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau:128` reads "the slot-aware spelling of the old flat `activeSlotOf(profile).currency`" — a `sed` pass rewrote the very thing the comment was contrasting against. It should refer to the old flat `profile.Data.currency`.

- [ ] **Step 3: Run the gate and commit**

Run: `bash scripts/check.sh`
Expected: PASS.

```bash
git add docs/limitations.md src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau
git commit -m "docs: update limitations for the slot-aware registration API"
```

---

## Done when

- `bash scripts/check.sh` is clean (lint + format + typecheck + ruff).
- The full TestEZ suite passes **on the PR** (a feature-branch push skips the test job by design — it only runs on a PR into main or a push to main). Baseline before this plan: **459 passing**.
- No `::` casts were added.
- A switch is refused — with the character NOT despawned — when: the slot is locked, the slot is already active, the profile is not loaded, or a transaction is in flight.
- After a switch, `ServerStore`'s atoms show the NEW slot's data, and never the old slot's.
- `grep -rn "registerProfilePath" src/ docs/` returns nothing.

## Deliberately NOT in this phase

- **Slot-select UI** and its **ByteNet packet / RPC**. There is no character data worth previewing until Stats and Customization land, and `RequestHandler` explicitly forbids request/response — so the query pattern should be designed with the UI that needs it, not speculatively. (The old game's start place already has a slot-select UI that Codify can convert to React — pull it in then.)
- **Slot deletion** — and therefore the `resolvePath` leaf-key fix, which only deletion required.
- **The dev-product purchase flow.** `unlockSlot` is the grant primitive; what triggers a grant is a separate concern. Note that Robux receipt processing is at-least-once, which is exactly why `unlockSlot` is idempotent.
- **A hub/location guard.** No hub exists yet. `switchSlot`'s validate block is where it slots in.
