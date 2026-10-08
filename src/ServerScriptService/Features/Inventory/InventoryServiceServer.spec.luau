--!strict
--[=[
	Unit tests for InventoryServiceServer.

	Mock strategy: UNLIKE the sibling domain specs (CurrencyServiceServer.spec,
	StatServiceServer.spec), which mock PlayerDataService's read/write surface, this spec seeds REAL
	fake profiles through PlayerDataService's `_setProfileForTesting` seam (the same strategy
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
local ItemAffixConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemAffixConstants)
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
			currency = { jaku = 100 },
			inventory = { items = {} },
			stats = { totalXp = 0, investments = {} },
			equipment = { slots = {} },
			appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} },
			equippedTitle = {},
		}
	end
	slots[1].inventory = { items = items or {} }
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			unlockedSlots = { 1 },
			itemMint = { nextUid = nextUid or 1 },
			entitlements = { cosmetics = {} },
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
				seed(1, { stack("healing-tonic", 5) })
				local inv = InventoryService:getInventory(1)
				expect(inv).to.be.ok()
				assert(inv, "checked above")
				expect(#inv.items).to.equal(1)
				expect(inv.items[1].itemType).to.equal("healing-tonic")
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
				seed(1, { stack("healing-tonic", 10) })
				expect(InventoryService:hasItem(1, "healing-tonic")).to.equal(true)
			end)

			it("returns false when the item is missing", function()
				seed(1, {})
				expect(InventoryService:hasItem(1, "healing-tonic")).to.equal(false)
			end)

			it("returns true/false around a required quantity", function()
				seed(1, { stack("healing-tonic", 5) })
				expect(InventoryService:hasItem(1, "healing-tonic", 5)).to.equal(true)
				expect(InventoryService:hasItem(1, "healing-tonic", 6)).to.equal(false)
			end)

			it("counts unique instances (not a quantity field) for a non-stackable itemType", function()
				seed(1, { unique("rusted-saw", "1_1"), unique("rusted-saw", "1_2") })
				expect(InventoryService:hasItem(1, "rusted-saw", 2)).to.equal(true)
				expect(InventoryService:hasItem(1, "rusted-saw", 3)).to.equal(false)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("addItem — stackable", function()
			it("merges into an existing stack", function()
				local profile = seed(1, { stack("healing-tonic", 4) })
				local ok = InventoryService:addItem(1, "healing-tonic", 3)
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(1)
				expect(items[1].quantity).to.equal(7)
			end)

			it("spills the overflow into a second stack once the first is full", function()
				-- healing-tonic stackMax is 10: 9 held, +5 requested -> 1 tops up the first stack to
				-- 10, the remaining 4 opens a new stack.
				local profile = seed(1, { stack("healing-tonic", 9) })
				local ok = InventoryService:addItem(1, "healing-tonic", 5)
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(2)
				expect(items[1].quantity).to.equal(10)
				expect(items[2].quantity).to.equal(4)
			end)

			it("refuses when count exceeds remaining stack space, leaving the inventory untouched", function()
				-- throwing-knife: stackMax 10, maxStacks 1. One full stack already holds the single
				-- allowed stack, so even 1 more can't merge (full) or spill (maxStacks reached).
				local profile = seed(1, { stack("throwing-knife", 10) })
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)

				local ok, reason = InventoryService:addItem(1, "throwing-knife", 1)

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("refuses at the kind cap, leaving the inventory untouched", function()
				-- misc's KIND_CAPS is 40. Seed exactly 40 full "wood" stacks (misc, stackMax 30, no
				-- maxStacks) so every existing stack is full AND the kind is already at its cap — no
				-- merge is possible and no new stack fits.
				local items: { PlayerDataTypes.InventoryEntry } = {}
				for _ = 1, 40 do
					table.insert(items, stack("wood", 30))
				end
				local profile = seed(1, items)
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)

				local ok, reason = InventoryService:addItem(1, "wood", 5)

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
				local ok, reason = InventoryService:addItem(999, "healing-tonic", 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)

			it("defaults count to 1 when omitted", function()
				local profile = seed(1, {})
				local ok = InventoryService:addItem(1, "healing-tonic")
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
				InventoryService:addItem(1, "rusted-saw", 1)
				expect(activeSlotOf(profile).inventory.items[1].uid).to.equal("1_1")
			end)

			it("mints `count` distinct uids in one call", function()
				local profile = seed(1, {})
				local ok = InventoryService:addItem(1, "rusted-saw", 2)
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(2)
				expect(items[1].uid).to.equal("1_1")
				expect(items[2].uid).to.equal("1_2")
			end)

			it("rolls back BOTH the mint counter and the inventory write on a kind-cap breach", function()
				-- weapon's KIND_CAPS is 30. Seed exactly 30 unique weapon entries (kind already at
				-- cap) so the inventory op's insert pushes it to 31 and validateInventory rejects —
				-- the transaction must roll back the itemMint op too, so nextUid never advances for
				-- an entry that was never actually added.
				local items: { PlayerDataTypes.InventoryEntry } = {}
				for i = 1, 30 do
					table.insert(items, unique("rusted-saw", `seed_{i}`))
				end
				local profile = seed(1, items, 5)

				local ok, reason = InventoryService:addItem(1, "rusted-saw", 1)

				expect(ok).to.equal(false)
				-- This is the data-layer validator's rejection (validateInventory's kind-cap check),
				-- not addUnique's own business logic (addUnique deliberately sets no upvalue reason —
				-- see its header) — so the reason should be the validator's real message, not the
				-- generic fallback.
				assert(reason, "checked above")
				expect(reason:find("exceeds KIND_CAPS", 1, true)).to.be.ok()
				expect(reason:find('kind "weapon"', 1, true)).to.be.ok()
				expect(profile.Data.account.itemMint.nextUid).to.equal(5)
				expect(#activeSlotOf(profile).inventory.items).to.equal(30)
			end)

			it("keeps uids unique across a character-slot switch (account-wide counter)", function()
				local profile = seed(1, {})

				InventoryService:addItem(1, "rusted-saw", 1)
				expect(activeSlotOf(profile).inventory.items[1].uid).to.equal("1_1")

				-- Switch the active character directly (bypassing SlotService, same technique
				-- PlayerDataServiceServer.spec uses): bump `active` AND `epoch` together.
				profile.Data.slotState.active = 2
				profile.Data.slotState.epoch += 1

				InventoryService:addItem(1, "rusted-saw", 1)
				local slot2Items = profile.Data.slots[2].inventory.items
				expect(#slot2Items).to.equal(1)
				expect(slot2Items[1].uid).to.equal("1_2")

				-- Slot 1's entry is untouched and no uid repeats across the two slots.
				expect(profile.Data.slots[1].inventory.items[1].uid).to.equal("1_1")
			end)

			it("returns a specific no-profile reason (not the generic mint-rejection message) when unloaded", function()
				local ok, reason = InventoryService:addItem(999, "rusted-saw", 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)
		end)

		describe("addItem — affix rolling", function()
			it("rolls a well-formed single affix onto minted weapon AND armour copies", function()
				-- Flat 0.30 chance, rarity-independent. Over 40 mints (weapon + armour) P(zero hits)
				-- ≈ 0.7^40 ≈ 6e-7, so at least one copy carries a well-formed single affix. Uses the live
				-- module RNG (the roller's exact-rate + common-also-rolls behaviour is covered
				-- deterministically in ItemAffixFormulas.spec). ItemAffixConstants.get resolves affixes of either kind.
				local profile = seed(1, {})
				InventoryService:addItem(1, "phoenix-blade", 20) -- weapon
				InventoryService:addItem(1, "chambered-helmet", 20) -- armour

				local withAffix = 0
				for _, entry in activeSlotOf(profile).inventory.items do
					local uniqueEntry = entry :: PlayerDataTypes.UniqueEntry
					if uniqueEntry.affixes then
						local count = 0
						for affixId, value in uniqueEntry.affixes do
							count += 1
							local def = ItemAffixConstants.get(affixId)
							expect(def).to.be.ok()
							expect(value >= def.min and value <= def.max).to.equal(true)
						end
						expect(count).to.equal(1)
						withAffix += 1
					end
				end
				expect(withAffix > 0).to.equal(true)
			end)

			it("tolerates a pre-existing entry carrying a retired affix id (validator leniency)", function()
				local weapon = unique("rusted-saw", "old_1") :: PlayerDataTypes.UniqueEntry
				weapon.affixes = { ["retired-affix"] = 3 }
				seed(1, { weapon })
				-- A benign add re-runs validateInventory over the whole slice; the retired affix must pass.
				local ok = InventoryService:addItem(1, "wood", 1)
				expect(ok).to.equal(true)
			end)

			it("rejects an entry whose affix value is not a number", function()
				local weapon = unique("rusted-saw", "bad_1") :: PlayerDataTypes.UniqueEntry
				weapon.affixes = { warriors = "big" :: any }
				seed(1, { weapon })
				-- Any mutation re-validates the whole slice; the malformed affix must fail it.
				local ok = InventoryService:addItem(1, "wood", 1)
				expect(ok).to.equal(false)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("removeItem", function()
			it("removes exactly the instance identified by uid", function()
				local profile = seed(1, { unique("rusted-saw", "a"), unique("rusted-saw", "b") })
				local ok = InventoryService:removeItem(1, { uid = "a" })
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(1)
				expect(items[1].uid).to.equal("b")
			end)

			it("refuses (unchanged) when the uid is not found", function()
				local profile = seed(1, { unique("rusted-saw", "a") })
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
				local profile = seed(1, { stack("healing-tonic", 10) })
				local ok = InventoryService:removeItem(1, { itemType = "healing-tonic", quantity = 3 })
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).inventory.items[1].quantity).to.equal(7)
			end)

			it("consumes across multiple stacks, fully draining earlier ones", function()
				local profile = seed(1, { stack("wood", 20), stack("wood", 15) })
				local ok = InventoryService:removeItem(1, { itemType = "wood", quantity = 30 })
				expect(ok).to.equal(true)
				local items = activeSlotOf(profile).inventory.items
				-- Walked from the end: the second stack (15) is fully consumed first, then 15 more
				-- comes off the first stack (20 -> 5).
				expect(#items).to.equal(1)
				expect(items[1].quantity).to.equal(5)
			end)

			it("refuses (unchanged) when the held quantity is insufficient", function()
				local profile = seed(1, { stack("wood", 5) })
				local before = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)
				local ok, reason = InventoryService:removeItem(1, { itemType = "wood", quantity = 10 })
				expect(ok).to.equal(false)
				-- The profile IS loaded — the refusal is "insufficient quantity", not a missing
				-- profile. Proves removeByTypeAndQuantity's up-front profile check doesn't paper over a
				-- real insufficient-quantity refusal with the wrong reason.
				expect(reason).never.to.equal("no profile loaded for userId 1")
				expect(deepEqual(activeSlotOf(profile).inventory.items, before)).to.equal(true)
			end)

			it("returns a specific no-profile reason when removing by type/quantity on an unloaded profile", function()
				local ok, reason = InventoryService:removeItem(999, { itemType = "wood", quantity = 1 })
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("slot isolation", function()
			it("adding to the active slot never touches another slot's inventory", function()
				local profile = seed(1, {})
				InventoryService:addItem(1, "wood", 5)
				expect(#activeSlotOf(profile).inventory.items).to.equal(1)
				expect(#profile.Data.slots[2].inventory.items).to.equal(0)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("inventoryOp", function()
			it("mints a transaction operation targeting the active slot's inventory path", function()
				seed(7, {})
				local mutator = function(inv: any)
					table.insert(inv.items, stack("wood", 1))
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
					table.insert(inv.items, stack("wood", 1))
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
