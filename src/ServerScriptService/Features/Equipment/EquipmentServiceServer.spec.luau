--!strict
--[=[
	Unit tests for EquipmentServiceServer.

	Mock strategy: same as InventoryServiceServer.spec — seed REAL fake profiles through
	PlayerDataService's `_setProfileForTesting` seam and drive the REAL `mutate()`/`transaction()`.
	`equip`/`unequip` compose ops across the equipment AND inventory slices via
	`PlayerDataService:transaction()`, so the atomicity guarantee under test (a rejection rolls back
	EVERY op, not just the one that failed) only means something against the real transaction/validator
	machinery — a spec-local mock would either be unfaithful or duplicate PlayerDataServiceServer's own
	tests.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local EquipmentService = require(ServerScriptService.Features.Equipment.EquipmentServiceServer)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local StatFormulas = require(ReplicatedStorage.Shared.Features.Stat.Utils.StatFormulas)
local sift = require(ReplicatedStorage.Packages.sift)

-- ============================================================
-- Helpers
-- ============================================================

-- Minimal synchronous signal: enough for OnSave Connect/Fire, mirroring
-- InventoryServiceServer.spec's fakeSignal (needed because `_setProfileForTesting` wires an OnSave
-- connection for the auto-save-abort seam).
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
-- ACTIVE slot's inventory/equipment/stats stamped from `opts`.
local function makeProfileData(opts: {
	items: { PlayerDataTypes.InventoryEntry }?,
	equipmentSlots: { [string]: PlayerDataTypes.UniqueEntry }?,
	totalXp: number?,
	nextUid: number?,
}?): PlayerDataTypes.PlayerProfile
	local o = opts or {}
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
	slots[1].inventory = { items = o.items or {} }
	slots[1].equipment = { slots = o.equipmentSlots or {} }
	slots[1].stats = { totalXp = o.totalXp or 0, investments = {} }
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			unlockedSlots = { 1 },
			itemMint = { nextUid = o.nextUid or 1 },
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

-- Recursive structural equality over plain data tables — used for the "refused, and X is unchanged"
-- assertions, which must catch ANY drift, not just a count. Mirrors InventoryServiceServer.spec's
-- deepEqual.
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

local function unique(itemType: string, uid: string): PlayerDataTypes.UniqueEntry
	return { itemType = itemType, uid = uid }
end

return function()
	describe("EquipmentServiceServer", function()
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

		local function seed(
			userId: number,
			opts: {
				items: { PlayerDataTypes.InventoryEntry }?,
				equipmentSlots: { [string]: PlayerDataTypes.UniqueEntry }?,
				totalXp: number?,
				nextUid: number?,
			}?
		)
			local profile = makeFakeProfile(makeProfileData(opts))
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		-- ---------------------------------------------------------------------
		describe("getEquipment / getAggregatedBonuses — empty and no-profile", function()
			it("returns nil for an unloaded profile", function()
				expect(EquipmentService:getEquipment(999)).to.equal(nil)
			end)

			it("returns the empty equipment wrapper for a fresh profile", function()
				seed(1)
				local equipment = EquipmentService:getEquipment(1)
				expect(equipment).to.be.ok()
				assert(equipment, "checked above")
				expect(deepEqual(equipment.slots, {})).to.equal(true)
			end)

			-- getAggregatedBonuses reads the COMMITTED StateSyncServerStore mirror of "equipment" — the SAME
			-- source StatServiceServer.getDerived aggregates over (see that service's spec for the
			-- established seeding pattern) — NOT the mocked PlayerDataService profile shape, so these
			-- tests seed StateSyncServerStore directly instead of (or in addition to) the fake profile.
			describe("getAggregatedBonuses — reads the StateSyncServerStore mirror", function()
				beforeEach(function()
					StateSyncServerStore.remove(1)
				end)

				afterEach(function()
					StateSyncServerStore.remove(1)
				end)

				it("returns {} for an unloaded/unmirrored profile", function()
					expect(deepEqual(EquipmentService:getAggregatedBonuses(999), {})).to.equal(true)
				end)

				it("returns {} when nothing is equipped", function()
					StateSyncServerStore.set("equipment", 1, { slots = {} })
					expect(deepEqual(EquipmentService:getAggregatedBonuses(1), {})).to.equal(true)
				end)

				it("sums an equipped item's statBonuses", function()
					StateSyncServerStore.set("equipment", 1, { slots = { helmet = unique("chambered-helmet", "h1") } })
					local bonuses = EquipmentService:getAggregatedBonuses(1)
					expect(deepEqual(bonuses, { rotEndurance = 8 })).to.equal(true)
				end)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("equip — into an empty slot", function()
			it("equips a weapon", function()
				local profile = seed(1, { items = { unique("rusted-saw", "w1") } })
				local ok = EquipmentService:equip(1, "w1")
				expect(ok).to.equal(true)
				local equipment = activeSlotOf(profile).equipment
				expect(equipment.slots.weapon).to.be.ok()
				assert(equipment.slots.weapon, "checked above")
				expect(equipment.slots.weapon.uid).to.equal("w1")
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("equips armour, respecting a met requiredLevel", function()
				local profile = seed(1, {
					items = { unique("chambered-helmet", "h1") },
					totalXp = StatFormulas.xpForLevel(8), -- chambered-helmet's requiredLevel
				})
				local ok = EquipmentService:equip(1, "h1")
				expect(ok).to.equal(true)
				local equipment = activeSlotOf(profile).equipment
				expect(equipment.slots.helmet).to.be.ok()
				assert(equipment.slots.helmet, "checked above")
				expect(equipment.slots.helmet.uid).to.equal("h1")
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("equip — refusals", function()
			it("refuses an unknown uid", function()
				local profile = seed(1, { items = {} })
				local ok, reason = EquipmentService:equip(1, "missing")
				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
				expect(deepEqual(activeSlotOf(profile).equipment.slots, {})).to.equal(true)
			end)

			it("refuses below requiredLevel, leaving inventory AND equipment unchanged", function()
				local profile = seed(1, {
					items = { unique("chambered-helmet", "h1") },
					totalXp = 0, -- level 1
				})
				local itemsBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)
				local equipmentBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).equipment.slots)

				local ok, reason = EquipmentService:equip(1, "h1")

				expect(ok).to.equal(false)
				expect(reason).to.equal(`requires level 8, you are level 1`)
				expect(deepEqual(activeSlotOf(profile).inventory.items, itemsBefore)).to.equal(true)
				expect(deepEqual(activeSlotOf(profile).equipment.slots, equipmentBefore)).to.equal(true)
			end)

			it("the VALIDATOR (not the service-level check) rejects a kind-mismatched slot", function()
				seed(1, {})
				-- Bypasses equip()'s own equipSlot check entirely: a raw op stamps an ARMOUR item into
				-- the WEAPON slot, proving validateEquipment itself is the real backstop.
				local ok = PlayerDataService:transaction({
					EquipmentService:equipmentOp(1, function(equipment)
						equipment.slots.weapon = unique("chambered-helmet", "h1")
						return true
					end),
				})
				expect(ok).to.equal(false)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("validateEquipment — per-instance modifiers", function()
			it("rejects an equipped entry whose affix value is not a number", function()
				seed(1, {})
				-- Raw op stamps a malformed affix straight into a (kind-valid) slot, bypassing equip()'s
				-- own checks — proving validateEquipment itself catches the non-finite modifier value.
				local ok = PlayerDataService:transaction({
					EquipmentService:equipmentOp(1, function(equipment)
						local w = unique("rusted-saw", "w1") :: PlayerDataTypes.UniqueEntry
						w.affixes = { warriors = "big" :: any }
						equipment.slots.weapon = w
						return true
					end),
				})
				expect(ok).to.equal(false)
			end)

			it("tolerates an equipped entry carrying a retired affix id", function()
				seed(1, {})
				local ok = PlayerDataService:transaction({
					EquipmentService:equipmentOp(1, function(equipment)
						local w = unique("rusted-saw", "w1") :: PlayerDataTypes.UniqueEntry
						w.affixes = { ["retired-affix"] = 3 }
						equipment.slots.weapon = w
						return true
					end),
				})
				expect(ok).to.equal(true)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("equip — swap", function()
			it("returns the previously-equipped item to inventory intact", function()
				local profile = seed(1, {
					items = { unique("phoenix-blade", "new-weapon") },
					equipmentSlots = { weapon = unique("rusted-saw", "old-weapon") },
				})

				local ok = EquipmentService:equip(1, "new-weapon")

				expect(ok).to.equal(true)
				local equipment = activeSlotOf(profile).equipment
				assert(equipment.slots.weapon, "checked above")
				expect(equipment.slots.weapon.uid).to.equal("new-weapon")

				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(1)
				expect(deepEqual(items[1], unique("rusted-saw", "old-weapon"))).to.equal(true)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("equip — atomicity", function()
			it("rolls back EVERYTHING when the validator rejects the commit, nothing moves", function()
				-- Pre-corrupt equipment via a raw profile stamp (bypassing the validator entirely, the
				-- same way a raw op would): two slots share the same uid. ANY subsequent write to the
				-- equipment slice — even one aimed at a totally different, clean slot — must now be
				-- rejected by validateEquipment on commit, and per the all-or-nothing guarantee that
				-- rejection must undo the OTHER ops in the same transaction too (the inventory removal),
				-- not just leave the equipment write half-applied.
				local profile = seed(1, {
					items = { unique("rusted-saw", "new-weapon") },
					equipmentSlots = {
						helmet = unique("chambered-helmet", "dup"),
						pauldrons = unique("chambered-helmet", "dup"),
					},
				})
				local itemsBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)
				local equipmentBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).equipment.slots)

				local ok, reason = EquipmentService:equip(1, "new-weapon")

				expect(ok).to.equal(false)
				-- The rejection is validateEquipment's (the data-layer invariant), not equip()'s own
				-- upvalue reason (none of equip's ops abort here — every op returns true; it's the
				-- post-mutator validator that rejects on commit) — so the propagated reason should be
				-- the validator's real "duplicate uid" message, not the generic fallback.
				assert(reason, "checked above")
				expect(reason:find("duplicate uid", 1, true)).to.be.ok()
				expect(deepEqual(activeSlotOf(profile).inventory.items, itemsBefore)).to.equal(true)
				expect(deepEqual(activeSlotOf(profile).equipment.slots, equipmentBefore)).to.equal(true)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("unequip", function()
			it("moves the equipped item back to inventory", function()
				local profile = seed(1, { equipmentSlots = { weapon = unique("rusted-saw", "w1") } })

				local ok = EquipmentService:unequip(1, "weapon")

				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).equipment.slots.weapon).to.equal(nil)
				local items = activeSlotOf(profile).inventory.items
				expect(#items).to.equal(1)
				expect(deepEqual(items[1], unique("rusted-saw", "w1"))).to.equal(true)
			end)

			it("refuses when the bag is already at its kind cap, nothing moves", function()
				local armourItems: { PlayerDataTypes.InventoryEntry } = {}
				for i = 1, 30 do
					table.insert(armourItems, unique("chambered-helmet", `bag_{i}`))
				end
				local profile = seed(1, {
					items = armourItems,
					equipmentSlots = { helmet = unique("chambered-helmet", "equipped-h") },
				})
				local itemsBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)

				local ok, reason = EquipmentService:unequip(1, "helmet")

				expect(ok).to.equal(false)
				expect(reason).to.equal("cannot unequip: armour inventory is at its cap (30)")
				expect(deepEqual(activeSlotOf(profile).inventory.items, itemsBefore)).to.equal(true)
				local equipment = activeSlotOf(profile).equipment
				expect(equipment.slots.helmet).to.be.ok()
				assert(equipment.slots.helmet, "checked above")
				expect(equipment.slots.helmet.uid).to.equal("equipped-h")
			end)

			it("refuses an empty slot", function()
				seed(1, {})
				local ok, reason = EquipmentService:unequip(1, "weapon")
				expect(ok).to.equal(false)
				expect(reason).to.equal(`slot "weapon" is empty`)
			end)

			it("refuses an invalid slot id", function()
				seed(1, {})
				local ok, reason = EquipmentService:unequip(1, "not-a-slot")
				expect(ok).to.equal(false)
				expect(reason).to.equal(`"not-a-slot" is not a valid equipment slot`)
			end)

			it("returns a specific no-profile reason when unloaded", function()
				local ok, reason = EquipmentService:unequip(999, "weapon")
				expect(ok).to.equal(false)
				expect(reason).to.equal("no profile loaded for userId 999")
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("slot isolation", function()
			it("equipping on the active slot never touches another character slot's equipment", function()
				local profile = seed(1, { items = { unique("rusted-saw", "w1") } })
				EquipmentService:equip(1, "w1")
				expect(profile.Data.slots[1].equipment.slots.weapon).to.be.ok()
				expect(deepEqual(profile.Data.slots[2].equipment.slots, {})).to.equal(true)
			end)

			it("switching the active slot isolates subsequent equips to the new slot", function()
				local profile = seed(1, { items = { unique("rusted-saw", "w1") } })
				EquipmentService:equip(1, "w1")

				-- Switch the active character directly (bypassing SlotService, same technique
				-- InventoryServiceServer.spec uses): bump `active` AND `epoch` together.
				profile.Data.slotState.active = 2
				profile.Data.slotState.epoch += 1
				profile.Data.slots[2].inventory = { items = { unique("phoenix-blade", "w2") } }

				EquipmentService:equip(1, "w2")

				expect(profile.Data.slots[2].equipment.slots.weapon).to.be.ok()
				-- Slot 1's equipment is untouched by the slot-2 equip.
				expect(profile.Data.slots[1].equipment.slots.weapon.uid).to.equal("w1")
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("equipmentOp", function()
			it("mints a transaction operation targeting the active slot's equipment path", function()
				seed(7, {})
				local mutator = function(equipment: any)
					equipment.slots.weapon = unique("rusted-saw", "op-test")
					return true
				end
				local op = EquipmentService:equipmentOp(7, mutator)
				expect(op.userId).to.equal(7)
				expect(op.path).to.equal(PlayerDataPathUtils.forSlot("equipment", 1))
				expect(op.mutator).to.equal(mutator)
				expect(op.epoch).to.equal(1)
			end)

			it("is pure packaging — the mutator does not run when the op is minted", function()
				local profile = seed(7, {})
				EquipmentService:equipmentOp(7, function(equipment: any)
					equipment.slots.weapon = unique("rusted-saw", "op-test")
					return true
				end)
				expect(deepEqual(activeSlotOf(profile).equipment.slots, {})).to.equal(true)
			end)

			it("throws when the profile is not loaded", function()
				expect(function()
					EquipmentService:equipmentOp(999, function()
						return true
					end)
				end).to.throw()
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("getState", function()
			it("reports every registered slot's acceptsKind", function()
				local state = EquipmentService:getState()
				local slots = state.slots :: { [string]: string }
				expect(slots.weapon).to.equal("weapon")
				expect(slots.helmet).to.equal("armour")
				expect(slots.pauldrons).to.equal("armour")
				expect(slots.chestplate).to.equal("armour")
				expect(slots.greaves).to.equal("armour")
			end)
		end)
	end)
end
