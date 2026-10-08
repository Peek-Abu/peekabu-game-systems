# Character Slots — Data Layer Foundation (Phase 1a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the player-data layer slot-aware — profile shape (`activeSlot` / `account` / `slots`), path resolution, `SliceOwner.registerSlot` / `registerAccount` — and prove it by moving the existing `currency` slice from account-level to slot-scoped.

**Architecture:** One ProfileStore key per player; slots nested inside it (`profile.slots[n].<slice>`), so cross-slot duplication is structurally impossible and a slot switch costs zero DataStore calls. Slice *paths* become dotted (`slots.2.currency`, `account.settings`) while slice *names* (the ServerStore atom keys, e.g. `currency`) stay flat. `SliceOwner`'s accessor shape is unchanged, so **domain services never learn that slots exist** — they read and write a plain `T` for the active character.

**Tech Stack:** Roblox / strict Luau (`--!strict`), ProfileStore, Charm + charm-sync, ByteNet, TestEZ, Rojo, selene + StyLua.

Spec: `docs/superpowers/specs/2026-07-12-player-data-slots-design.md`

## Global Constraints

- **`--!strict` everywhere. No `any`, no casts.** A `::` cast needs genuine justification, a comment at the site, and sign-off. **If nested path resolution appears to force a cast, STOP and escalate — do not sprinkle `:: any`.** Fix the type, not the symptom.
- **Spec-first TDD.** Write `<Name>.spec.luau` *before* the implementation. `SpecRoots.assertAllModulesSpecced` fails the build if a first-party module has no `.spec` sibling. Spec files are intentionally untyped — that is fine and expected.
- **Commits: plain messages only.** No `Co-Authored-By:` / `Claude-Session:` trailers.
- **Service shape:** lean annotated literal (`export type X = {...}` + `local X: X = {...}`, methods as fields). No `function X:method()` statements, no `self` casts.
- **There is no headless test runner.** TestEZ needs a real Roblox runtime. Local gate = `bash scripts/check.sh` (lint + format + typecheck + ruff). Tests run in Studio (`rojo serve` → run `TestRunner.server.luau` → read Output) or on Open Cloud in CI.
- **`wally-package-types` is NOT idempotent** — run `scripts/check.sh` *with* its `wally install` step (not `--skip-install`) if link files look corrupted.
- **No migrations.** Data is wiped and nothing is published; schema changes are free. Do not write a `PlayerDataMigrations` entry for any of this.
- `MAX_SLOTS = 3`.

**Verification command used in every task** (substitute the real spec name where a TestEZ run is called for):

```bash
bash scripts/check.sh --skip-install
```

---

## File Structure

| File | Responsibility |
|---|---|
| `src/ServerScriptService/Modules/ProfilePath.luau` | **New.** Pure path algebra: build / parse / normalise dotted profile paths. No dependencies, trivially testable. |
| `src/ServerScriptService/Modules/ProfilePath.spec.luau` | **New.** Its spec. |
| `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | Profile shape: `PlayerSlot`, `PlayerAccount`, `PlayerProfile` gains `activeSlot` / `account` / `slots`. |
| `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` | `MAX_SLOTS`, base template, `registerSlotPath` / `registerAccountPath`, pattern-keyed validators. |
| `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` | Path resolution in `mutate` / `transaction` / shell reads; mirror normalisation + active-slot guard; `getActiveSlot`. |
| `src/ServerScriptService/Modules/SliceOwner.luau` | `registerSlot` / `registerAccount`; accessor shape unchanged. |
| `src/ReplicatedStorage/Shared/State/SliceManifest.luau` | Slot-scoped readers project the **active slot only**. |
| `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.luau` | The proof: `SliceOwner.register` → `SliceOwner.registerSlot`. |

Each of the above has a `.spec.luau` sibling that must be updated alongside it.

---

### Task 1: `ProfilePath` — the path algebra

Pure, dependency-free, and it pins down the vocabulary every later task uses. Build it first.

**Files:**
- Create: `src/ServerScriptService/Modules/ProfilePath.luau`
- Test: `src/ServerScriptService/Modules/ProfilePath.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ProfilePath.forSlot(slice: string, slotIndex: number) -> string` → `"slots.2.currency"`
  - `ProfilePath.forAccount(slice: string) -> string` → `"account.settings"`
  - `ProfilePath.slotPattern(slice: string) -> string` → `"slots.*.currency"` (the validator/registration key)
  - `ProfilePath.pattern(path: string) -> string` → normalises any numeric segment to `*`
  - `ProfilePath.sliceName(path: string) -> string` → last segment (the ServerStore atom key)
  - `ProfilePath.slotIndex(path: string) -> number?` → `2` for `slots.2.currency`, `nil` otherwise
  - `ProfilePath.segments(path: string) -> { string }`

- [ ] **Step 1: Write the failing spec**

Create `src/ServerScriptService/Modules/ProfilePath.spec.luau`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local ProfilePath = require(ServerScriptService.Modules.ProfilePath)

return function()
	describe("ProfilePath", function()
		describe("forSlot / forAccount", function()
			it("builds a slot path", function()
				expect(ProfilePath.forSlot("currency", 2)).to.equal("slots.2.currency")
			end)

			it("builds an account path", function()
				expect(ProfilePath.forAccount("settings")).to.equal("account.settings")
			end)
		end)

		describe("pattern", function()
			it("normalises the slot index to a wildcard", function()
				expect(ProfilePath.pattern("slots.2.currency")).to.equal("slots.*.currency")
			end)

			it("leaves an account path unchanged", function()
				expect(ProfilePath.pattern("account.settings")).to.equal("account.settings")
			end)

			it("is what slotPattern produces, so registration and lookup agree", function()
				expect(ProfilePath.pattern(ProfilePath.forSlot("currency", 3))).to.equal(
					ProfilePath.slotPattern("currency")
				)
			end)
		end)

		describe("sliceName", function()
			it("returns the last segment for a slot path", function()
				expect(ProfilePath.sliceName("slots.2.currency")).to.equal("currency")
			end)

			it("returns the last segment for an account path", function()
				expect(ProfilePath.sliceName("account.settings")).to.equal("settings")
			end)

			it("returns a bare root key unchanged", function()
				expect(ProfilePath.sliceName("activeSlot")).to.equal("activeSlot")
			end)
		end)

		describe("slotIndex", function()
			it("extracts the slot index", function()
				expect(ProfilePath.slotIndex("slots.2.currency")).to.equal(2)
			end)

			it("is nil for an account path", function()
				expect(ProfilePath.slotIndex("account.settings")).to.never.be.ok()
			end)

			it("is nil for a bare root key", function()
				expect(ProfilePath.slotIndex("activeSlot")).to.never.be.ok()
			end)
		end)
	end)
end
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — typecheck errors, `ProfilePath` does not exist. (The TestEZ assertion failure itself only shows in Studio; the typecheck failure is the fast signal here.)

- [ ] **Step 3: Write the implementation**

Create `src/ServerScriptService/Modules/ProfilePath.luau`:

```lua
--!strict
--[=[
	ProfilePath: the path algebra for the slot-aware profile.

	Profile data is addressed by a DOTTED path (`slots.2.currency`, `account.settings`) rather than a
	bare root key, because slots nest inside the profile (see the character-slots design). Two derived
	forms matter and are easy to conflate, so they get names here rather than being re-derived ad hoc:

	- The PATTERN (`slots.*.currency`) is the REGISTRATION key: a slice is registered once, and its
	  default/validator apply to every slot. Looking a validator up by the concrete path would find
	  nothing for slot 2 and silently enforce the invariant on slot 1 only.
	- The SLICE NAME (`currency`) is the ServerStore ATOM key: the reactive mirror is per slice, not
	  per slot (the manifest's reader projects the active slot), so the atom name must not carry the
	  slot index.

	@class ProfilePath
]=]

local SLOTS = "slots"
local ACCOUNT = "account"
local WILDCARD = "*"

local ProfilePath = {}

ProfilePath.SLOTS = SLOTS
ProfilePath.ACCOUNT = ACCOUNT

--[=[
	Splits a dotted path into its segments.
	@param path string -- e.g. "slots.2.currency"
	@return { string } -- e.g. { "slots", "2", "currency" }
]=]
function ProfilePath.segments(path: string): { string }
	local out: { string } = {}
	for segment in string.gmatch(path, "[^.]+") do
		table.insert(out, segment)
	end
	return out
end

--[=[
	The concrete path to one slice of one slot.
	@param slice string -- The slice name (e.g. "currency")
	@param slotIndex number -- 1..MAX_SLOTS
	@return string -- e.g. "slots.2.currency"
]=]
function ProfilePath.forSlot(slice: string, slotIndex: number): string
	return `{SLOTS}.{slotIndex}.{slice}`
end

--[=[
	The path to one account-wide slice.
	@param slice string -- The slice name (e.g. "settings")
	@return string -- e.g. "account.settings"
]=]
function ProfilePath.forAccount(slice: string): string
	return `{ACCOUNT}.{slice}`
end

--[=[
	The REGISTRATION key for a slot-scoped slice: slot-index-agnostic.
	@param slice string -- The slice name
	@return string -- e.g. "slots.*.currency"
]=]
function ProfilePath.slotPattern(slice: string): string
	return `{SLOTS}.{WILDCARD}.{slice}`
end

--[=[
	Normalises a concrete path to its registration pattern by replacing numeric segments with `*`.
	`pattern(forSlot(slice, n)) == slotPattern(slice)` for every n — that identity is what makes a
	validator registered once hold for EVERY slot.
	@param path string -- A concrete path
	@return string -- Its pattern
]=]
function ProfilePath.pattern(path: string): string
	local out: { string } = {}
	for _, segment in ProfilePath.segments(path) do
		table.insert(out, if tonumber(segment) ~= nil then WILDCARD else segment)
	end
	return table.concat(out, ".")
end

--[=[
	The slice name (last segment) — the ServerStore atom key for this path.
	@param path string
	@return string
]=]
function ProfilePath.sliceName(path: string): string
	local segments = ProfilePath.segments(path)
	return segments[#segments]
end

--[=[
	The slot this path addresses, or nil if it is not slot-scoped (account path or bare root key).
	Callers use this to skip mirroring a write aimed at a NON-active slot (the atom holds the active
	slot only, so re-mirroring on such a write would be a no-op at best and misleading at worst).
	@param path string
	@return number? -- The slot index, or nil
]=]
function ProfilePath.slotIndex(path: string): number?
	local segments = ProfilePath.segments(path)
	if segments[1] ~= SLOTS then
		return nil
	end
	return tonumber(segments[2])
end

return ProfilePath
```

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS (lint, format, typecheck all clean).

Then run the TestEZ suite in Studio (`rojo serve` → connect → run `TestRunner.server.luau`) and confirm the `ProfilePath` describe block passes with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Modules/ProfilePath.luau src/ServerScriptService/Modules/ProfilePath.spec.luau
git commit -m "feat(data): add ProfilePath path algebra for slot-aware profiles"
```

---

### Task 2: The slot-aware profile shape

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau:26-31`
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau:13-22`
- Test: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau`

**Interfaces:**
- Consumes: nothing from Task 1 yet.
- Produces:
  - `PlayerDataTypes.PlayerSlot = { currency: Currency, inventory: { InventoryItem } }`
  - `PlayerDataTypes.PlayerAccount = { unlockedSlots: { number } }`
  - `PlayerDataTypes.PlayerProfile = { _schemaVersion: number?, activeSlot: number, account: PlayerAccount, slots: { PlayerSlot } }`
  - `PlayerDataConstants.MAX_SLOTS = 3`

Note `slots` is an **array** (`{ PlayerSlot }`, contiguous 1..3), not a map — a contiguous integer-keyed table JSON-serialises as an array, which is what DataStore stores.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau` (inside the existing top-level `describe`):

```lua
describe("slot-aware template", function()
	it("exposes MAX_SLOTS", function()
		expect(PlayerDataConstants.MAX_SLOTS).to.equal(3)
	end)

	it("starts new profiles on slot 1", function()
		expect(PlayerDataConstants.PROFILE_TEMPLATE.activeSlot).to.equal(1)
	end)

	it("gives new profiles MAX_SLOTS slot tables", function()
		expect(#PlayerDataConstants.PROFILE_TEMPLATE.slots).to.equal(PlayerDataConstants.MAX_SLOTS)
	end)

	it("unlocks only slot 1 by default", function()
		local unlocked = PlayerDataConstants.PROFILE_TEMPLATE.account.unlockedSlots
		expect(#unlocked).to.equal(1)
		expect(unlocked[1]).to.equal(1)
	end)

	it("gives each slot its OWN table (no shared-reference aliasing)", function()
		local slots = PlayerDataConstants.PROFILE_TEMPLATE.slots
		expect(slots[1]).to.never.equal(slots[2])
		expect(slots[2]).to.never.equal(slots[3])
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — typecheck errors: `activeSlot` / `slots` / `account` are not fields of `PlayerProfile`, `MAX_SLOTS` is not a field of `PlayerDataConstants`.

- [ ] **Step 3: Write the implementation**

In `src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau`, replace the `PlayerProfile` export (lines 26-31) with:

```lua
--[=[
	One character slot. Every slot-scoped domain slice registers a field here.

	INVARIANT: a slot is a SELF-CONTAINED SUBTREE — it must never hold a reference into another slot.
	That is what keeps a slot liftable into its own DataStore key later, if one ever outgrows the
	shared 4MB budget, without reshaping domain code.
]=]
export type PlayerSlot = {
	currency: Currency,
	inventory: { InventoryItem },
	-- Extend with other SLOT-SCOPED slices here (stats, equipment, hotbar, ...)
}

--[=[
	Account-wide data: entitlements and collections — "you own this". Idempotent by nature, therefore
	safe to share across characters. Quantities and item instances do NOT belong here (see the
	character-slots design: they must live under exactly one atomic owner).
]=]
export type PlayerAccount = {
	unlockedSlots: { number },
	-- Extend with other ACCOUNT-WIDE slices here (settings, unlocked cosmetics, entitlement titles, ...)
}

--[=[
	The whole profile: one ProfileStore key per player, with every character slot nested INSIDE it.
	That is what makes cross-slot item movement a single atomic UpdateAsync — and therefore makes
	cross-slot duplication structurally impossible rather than merely unlikely.
]=]
export type PlayerProfile = {
	_schemaVersion: number?, -- Managed by PlayerDataMigrations; absent on client-built profiles
	activeSlot: number,
	account: PlayerAccount,
	slots: { PlayerSlot },
}
```

In `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau`, replace the `PlayerDataConstants` table literal (lines 13-22) with:

```lua
local MAX_SLOTS = 3

-- Builds the empty slot array. Each slot is its OWN table: a single `{}` reused MAX_SLOTS times would
-- alias one table across all three, so a write to slot 1 would appear in slots 2 and 3.
local function emptySlots(): { PlayerDataTypes.PlayerSlot }
	local slots = {}
	for index = 1, MAX_SLOTS do
		slots[index] = {}
	end
	return slots
end

local PlayerDataConstants = {
	--[=[
		The number of character slots a profile carries.
		@prop MAX_SLOTS number
	]=]
	MAX_SLOTS = MAX_SLOTS,

	--[=[
		Template for new player profiles. Domain services append their own slices via
		registerSlotPath / registerAccountPath; the skeleton below is what those slices hang off.
		New profiles are stamped with the current schema version so they skip migrations.
		@prop PROFILE_TEMPLATE PlayerDataTypes.PlayerProfile
	]=]
	PROFILE_TEMPLATE = {
		_schemaVersion = PlayerDataMigrations.CURRENT_VERSION,
		activeSlot = 1,
		account = { unlockedSlots = { 1 } },
		slots = emptySlots(),
	} :: PlayerDataTypes.PlayerProfile,
}
```

The `emptySlots()` slots are typed `PlayerSlot` but start empty — `registerSlotPath` (Task 3) fills each one before the template is sealed, which is why this typechecks as `PlayerProfile` and why registration must happen at module load, before `seal()`.

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

> Existing `currency` / `inventory` registrations still call the old `SliceOwner.register`, which writes a **root** key. That is fine for now — Task 3 replaces it, and Task 7 moves currency. If typecheck complains that `PROFILE_TEMPLATE[path]` no longer resolves, that is expected and Task 3 fixes it; do not paper over it with a cast.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Types/PlayerDataTypes.luau src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau
git commit -m "feat(data): add slot-aware profile shape (activeSlot / account / slots)"
```

---

### Task 3: Nested registration + pattern-keyed validators

**Files:**
- Modify: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau` (`registerProfilePath` → slot/account registrars)
- Test: `src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau`

**Interfaces:**
- Consumes: `ProfilePath.slotPattern`, `ProfilePath.forAccount`, `ProfilePath.pattern` (Task 1); `PlayerDataConstants.MAX_SLOTS` (Task 2).
- Produces:
  - `PlayerDataConstants.registerSlotPath(slice: string, defaultData: any, validator: PathValidator?)` — stamps `defaultData` into **every** slot, deep-copied per slot; registers the validator under `slots.*.<slice>`.
  - `PlayerDataConstants.registerAccountPath(slice: string, defaultData: any, validator: PathValidator?)` — stamps into `account.<slice>`.
  - `PlayerDataConstants.getValidator(path)` — now looks up by `ProfilePath.pattern(path)`, so one registration covers every slot.

**The bug this task exists to prevent:** if `getValidator` were keyed by the concrete path, a validator registered for `currency` would be found for `slots.1.currency` only, and slots 2 and 3 would accept out-of-range values. The pattern normalisation is the whole point.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau`:

```lua
describe("registerSlotPath", function()
	it("stamps the default into EVERY slot", function()
		PlayerDataConstants.registerSlotPath("testStats", { level = 1 })
		for index = 1, PlayerDataConstants.MAX_SLOTS do
			expect(PlayerDataConstants.PROFILE_TEMPLATE.slots[index].testStats.level).to.equal(1)
		end
	end)

	it("deep-copies the default per slot, so slots never alias one table", function()
		PlayerDataConstants.registerSlotPath("testAlias", { level = 1 })
		local slots = PlayerDataConstants.PROFILE_TEMPLATE.slots
		expect(slots[1].testAlias).to.never.equal(slots[2].testAlias)

		slots[1].testAlias.level = 99
		expect(slots[2].testAlias.level).to.equal(1)
	end)

	it("registers the validator against EVERY slot, not just slot 1", function()
		PlayerDataConstants.registerSlotPath("testValidated", { n = 0 }, function(value)
			return value.n >= 0, "n must be non-negative"
		end)

		-- One registration; the validator must be found for any concrete slot path.
		for index = 1, PlayerDataConstants.MAX_SLOTS do
			local validator = PlayerDataConstants.getValidator(ProfilePath.forSlot("testValidated", index))
			expect(validator).to.be.ok()
			expect(validator({ n = -1 })).to.equal(false)
		end
	end)
end)

describe("registerAccountPath", function()
	it("stamps the default under account", function()
		PlayerDataConstants.registerAccountPath("testSettings", { sfx = true })
		expect(PlayerDataConstants.PROFILE_TEMPLATE.account.testSettings.sfx).to.equal(true)
	end)

	it("registers a validator found by the account path", function()
		PlayerDataConstants.registerAccountPath("testAccountValidated", { n = 0 }, function(value)
			return value.n >= 0, "n must be non-negative"
		end)
		local validator = PlayerDataConstants.getValidator(ProfilePath.forAccount("testAccountValidated"))
		expect(validator).to.be.ok()
		expect(validator({ n = -1 })).to.equal(false)
	end)
end)

describe("double registration", function()
	it("rejects registering the same slot slice twice", function()
		PlayerDataConstants.registerSlotPath("testDupe", { n = 0 })
		expect(function()
			PlayerDataConstants.registerSlotPath("testDupe", { n = 0 })
		end).to.throw()
	end)
end)
```

Add the `ProfilePath` require at the top of the spec:

```lua
local ProfilePath = require(ServerScriptService.Modules.ProfilePath)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — `registerSlotPath` / `registerAccountPath` are not fields of `PlayerDataConstants`.

- [ ] **Step 3: Write the implementation**

In `src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau`, add the `ProfilePath` require, then replace `registerProfilePath` (lines 60-82) and `getValidator` (lines 90-92) with:

```lua
local ProfilePath = require(ServerScriptService.Modules.ProfilePath)
```

```lua
-- Shared guard for both registrars. `patternKey` is the slot-index-agnostic key the validator is
-- stored under (see ProfilePath): registering once must cover every slot.
local function assertRegisterable(patternKey: string, slice: string, validator: PathValidator?)
	assert(type(slice) == "string", "slice must be a string")
	assert(
		not sealed,
		`[PlayerDataConstants] Cannot register slice "{slice}" after the template is sealed `
			.. "(PlayerDataService already initialized). Require the owning service module during boot, "
			.. 'before initService("PlayerDataServiceServer").'
	)
	assert(pathValidators[patternKey] == nil and registered[patternKey] == nil, `[PlayerDataConstants] Slice "{patternKey}" is already registered!`)
	if validator ~= nil then
		assert(type(validator) == "function", `validator for "{patternKey}" must be a function, got {type(validator)}`)
		pathValidators[patternKey] = validator
	end
	registered[patternKey] = true
end

-- Deep-copy so the template owns an independent table per destination. Callers pass literals
-- (e.g. { gold = 100 }); without this, all MAX_SLOTS slots would alias ONE default table and a write
-- to slot 1 would surface in slots 2 and 3. Scalars pass through untouched.
local function copyDefault(defaultData: any): any
	return if type(defaultData) == "table" then sift.Dictionary.copyDeep(defaultData) else defaultData
end

--[=[
	Registers a SLOT-SCOPED slice: one registration, stamped into every slot, validated in every slot.
	The owning service calls this via SliceOwner.registerSlot.
	@param slice string -- The slice name (e.g. "currency")
	@param defaultData any -- The initial value stamped into EACH slot of a new profile
	@param validator PathValidator? -- Invariant enforced by mutate()/transaction() on EVERY slot
]=]
function PlayerDataConstants.registerSlotPath(slice: string, defaultData: any, validator: PathValidator?)
	assertRegisterable(ProfilePath.slotPattern(slice), slice, validator)
	for index = 1, MAX_SLOTS do
		PlayerDataConstants.PROFILE_TEMPLATE.slots[index][slice] = copyDefault(defaultData)
	end
end

--[=[
	Registers an ACCOUNT-WIDE slice. The owning service calls this via SliceOwner.registerAccount.
	@param slice string -- The slice name (e.g. "settings")
	@param defaultData any -- The initial value stamped onto new profiles
	@param validator PathValidator? -- Invariant enforced by mutate()/transaction()
]=]
function PlayerDataConstants.registerAccountPath(slice: string, defaultData: any, validator: PathValidator?)
	assertRegisterable(ProfilePath.forAccount(slice), slice, validator)
	PlayerDataConstants.PROFILE_TEMPLATE.account[slice] = copyDefault(defaultData)
end

--[=[
	Returns the invariant validator for a CONCRETE path, looked up by its PATTERN. This normalisation
	is load-bearing: a slice registers its validator once, and every slot must be covered by it. Keying
	the lookup on the concrete path would find the validator for slot 1 only, silently leaving slots 2
	and 3 unvalidated — precisely the class of bug the data-layer validator exists to prevent.
	@param path string -- A concrete profile path (e.g. "slots.2.currency")
	@return PathValidator? -- The validator, or nil if the slice is unvalidated
]=]
function PlayerDataConstants.getValidator(path: string): PathValidator?
	return pathValidators[ProfilePath.pattern(path)]
end
```

Add alongside the existing `pathValidators` declaration:

```lua
-- Every registered pattern key, so a double registration is caught even when the slice has no
-- validator (pathValidators alone would not notice).
local registered: { [string]: true } = {}
```

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

Run the TestEZ suite in Studio; the `registerSlotPath` / `registerAccountPath` blocks must pass.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Modules/Constants/PlayerDataConstants.luau src/ServerScriptService/Modules/Constants/PlayerDataConstants.spec.luau
git commit -m "feat(data): register slices per-slot and per-account with pattern-keyed validators"
```

---

### Task 4: Path resolution in PlayerDataService

The core change. `profile.Data[path]` becomes `resolve(profile.Data, path)` at every site.

**Files:**
- Modify: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau` — `_getSliceShell` (471-488), `mutate` (506-620), `transaction` (~762, ~792, ~839)
- Test: `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau`

**Interfaces:**
- Consumes: `ProfilePath.sliceName`, `ProfilePath.slotIndex` (Task 1).
- Produces:
  - `PlayerDataService:getActiveSlot(userId: number) -> number?`
  - `PlayerDataService:_getSlotShell(userId: number, slotIndex: number, slice: string) -> PlayerDataTypes.PlayerSlot?`
  - `PlayerDataService:_getAccountShell(userId: number, slice: string) -> PlayerDataTypes.PlayerAccount?`
  - `mutate` / `transaction` accept dotted paths.

Two separate shell methods (rather than one returning a union) so each returns a **concrete** type and `SliceOwner`'s `read` closure typechecks with **no cast**.

**Mirror rule:** the ServerStore atom holds the **active slot only** (the manifest reader projects it — Task 6). So a committed write mirrors iff the path is account-scoped, or its slot index equals `activeSlot`. A write to a non-active slot must NOT mirror.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau`, following the existing mock-profile setup in that file:

```lua
describe("slot-aware paths", function()
	it("mutates the active slot's slice through a dotted path", function()
		local ok = PlayerDataService:mutate(USER_ID, ProfilePath.forSlot("currency", 1), function(currency)
			currency.gold += 50
			return true
		end)
		expect(ok).to.equal(true)
		expect(PlayerDataService:getProfile(USER_ID).slots[1].currency.gold).to.equal(150)
	end)

	it("keeps slots independent — writing slot 1 does not touch slot 2", function()
		PlayerDataService:mutate(USER_ID, ProfilePath.forSlot("currency", 1), function(currency)
			currency.gold = 777
			return true
		end)
		expect(PlayerDataService:getProfile(USER_ID).slots[2].currency.gold).to.equal(100)
	end)

	it("enforces the slice invariant on a NON-first slot", function()
		local ok = PlayerDataService:mutate(USER_ID, ProfilePath.forSlot("currency", 3), function(currency)
			currency.gold = -1
			return true
		end)
		expect(ok).to.equal(false)
		expect(PlayerDataService:getProfile(USER_ID).slots[3].currency.gold).to.equal(100)
	end)

	it("mirrors a write to the ACTIVE slot into ServerStore", function()
		PlayerDataService:mutate(USER_ID, ProfilePath.forSlot("currency", 1), function(currency)
			currency.gold = 500
			return true
		end)
		expect(ServerStore.snapshot("currency")[USER_ID].gold).to.equal(500)
	end)

	it("does NOT mirror a write to an INACTIVE slot", function()
		-- activeSlot is 1; the atom must keep showing slot 1's value.
		local before = ServerStore.snapshot("currency")[USER_ID].gold
		PlayerDataService:mutate(USER_ID, ProfilePath.forSlot("currency", 2), function(currency)
			currency.gold = 4242
			return true
		end)
		expect(ServerStore.snapshot("currency")[USER_ID].gold).to.equal(before)
	end)

	it("mutates an account slice", function()
		local ok = PlayerDataService:mutate(USER_ID, ProfilePath.forAccount("unlockedSlots"), function(unlocked)
			table.insert(unlocked, 2)
			return true
		end)
		expect(ok).to.equal(true)
		expect(#PlayerDataService:getProfile(USER_ID).account.unlockedSlots).to.equal(2)
	end)

	it("returns the active slot", function()
		expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(1)
	end)

	it("rejects an unknown path without mutating", function()
		local ok = PlayerDataService:mutate(USER_ID, "slots.9.currency", function()
			return true
		end)
		expect(ok).to.equal(false)
	end)

	it("rolls back a transaction spanning an account slice and a slot slice", function()
		local result = PlayerDataService:transaction({
			{
				userId = USER_ID,
				path = ProfilePath.forSlot("currency", 1),
				mutator = function(currency)
					currency.gold = 999
					return true
				end,
			},
			{
				userId = USER_ID,
				path = ProfilePath.forAccount("unlockedSlots"),
				mutator = function()
					return false -- abort the whole transaction
				end,
			},
		})
		expect(result.success).to.equal(false)
		expect(PlayerDataService:getProfile(USER_ID).slots[1].currency.gold).to.never.equal(999)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — `getActiveSlot` is not a field of the service; dotted paths resolve to `nil`.

- [ ] **Step 3: Write the implementation**

Add the require at the top of `PlayerDataServiceServer.luau`:

```lua
local ProfilePath = require(ServerScriptService.Modules.ProfilePath)
```

Add this file-local helper above the service literal:

```lua
--[=[
	Resolves a dotted profile path to the CONTAINER table holding the leaf, plus the leaf's key.
	`slots.2.currency` -> (profile.slots[2], "currency"); `account.settings` -> (profile.account,
	"settings"); a bare root key -> (profile, key). Returns nil if any segment is missing, which is how
	mutate() rejects an unknown path instead of creating one.

	Walking the path is the ONE place the profile's nesting is understood; every call site below
	(read, mutate, transaction, rollback) goes through it, so none of them index profile.Data directly.
]=]
local function resolvePath(data: PlayerDataTypes.PlayerProfile, path: string): ({ [string]: any }?, string?)
	local segments = ProfilePath.segments(path)
	local container: any = data
	for index = 1, #segments - 1 do
		local segment = segments[index]
		local key: any = tonumber(segment) or segment
		container = container[key]
		if type(container) ~= "table" then
			return nil, nil
		end
	end
	return container, segments[#segments]
end
```

Rewrite `_getSliceShell` as the two typed shell readers:

```lua
	--[=[
		INTERNAL PLUMBING for SliceOwner.registerSlot's `get` — not for game code.

		Returns a shallow SHELL of one slot (`table.clone` of the slot table) with ONLY the requested
		slice swapped for a frozen deep copy. The shell exists so SliceOwner's typed `read` (a field
		access on PlayerSlot) can re-assert the slice type on the way out with no written cast.

		CONTRACT (unchanged from the old _getSliceShell): the caller must immediately project the
		swapped slice out of the shell and drop the shell. The shell's OTHER fields still alias the LIVE
		slot tables — that is what keeps this O(slice) rather than O(profile).

		@param userId number
		@param slotIndex number -- 1..MAX_SLOTS
		@param slice string -- The slice name (e.g. "currency")
		@return PlayerDataTypes.PlayerSlot? -- The shell, or nil if the profile/slot/slice isn't loaded
	]=]
	_getSlotShell = function(_self, userId, slotIndex, slice)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(slice) == "string", `slice must be a string, got {type(slice)}`)

		local profile = playerProfiles[userId]
		if not profile then
			return nil
		end
		local slot = profile.Data.slots[slotIndex]
		if not slot then
			return nil
		end
		local live = slot[slice]
		if live == nil then
			return nil
		end
		local shell = table.clone(slot)
		shell[slice] = if type(live) == "table" then sift.Dictionary.freezeDeep(live) else live
		return shell
	end,

	--[=[
		INTERNAL PLUMBING for SliceOwner.registerAccount's `get`. Same shell contract as _getSlotShell,
		over the account table.
		@param userId number
		@param slice string
		@return PlayerDataTypes.PlayerAccount?
	]=]
	_getAccountShell = function(_self, userId, slice)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(slice) == "string", `slice must be a string, got {type(slice)}`)

		local profile = playerProfiles[userId]
		if not profile then
			return nil
		end
		local live = profile.Data.account[slice]
		if live == nil then
			return nil
		end
		local shell = table.clone(profile.Data.account)
		shell[slice] = if type(live) == "table" then sift.Dictionary.freezeDeep(live) else live
		return shell
	end,

	--[=[
		The slot the player is currently playing. SliceOwner.registerSlot resolves this at CALL time, so
		every slot-scoped read/write lands on the active character without domain services knowing slots
		exist.
		@param userId number
		@return number? -- The active slot index, or nil if the profile isn't loaded
	]=]
	getActiveSlot = function(_self, userId)
		Guard.userId(userId)
		local profile = playerProfiles[userId]
		return if profile then profile.Data.activeSlot else nil
	end,
```

In `mutate`, replace the direct `profile.Data[path]` indexing (lines 541-560) with the resolved container:

```lua
		local container, key = resolvePath(profile.Data, path)
		if not container or not key then
			log:warn("Cannot mutate, path not found:", path)
			return false
		end

		local data = container[key]
		if data == nil then
			log:warn("Cannot mutate, path not found:", path)
			return false
		end

		local snapshot = if type(data) == "table" then sift.Dictionary.copyDeep(data) else data
		local function rollback()
			-- Re-resolve at restore time (mirrors transaction's rollbackAll), so the write lands in
			-- whatever table the profile CURRENTLY holds rather than a since-detached reference.
			local restoreContainer, restoreKey = resolvePath(profile.Data, path)
			if restoreContainer and restoreKey then
				restoreContainer[restoreKey] = if type(snapshot) == "table"
					then sift.Dictionary.copyDeep(snapshot)
					else snapshot
			end
		end
```

Then, in the same function, the validator check reads through the container (replacing `profile.Data[path]` at line 596):

```lua
		local validator = PlayerDataConstants.getValidator(path)
		if validator then
			local valid, reason = validator(container[key])
			if not valid then
				rollback()
				log:error(
					"mutate() rejected: slice invariant violated. userId:",
					userId,
					"path:",
					path,
					"reason:",
					reason or "invalid"
				)
				return false
			end
		end
```

And the mirror (replacing lines 616-618):

```lua
		-- Mirror only the slice that changed. The atom is keyed by SLICE NAME, not by path — the
		-- manifest's reader projects the ACTIVE slot (see SliceManifest), so a write aimed at a
		-- non-active slot must not re-mirror: it would push the active slot's (unchanged) value and
		-- imply a change that the client cannot see. Account paths always mirror.
		local slotIndex = ProfilePath.slotIndex(path)
		if slotIndex == nil or slotIndex == profile.Data.activeSlot then
			local slice = ProfilePath.sliceName(path)
			if ServerStore.isSyncedSlice(slice) then
				ServerStore.sync(slice, userId, profile.Data)
			end
		end
```

Apply the identical three substitutions inside `transaction` — the snapshot/apply site (~762), the per-op data read (~792), the per-op validator (~839), and the post-commit mirror (~951). Every `profile.Data[op.path]` / `profileData[path]` becomes a `resolvePath` pair, and the mirror gains the same slot-index guard. **Do not leave a single direct `profile.Data[path]` index behind** — grep to confirm:

```bash
grep -n "Data\[path\]\|Data\[op\.path\]\|profileData\[path\]" src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau
```

Expected: no matches.

Finally, add the three new methods to the `PlayerDataServiceServer` exported type (the annotated-literal interface at the top of the file):

```lua
	getActiveSlot: (self: PlayerDataServiceServer, userId: number) -> number?,
	_getSlotShell: (
		self: PlayerDataServiceServer,
		userId: number,
		slotIndex: number,
		slice: string
	) -> PlayerDataTypes.PlayerSlot?,
	_getAccountShell: (
		self: PlayerDataServiceServer,
		userId: number,
		slice: string
	) -> PlayerDataTypes.PlayerAccount?,
```

and delete the old `_getSliceShell` field from both the type and the literal.

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

Run the TestEZ suite in Studio. The whole `PlayerDataServiceServer` describe block must pass — **including the pre-existing transaction/rollback tests**, which are the regression guard on this task.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.luau src/ServerScriptService/Services/PlayerDataService/PlayerDataServiceServer.spec.luau
git commit -m "feat(data): resolve dotted profile paths in mutate/transaction and mirror the active slot only"
```

---

### Task 5: `SliceOwner.registerSlot` / `registerAccount`

**Files:**
- Modify: `src/ServerScriptService/Modules/SliceOwner.luau`
- Test: `src/ServerScriptService/Modules/SliceOwner.spec.luau`

**Interfaces:**
- Consumes: `PlayerDataConstants.registerSlotPath` / `registerAccountPath` (Task 3); `PlayerDataService:getActiveSlot` / `_getSlotShell` / `_getAccountShell` (Task 4); `ProfilePath.forSlot` / `forAccount` (Task 1).
- Produces:
  - `SliceOwner.registerSlot<T>(slice, default, read: (slot: PlayerSlot) -> T, validate?) -> SliceAccessor<T>`
  - `SliceOwner.registerAccount<T>(slice, default, read: (account: PlayerAccount) -> T, validate?) -> SliceAccessor<T>`
  - `SliceAccessor<T>` gains `getForSlot: (userId: number, slotIndex: number) -> T?` (slot accessor only).

`SliceAccessor`'s `get` / `mutate` / `op` signatures are **unchanged** — that is the point: domain services keep reading and writing a plain `T` and never learn slots exist. `registerSlot` resolves the active slot **at call time**, not at registration.

Note the `read` closure now takes a **`PlayerSlot`** (`function(slot) return slot.currency end`), not a whole profile — that is what lets one closure serve both `get` (active slot) and `getForSlot` (any slot) with no cast.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Modules/SliceOwner.spec.luau`:

```lua
describe("registerSlot", function()
	it("reads and writes the ACTIVE slot without the caller naming a slot", function()
		local slice = SliceOwner.registerSlot("testGold", { amount = 0 }, function(slot)
			return slot.testGold
		end)

		slice.mutate(USER_ID, function(gold)
			gold.amount = 42
			return true
		end)

		expect(slice.get(USER_ID).amount).to.equal(42)
		-- activeSlot is 1, so the write must have landed in slot 1 and nowhere else.
		expect(slice.getForSlot(USER_ID, 1).amount).to.equal(42)
		expect(slice.getForSlot(USER_ID, 2).amount).to.equal(0)
	end)

	it("follows the active slot when it changes", function()
		local slice = SliceOwner.registerSlot("testFollow", { amount = 0 }, function(slot)
			return slot.testFollow
		end)

		slice.mutate(USER_ID, function(value)
			value.amount = 1
			return true
		end)

		setActiveSlot(USER_ID, 2) -- test helper: mutates profile.activeSlot directly

		expect(slice.get(USER_ID).amount).to.equal(0) -- slot 2 is untouched
		slice.mutate(USER_ID, function(value)
			value.amount = 2
			return true
		end)
		expect(slice.getForSlot(USER_ID, 1).amount).to.equal(1)
		expect(slice.getForSlot(USER_ID, 2).amount).to.equal(2)
	end)

	it("returns a frozen read — mutating it throws", function()
		local slice = SliceOwner.registerSlot("testFrozen", { amount = 0 }, function(slot)
			return slot.testFrozen
		end)
		local value = slice.get(USER_ID)
		expect(function()
			value.amount = 1
		end).to.throw()
	end)
end)

describe("registerAccount", function()
	it("reads and writes the account slice", function()
		local slice = SliceOwner.registerAccount("testFlags", { premium = false }, function(account)
			return account.testFlags
		end)

		slice.mutate(USER_ID, function(flags)
			flags.premium = true
			return true
		end)

		expect(slice.get(USER_ID).premium).to.equal(true)
	end)

	it("is shared across slots — switching slot does not change it", function()
		local slice = SliceOwner.registerAccount("testShared", { n = 0 }, function(account)
			return account.testShared
		end)
		slice.mutate(USER_ID, function(value)
			value.n = 7
			return true
		end)
		setActiveSlot(USER_ID, 3)
		expect(slice.get(USER_ID).n).to.equal(7)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — `registerSlot` / `registerAccount` are not fields of `SliceOwner`.

- [ ] **Step 3: Write the implementation**

In `src/ServerScriptService/Modules/SliceOwner.luau`, extend the accessor type and replace `register` with the two registrars:

```lua
local ProfilePath = require(ServerScriptService.Modules.ProfilePath)
```

```lua
--[=[
	Read/mutate access to one profile slice, typed to that slice's value.

	`get`/`mutate`/`op` are IDENTICAL in shape for slot-scoped and account-wide slices: a slot slice
	resolves the player's ACTIVE slot at call time. That is deliberate — domain services (CurrencyService,
	a future StatsService) never learn that slots exist; they read and write a plain `T` for "the
	character this player is currently playing".

	@interface SliceAccessor<T>
	.get (userId: number) -> T? -- The active slot's (or the account's) slice value
	.getForSlot (userId: number, slotIndex: number) -> T? -- An explicit slot; nil on an account slice
	.mutate (userId: number, fn: (value: T) -> boolean?) -> boolean
	.op (userId: number, fn: (value: T) -> boolean) -> TransactionOperation
]=]
export type SliceAccessor<T> = {
	get: (userId: number) -> T?,
	getForSlot: (userId: number, slotIndex: number) -> T?,
	mutate: (userId: number, fn: (value: T) -> boolean?) -> boolean,
	op: (userId: number, fn: (value: T) -> boolean) -> PlayerDataService.TransactionOperation,
}

--[=[
	Registers a SLOT-SCOPED slice (stats, inventory, currency, …) and returns typed access to it.
	Call once at the owning service's module load, before PlayerDataService seals the template.

	The slice's value type `T` is inferred from the `read` closure — a typed field access on a
	PlayerSlot (`function(slot) return slot.currency end`) — so `get` returns `T?` and `mutate`'s
	mutator argument is typed `T`, with ZERO casts. The SAME closure serves `get` (active slot) and
	`getForSlot` (an explicit slot), which is why it takes a slot rather than a whole profile.

	@param slice string -- The slice name this service owns (e.g. "currency")
	@param default unknown -- The initial value stamped into EVERY slot of a new profile
	@param read (slot: PlayerDataTypes.PlayerSlot) -> T -- Typed reader off one slot; drives T
	@param validate ((value: T) -> (boolean, string?))? -- Invariant enforced on EVERY slot
	@return SliceAccessor<T>
]=]
function SliceOwner.registerSlot<T>(
	slice: string,
	default: unknown,
	read: (slot: PlayerDataTypes.PlayerSlot) -> T,
	validate: ((value: T) -> (boolean, string?))?
): SliceAccessor<T>
	PlayerDataConstants.registerSlotPath(slice, default, validate)

	local function pathFor(userId: number): string?
		local activeSlot = PlayerDataService:getActiveSlot(userId)
		return if activeSlot then ProfilePath.forSlot(slice, activeSlot) else nil
	end

	return {
		get = function(userId)
			Guard.userId(userId)
			local activeSlot = PlayerDataService:getActiveSlot(userId)
			if not activeSlot then
				return nil
			end
			local shell = PlayerDataService:_getSlotShell(userId, activeSlot, slice)
			if not shell then
				return nil
			end
			return read(shell)
		end,

		getForSlot = function(userId, slotIndex)
			Guard.userId(userId)
			local shell = PlayerDataService:_getSlotShell(userId, slotIndex, slice)
			if not shell then
				return nil
			end
			return read(shell)
		end,

		mutate = function(userId, fn)
			Guard.userId(userId)
			local path = pathFor(userId)
			if not path then
				return false
			end
			return PlayerDataService:mutate(userId, path, fn)
		end,

		-- The active slot is resolved when the op is MINTED (transaction() runs it later). That is
		-- correct: a slot switch is itself a mutation and cannot interleave with a transaction, so the
		-- slot an op was minted against is the slot it commits against.
		op = function(userId, fn)
			Guard.userId(userId)
			local path = pathFor(userId)
			assert(path, `SliceOwner.op: no profile loaded for userId {userId}`)
			return { userId = userId, path = path, mutator = fn }
		end,
	}
end

--[=[
	Registers an ACCOUNT-WIDE slice (settings, unlocked cosmetics, entitlement titles, …).
	Same accessor shape as registerSlot; `getForSlot` returns the account value regardless of slot,
	because an account slice is by definition the same for every character.

	@param slice string -- The slice name (e.g. "settings")
	@param default unknown -- The initial value stamped onto new profiles
	@param read (account: PlayerDataTypes.PlayerAccount) -> T -- Typed reader; drives T
	@param validate ((value: T) -> (boolean, string?))? -- Invariant enforced by mutate()/transaction()
	@return SliceAccessor<T>
]=]
function SliceOwner.registerAccount<T>(
	slice: string,
	default: unknown,
	read: (account: PlayerDataTypes.PlayerAccount) -> T,
	validate: ((value: T) -> (boolean, string?))?
): SliceAccessor<T>
	PlayerDataConstants.registerAccountPath(slice, default, validate)
	local path = ProfilePath.forAccount(slice)

	local function readAccount(userId: number): T?
		local shell = PlayerDataService:_getAccountShell(userId, slice)
		if not shell then
			return nil
		end
		return read(shell)
	end

	return {
		get = function(userId)
			Guard.userId(userId)
			return readAccount(userId)
		end,

		getForSlot = function(userId, _slotIndex)
			Guard.userId(userId)
			return readAccount(userId)
		end,

		mutate = function(userId, fn)
			Guard.userId(userId)
			return PlayerDataService:mutate(userId, path, fn)
		end,

		op = function(userId, fn)
			Guard.userId(userId)
			return { userId = userId, path = path, mutator = fn }
		end,
	}
end
```

Delete the old `SliceOwner.register`. The `PlayerDataTypes` require is already present at the top of the file.

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

Run the TestEZ suite in Studio; the `SliceOwner` block must pass.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Modules/SliceOwner.luau src/ServerScriptService/Modules/SliceOwner.spec.luau
git commit -m "feat(data): add SliceOwner.registerSlot / registerAccount"
```

---

### Task 6: The mirror projects the active slot

**Files:**
- Modify: `src/ReplicatedStorage/Shared/State/SliceManifest.luau:36-47`
- Test: `src/ReplicatedStorage/Shared/State/SliceManifest.spec.luau`

**Interfaces:**
- Consumes: the `PlayerProfile` shape (Task 2).
- Produces: `currency` and `inventory` manifest readers that project `profile.slots[profile.activeSlot]`.

This is the change that keeps **inactive characters' data off the wire**. `ServerStore.sync` already calls `read(profile)` on the full profile, so no `ServerStore` edit is needed — the projection lives entirely in the reader.

- [ ] **Step 1: Write the failing spec**

Add to `src/ReplicatedStorage/Shared/State/SliceManifest.spec.luau`:

```lua
describe("slot-scoped readers", function()
	local function profileWith(activeSlot)
		return {
			activeSlot = activeSlot,
			account = { unlockedSlots = { 1 } },
			slots = {
				{ currency = { gold = 1 }, inventory = {} },
				{ currency = { gold = 2 }, inventory = {} },
				{ currency = { gold = 3 }, inventory = {} },
			},
		}
	end

	it("reads currency from the ACTIVE slot", function()
		expect(SliceManifest.DEFINITIONS.currency.read(profileWith(2)).gold).to.equal(2)
	end)

	it("follows the active slot", function()
		expect(SliceManifest.DEFINITIONS.currency.read(profileWith(3)).gold).to.equal(3)
	end)

	it("never exposes an inactive slot's value", function()
		local mirrored = SliceManifest.DEFINITIONS.currency.read(profileWith(1))
		expect(mirrored.gold).to.equal(1)
		expect(mirrored.gold).to.never.equal(2)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — typecheck: `currency` is not a field of `PlayerProfile` (the readers still index the old root key).

- [ ] **Step 3: Write the implementation**

In `src/ReplicatedStorage/Shared/State/SliceManifest.luau`, replace `DEFINITIONS` (lines 36-47):

```lua
-- The replicated slices. One entry here is the manifest edit when adding a slice.
--
-- A SLOT-SCOPED slice reads through `profile.slots[profile.activeSlot]`, so the atom — and therefore
-- everything charm-sync ships to the client — holds the ACTIVE character only. Inactive slots' data
-- never leaves the server. An ACCOUNT-WIDE slice reads through `profile.account` instead.
local DEFINITIONS: { [string]: SliceDefinition } = {
	currency = {
		read = function(profile)
			return profile.slots[profile.activeSlot].currency
		end,
	},
	inventory = {
		read = function(profile)
			return profile.slots[profile.activeSlot].inventory
		end,
	},
}
```

Also update the "adding a slice" recipe in this file's header comment: step 1 becomes "Add the field to `PlayerDataTypes.PlayerSlot` (slot-scoped) or `PlayerAccount` (account-wide)", and step 4 becomes "Register via `SliceOwner.registerSlot` / `registerAccount`".

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/State/SliceManifest.luau src/ReplicatedStorage/Shared/State/SliceManifest.spec.luau
git commit -m "feat(state): mirror only the active slot's slices to the client"
```

---

### Task 7: Move `currency` to slot-scoped (the proof)

The end-to-end proof that a real domain service becomes slot-aware **without its domain logic changing**. `inventory` follows in Phase 3; leave `InventoryServiceServer` on the same treatment only if it currently calls `SliceOwner.register` (it does — update the call identically, but do not touch its domain logic).

**Files:**
- Modify: `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.luau:43-48`
- Modify: `src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau` (its `SliceOwner.register` call only)
- Test: `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.spec.luau`

**Interfaces:**
- Consumes: `SliceOwner.registerSlot` (Task 5).
- Produces: no public API change to `CurrencyServiceServer` — that is the deliverable.

- [ ] **Step 1: Write the failing spec**

Add to `src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.spec.luau`:

```lua
describe("slot scoping", function()
	it("keeps each character's currency separate", function()
		CurrencyService:addCurrency(USER_ID, "gold", 50) -- active slot is 1
		expect(CurrencyService:getCurrencyAmount(USER_ID, "gold")).to.equal(150)

		setActiveSlot(USER_ID, 2)
		-- Slot 2 is a fresh character: it has the template default, not slot 1's balance.
		expect(CurrencyService:getCurrencyAmount(USER_ID, "gold")).to.equal(100)

		CurrencyService:addCurrency(USER_ID, "gold", 5)
		expect(CurrencyService:getCurrencyAmount(USER_ID, "gold")).to.equal(105)

		setActiveSlot(USER_ID, 1)
		expect(CurrencyService:getCurrencyAmount(USER_ID, "gold")).to.equal(150)
	end)

	it("enforces the currency cap on a non-first slot", function()
		setActiveSlot(USER_ID, 3)
		local ok = CurrencyService:addCurrency(USER_ID, "gold", CurrencyConstants.MAX_CURRENCY + 1)
		expect(ok).to.equal(false)
		expect(CurrencyService:getCurrencyAmount(USER_ID, "gold")).to.equal(100)
	end)
end)
```

- [ ] **Step 2: Run the gate to see it fail**

Run: `bash scripts/check.sh --skip-install`
Expected: FAIL — `SliceOwner.register` no longer exists (deleted in Task 5).

- [ ] **Step 3: Write the implementation**

In `CurrencyServiceServer.luau`, replace the registration (lines 43-48). Only the registrar and the reader's argument change — `validateCurrency` and every method below are untouched:

```lua
-- Registers "currency" as a SLOT-SCOPED slice: each character has its own balance. The reader takes a
-- PlayerSlot (not a whole profile), which is what lets SliceOwner serve both `get` (the active
-- character) and `getForSlot` (the slot-select preview) from one typed closure. Currency's DOMAIN
-- logic below is unchanged — the service never learns that slots exist.
local currencySlice = SliceOwner.registerSlot("currency", {
	gold = 100,
	gems = 10,
}, function(slot)
	return slot.currency
end, validateCurrency)
```

Apply the identical shape to `InventoryServiceServer.luau`'s registration:

```lua
local inventorySlice = SliceOwner.registerSlot("inventory", {}, function(slot)
	return slot.inventory
end, validateInventory)
```

(Keep whatever the existing default and validator arguments are — only the registrar name and the reader's parameter change.)

- [ ] **Step 4: Run the gate to verify it passes**

Run: `bash scripts/check.sh --skip-install`
Expected: PASS.

Run the **full** TestEZ suite in Studio. Every pre-existing Currency and Inventory test must still pass **unchanged** — that is the proof that a domain service is slot-aware without its domain logic changing. Confirm the total count matches the previous baseline plus the new tests, with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.luau src/ServerScriptService/Services/CurrencyService/CurrencyServiceServer.spec.luau src/ServerScriptService/Services/InventoryService/InventoryServiceServer.luau
git commit -m "feat(currency): scope currency and inventory slices to the active character slot"
```

---

## Done when

- `bash scripts/check.sh` is clean (lint + format + typecheck + ruff).
- The full TestEZ suite passes in Studio with 0 failures, including every pre-existing test.
- No `::` casts were added anywhere.
- `grep -rn "SliceOwner.register(" src/` returns no matches (the old root-key registrar is gone).
- A write to slot 2 while slot 1 is active changes slot 2's stored data and does **not** change the client's `currency` atom.

## Follow-on (NOT this plan)

`SlotService` (the slot-switch flow + the on-demand preview RPC) and the slot-select UI are the second half of Phase 1 and get their own plan, written once this foundation lands and we know whether the accessor API held up. The switch itself is: validate (Guard: in range, unlocked, not in combat/trade) → despawn → `mutate` `activeSlot` → re-mirror every slot-scoped slice via `ServerStore.syncFromProfile` → respawn. No DataStore call, no lock, no crash window.
