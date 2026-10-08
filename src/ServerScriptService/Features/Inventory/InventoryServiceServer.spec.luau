--!strict
--[=[
	Unit tests for InventoryServiceServer.

	Mock strategy: UNLIKE the sibling domain specs (e.g. CurrencyServiceServer.spec), which mock
	PlayerDataService's read/write surface, this spec seeds REAL fake profiles through PlayerDataService's `_setProfileForTesting` seam (the same strategy
	PlayerDataServiceServer.spec uses) and drives the REAL `mutate()`/`transaction()`. That is a
	deliberate deviation: addItem's unique-item path composes an atomic `transaction()` across TWO
	slices (the account-wide itemMint counter and the slot-scoped inventory), and the guarantee under
	test — a kind-cap violation caught by the REGISTERED validateInventory rolls back BOTH ops, so
	`nextUid` never advances for entries that were never added — only means something against the
	real transaction/validator machinery. Reimplementing that machinery as a spec-local mock would
	either be unfaithful or duplicate PlayerDataServiceServer's own tests; using the real thing is both
	less code and a stronger guarantee.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local InventoryService = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local sift = require(ReplicatedStorage.Packages.sift)

-- ============================================================
-- Helpers
-- ============================================================

-- Minimal synchronous signal: enough for OnSave Connect/Fire, mirroring
-- PlayerDataServiceServer.spec's fakeSignal (needed because `_setProfileForTesting` wires an
-- OnSave connection for the auto-save-abort seam).
local function fakeSignal()
	local handlers: { [(...any) -> ()]: boolean } = {}
	return {
		Connect = function(_self, fn: (...any) -> ())
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			local snapshot = {}
			for fn in handlers do
				table.insert(snapshot, fn)
			end
			for _, fn in snapshot do
				fn(...)
			end
		end,
	}
end

local function makeFakeProfile(data: any)
	return {
		Data = data,
		LastSavedData = sift.Dictionary.copyDeep(data),
		OnSave = fakeSignal(),
		OnAfterSave = fakeSignal(),
		IsActive = function()
			return true
		end,
		Save = function() end,
	}
end

-- A whole slot-aware profile: every slot seeded with the registered template defaults, with the
-- ACTIVE slot's inventory stamped with `items` and the account's item-mint counter stamped with
-- `nextUid` (defaults to 1 — a fresh account that has never minted a unique item).
local function makeProfileData(
	items: { PlayerDataTypes.InventoryEntry }?,
	nextUid: number?
): PlayerDataTypes.PlayerProfile
	local slots: { PlayerDataTypes.PlayerSlot } = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { coins = 100 },
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	slots[1].inventory = { items = items or {} }
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = nextUid or 1 },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

-- The slot the service's reads and writes must land in.
local function activeSlotOf(profile: any): PlayerDataTypes.PlayerSlot
	return profile.Data.slots[profile.Data.slotState.active]
end

-- Recursive structural equality over plain data tables (items arrays / entries) — used for the
-- "refused, and the array is unchanged" assertions, which must catch ANY drift, not just a count.
local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil and b[key] ~= nil then
			return false
		end
	end
	return true
end

-- A stack entry literal, typed loosely for fixture-building convenience.
local function stack(itemType: string, quantity: number): PlayerDataTypes.InventoryEntry
	return { itemType = itemType, quantity = quantity } :: PlayerDataTypes.StackEntry
end

local function unique(itemType: string, uid: string): PlayerDataTypes.InventoryEntry
	return { itemType = itemType, uid = uid } :: PlayerDataTypes.UniqueEntry
end

return function()
	-- Multi-slot behaviour is dormant while MAX_SLOTS = 1; these re-enable when a game raises it.
	local itMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then it else itSKIP
	local describeMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then describe else describeSKIP

	describe("InventoryServiceServer", function()
		local profiles: { [number]: any } = {}

		beforeAll(function()
			-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM.
			ItemContentRegistry.init()
		end)

		beforeEach(function()
			profiles = {}
		end)

		afterEach(function()
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			profiles = {}
		end)

		local function seed(userId: number, items: { PlayerDataTypes.InventoryEntry }?, nextUid: number?)
			local profile = makeFakeProfile(makeProfileData(items, nextUid))
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		-- ---------------------------------------------------------------------
		describe("getInventory", function()
			it("returns the inventory wrapper for a loaded player", function()
				seed(1, { stack("medkit", 5) })
				local inv = InventoryService:getInventory(1)
				expect(inv).to.be.ok()
				assert(inv, "checked above")
				expect(#inv.items).to.equal(1)
				expect(inv.items[1].itemType).to.equal("medkit")
			end)

			it("returns nil when the profile is not loaded", function()
				expect(InventoryService:getInventory(999)).to.equal(nil)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					InventoryService:getInventory("bad" :: any)
				end).to.throw()
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("hasItem", function()
			it("returns true when the player has the item", function()
				seed(1, { stack("medkit", 10) })
				expect(InventoryService:hasItem(1, "medkit")).to.equal(true)
			end)

			it("returns false when the item is missing", function()
				seed(1, {})
				expect(InventoryService:hasItem(1, "medkit")).to.equal(false)
			end)

			it("returns true/false around a required quantity", function()
				seed(1, { stack("medkit", 5) })
				expect(InventoryService:hasItem(1, "medkit", 5)).to.equal(true)
				expect(InventoryService:hasItem(1, "medkit", 6)).to.equal(false)
			end)

			it("counts unique instances (not a quantity field) for a non-stackable itemType", function()
				seed(1, { unique("wrench", "1_1"), unique("wrench", "1_2") })
				expect(InventoryService:hasItem(1, "wrench", 2)).to.equal(true)
				expect(InventoryService:hasItem(1, "wrench", 3)).to.equal(false)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("addItem — stackable", function()
			it("merges into an existing stack", function()
				local profile = seed(1, { stack("medkit", 4) })
				local ok = InventoryService:addItem(1, "medkit", 3)
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(1)
				expect(items[1].quantity).to.equal(7)
			end)

			it("spills the overflow into a second stack once the first is full", function()
				-- medkit stackMax is 10: 9 held, +5 requested -> 1 tops up the first stack to
				-- 10, the remaining 4 opens a new stack.
				local profile = seed(1, { stack("medkit", 9) })
				local ok = InventoryService:addItem(1, "medkit", 5)
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(2)
				expect(items[1].quantity).to.equal(10)
				expect(items[2].quantity).to.equal(4)
			end)

			it("refuses when count exceeds remaining stack space, leaving the inventory untouched", function()
				-- flare: stackMax 10, maxStacks 1. One full stack already holds the single
				-- allowed stack, so even 1 more can't merge (full) or spill (maxStacks reached).
				local profile = seed(1, { stack("flare", 10) })
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)

				local ok, reason = InventoryService:addItem(1, "flare", 1)

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("refuses at the kind cap, leaving the inventory untouched", function()
				-- misc's KIND_CAPS is 40. Seed exactly 40 full "scrap" stacks (misc, stackMax 30, no
				-- maxStacks) so every existing stack is full AND the kind is already at its cap — no
				-- merge is possible and no new stack fits.
				local items: { PlayerDataTypes.InventoryEntry } = {}
				for _ = 1, 40 do
					table.insert(items, stack("scrap", 30))
				end
				local profile = seed(1, items)
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)

				local ok, reason = InventoryService:addItem(1, "scrap", 5)

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				-- The profile IS loaded here — the write failed because planStackPlacement refused it
				-- (kind cap), not because no profile exists. Asserting the reason is NOT the
				-- no-profile-loaded message is what proves addStackable distinguishes the two causes
				-- instead of defaulting every mutate() failure to "no profile loaded".
				expect(reason).never.to.equal("no profile loaded for userId 1")
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("returns a specific no-profile reason when unloaded (not a validator/kind-cap guess)", function()
				local ok, reason = InventoryService:addItem(999, "medkit", 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)

			it("defaults count to 1 when omitted", function()
				local profile = seed(1, {})
				local ok = InventoryService:addItem(1, "medkit")
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).inventory.items[1].quantity).to.equal(1)
			end)

			it("refuses an unregistered itemType with a reason", function()
				seed(1, {})
				local ok, reason = InventoryService:addItem(1, "not-a-real-item", 1)
				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("addItem — unique (atomic mint)", function()
			it("mints sequential, account-scoped uids", function()
				local profile = seed(1, {})
				InventoryService:addItem(1, "wrench", 1)
				expect(activeSlotOf(profile).inventory.items[1].uid).to.equal("1_1")
			end)

			it("mints `count` distinct uids in one call", function()
				local profile = seed(1, {})
				local ok = InventoryService:addItem(1, "wrench", 2)
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(2)
				expect(items[1].uid).to.equal("1_1")
				expect(items[2].uid).to.equal("1_2")
			end)

			it("rolls back BOTH the mint counter and the inventory write on a kind-cap breach", function()
				-- tool's KIND_CAPS is 30. Seed exactly 30 unique tool entries (kind already at
				-- cap) so the inventory op's insert pushes it to 31 and validateInventory rejects —
				-- the transaction must roll back the itemMint op too, so nextUid never advances for
				-- an entry that was never actually added.
				local items: { PlayerDataTypes.InventoryEntry } = {}
				for i = 1, 30 do
					table.insert(items, unique("wrench", `seed_{i}`))
				end
				local profile = seed(1, items, 5)

				local ok, reason = InventoryService:addItem(1, "wrench", 1)

				expect(ok).to.equal(false)
				-- This is the data-layer validator's rejection (validateInventory's kind-cap check),
				-- not addUnique's own business logic (addUnique deliberately sets no upvalue reason —
				-- see its header) — so the reason should be the validator's real message, not the
				-- generic fallback.
				assert(reason, "checked above")
				expect(reason:find("exceeds KIND_CAPS", 1, true)).to.be.ok()
				expect(reason:find('kind "tool"', 1, true)).to.be.ok()
				expect(profile.Data.account.itemMint.nextUid).to.equal(5)
				expect(#activeSlotOf(profile).inventory.items).to.equal(30)
			end)

			itMultiSlot("keeps uids unique across a character-slot switch (account-wide counter)", function()
				local profile = seed(1, {})

				InventoryService:addItem(1, "wrench", 1)
				expect(activeSlotOf(profile).inventory.items[1].uid).to.equal("1_1")

				-- Switch the active character directly (same technique PlayerDataServiceServer.spec
				-- uses): bump `active` AND `epoch` together.
				profile.Data.slotState.active = 2
				profile.Data.slotState.epoch += 1

				InventoryService:addItem(1, "wrench", 1)
				local slot2Items = profile.Data.slots[2].inventory.items
				expect(#slot2Items).to.equal(1)
				expect(slot2Items[1].uid).to.equal("1_2")

				-- Slot 1's entry is untouched and no uid repeats across the two slots.
				expect(profile.Data.slots[1].inventory.items[1].uid).to.equal("1_1")
			end)

			it("returns a specific no-profile reason (not the generic mint-rejection message) when unloaded", function()
				local ok, reason = InventoryService:addItem(999, "wrench", 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)
		end)

		describe("addItem — attrs", function()
			it("stamps attrs onto every minted unique copy, each copy holding its own table", function()
				local profile = seed(1, {})
				local attrs = { level = 3, nickname = "Old Faithful" }
				local ok = InventoryService:addItem(1, "wrench", 2, attrs)
				expect(ok).to.equal(true)

				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(2)
				local first = items[1] :: PlayerDataTypes.UniqueEntry
				local second = items[2] :: PlayerDataTypes.UniqueEntry
				local firstAttrs = first.attrs
				local secondAttrs = second.attrs
				assert(firstAttrs, "first copy carries attrs")
				assert(secondAttrs, "second copy carries attrs")
				expect(firstAttrs.level).to.equal(3)
				expect(firstAttrs.nickname).to.equal("Old Faithful")
				expect(secondAttrs.level).to.equal(3)
				expect(secondAttrs.nickname).to.equal("Old Faithful")
				-- No aliasing: neither between the two copies nor with the caller's table.
				expect(firstAttrs).never.to.equal(secondAttrs)
				expect(firstAttrs).never.to.equal(attrs)
				expect(secondAttrs).never.to.equal(attrs)
			end)

			it("mints a unique copy with no attrs field when attrs is omitted", function()
				local profile = seed(1, {})
				local ok = InventoryService:addItem(1, "wrench", 1)
				expect(ok).to.equal(true)
				local entry = activeSlotOf(profile).inventory.items[1] :: PlayerDataTypes.UniqueEntry
				expect(entry.attrs).to.equal(nil)
			end)

			it("refuses attrs on a stackable itemType, leaving the inventory untouched", function()
				local profile = seed(1, { stack("medkit", 4) })
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)

				local ok, reason = InventoryService:addItem(1, "medkit", 1, { level = 1 })

				expect(ok).to.equal(false)
				assert(reason, "checked above")
				expect(reason:find("stackable", 1, true)).to.be.ok()
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("refuses invalid attrs before minting (no entry added, nextUid unchanged)", function()
				local profile = seed(1, {}, 5)

				local ok, reason = InventoryService:addItem(1, "wrench", 1, { level = true :: any })

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
				expect(profile.Data.account.itemMint.nextUid).to.equal(5)
			end)

			it("refuses an over-long string attr before minting", function()
				local profile = seed(1, {}, 5)

				local ok = InventoryService:addItem(1, "wrench", 1, { nickname = string.rep("a", 65) })

				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
				expect(profile.Data.account.itemMint.nextUid).to.equal(5)
			end)

			it("tolerates a pre-existing entry carrying an unknown attr key (validator leniency)", function()
				local tool = unique("wrench", "old_1") :: PlayerDataTypes.UniqueEntry
				tool.attrs = { ["retired-attr"] = 3 }
				seed(1, { tool })
				-- A benign add re-runs validateInventory over the whole slice; the unknown key must pass.
				local ok = InventoryService:addItem(1, "scrap", 1)
				expect(ok).to.equal(true)
			end)

			it("rejects a write while an entry's attr value is neither a number nor a string", function()
				local tool = unique("wrench", "bad_1") :: PlayerDataTypes.UniqueEntry
				tool.attrs = { level = true :: any }
				seed(1, { tool })
				-- Any mutation re-validates the whole slice; the malformed attr must fail it.
				local ok = InventoryService:addItem(1, "scrap", 1)
				expect(ok).to.equal(false)
			end)

			it("rejects a write while an entry's string attr is longer than 64 characters", function()
				local tool = unique("wrench", "bad_1") :: PlayerDataTypes.UniqueEntry
				tool.attrs = { nickname = string.rep("a", 65) }
				seed(1, { tool })
				local ok = InventoryService:addItem(1, "scrap", 1)
				expect(ok).to.equal(false)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("removeItem", function()
			it("removes exactly the instance identified by uid", function()
				local profile = seed(1, { unique("wrench", "a"), unique("wrench", "b") })
				local ok = InventoryService:removeItem(1, { uid = "a" })
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(1)
				expect(items[1].uid).to.equal("b")
			end)

			it("refuses (unchanged) when the uid is not found", function()
				local profile = seed(1, { unique("wrench", "a") })
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)
				local ok, reason = InventoryService:removeItem(1, { uid = "missing" })
				expect(ok).to.equal(false)
				-- The profile IS loaded — the refusal is "no item with that uid", not a missing
				-- profile. Proves removeByUid's up-front profile check doesn't paper over a real
				-- "uid not found" refusal with the wrong reason.
				expect(reason).never.to.equal("no profile loaded for userId 1")
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("returns a specific no-profile reason when removing by uid on an unloaded profile", function()
				local ok, reason = InventoryService:removeItem(999, { uid = "a" })
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)

			it("partially decrements a single stack", function()
				local profile = seed(1, { stack("medkit", 10) })
				local ok = InventoryService:removeItem(1, { itemType = "medkit", quantity = 3 })
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).inventory.items[1].quantity).to.equal(7)
			end)

			it("consumes across multiple stacks, fully draining earlier ones", function()
				local profile = seed(1, { stack("scrap", 20), stack("scrap", 15) })
				local ok = InventoryService:removeItem(1, { itemType = "scrap", quantity = 30 })
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				-- Walked from the end: the second stack (15) is fully consumed first, then 15 more
				-- comes off the first stack (20 -> 5).
				expect(#items).to.equal(1)
				expect(items[1].quantity).to.equal(5)
			end)

			it("refuses (unchanged) when the held quantity is insufficient", function()
				local profile = seed(1, { stack("scrap", 5) })
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)
				local ok, reason = InventoryService:removeItem(1, { itemType = "scrap", quantity = 10 })
				expect(ok).to.equal(false)
				-- The profile IS loaded — the refusal is "insufficient quantity", not a missing
				-- profile. Proves removeByTypeAndQuantity's up-front profile check doesn't paper over a
				-- real insufficient-quantity refusal with the wrong reason.
				expect(reason).never.to.equal("no profile loaded for userId 1")
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("returns a specific no-profile reason when removing by type/quantity on an unloaded profile", function()
				local ok, reason = InventoryService:removeItem(999, { itemType = "scrap", quantity = 1 })
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)
		end)

		-- ---------------------------------------------------------------------
		describeMultiSlot("slot isolation", function()
			it("adding to the active slot never touches another slot's inventory", function()
				local profile = seed(1, {})
				InventoryService:addItem(1, "scrap", 5)
				expect(#activeSlotOf(profile).inventory.items).to.equal(1)
				expect(#profile.Data.slots[2].inventory.items).to.equal(0)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("inventoryOp", function()
			it("mints a transaction operation targeting the active slot's inventory path", function()
				seed(7, {})
				local mutator = function(inv: any)
					table.insert(inv.items, stack("scrap", 1))
					return true
				end
				local op = InventoryService:inventoryOp(7, mutator)
				expect(op.userId).to.equal(7)
				expect(op.path).to.equal(PlayerDataPathUtils.forSlot("inventory", 1))
				expect(op.mutator).to.equal(mutator)
				expect(op.epoch).to.equal(1)
			end)

			it("is pure packaging — the mutator does not run when the op is minted", function()
				local profile = seed(7, {})
				InventoryService:inventoryOp(7, function(inv: any)
					table.insert(inv.items, stack("scrap", 1))
					return true
				end)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("throws when the profile is not loaded", function()
				expect(function()
					InventoryService:inventoryOp(999, function()
						return true
					end)
				end).to.throw()
			end)

			it("throws for a non-number userId", function()
				seed(7, {})
				expect(function()
					InventoryService:inventoryOp("bad" :: any, function()
						return true
					end)
				end).to.throw()
			end)
		end)
	end)
end
