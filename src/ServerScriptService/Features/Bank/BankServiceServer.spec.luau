--!strict
--[=[
	Unit tests for BankServiceServer. Same strategy as Inventory/Equipment specs: seed REAL fake
	profiles via `_setProfileForTesting` and drive the REAL transaction()/validator machinery — the
	atomicity guarantees (a rejection rolls back BOTH slices) only mean something against it.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local InventoryUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryUtils)
local BankConstants = require(ReplicatedStorage.Shared.Features.Bank.Data.BankConstants)
local sift = require(ReplicatedStorage.Packages.sift)

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

type SeedOpts = {
	items: { PlayerDataTypes.InventoryEntry }?,
	bankItems: { PlayerDataTypes.InventoryEntry }?,
	currency: PlayerDataTypes.Currency?,
	bankCurrency: PlayerDataTypes.Currency?,
}

local function makeProfileData(opts: SeedOpts?): PlayerDataTypes.PlayerProfile
	local o = opts or {}
	local slots: { PlayerDataTypes.PlayerSlot } = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = {},
			inventory = { items = {} },
			stats = { totalXp = 0, investments = {} },
			equipment = { slots = {} },
			appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} },
			bank = { items = {}, currency = {} },
			equippedTitle = {},
		}
	end
	slots[1].inventory = { items = o.items or {} }
	slots[1].bank = { items = o.bankItems or {}, currency = o.bankCurrency or {} }
	slots[1].currency = o.currency or {}
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			unlockedSlots = { 1 },
			itemMint = { nextUid = 1 },
			entitlements = { cosmetics = {} },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

local function activeSlotOf(profile: any): PlayerDataTypes.PlayerSlot
	return profile.Data.slots[profile.Data.slotState.active]
end

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
	describe("BankServiceServer", function()
		local profiles: { [number]: any } = {}

		beforeAll(function()
			ItemContentRegistry.init()
		end)

		afterEach(function()
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			profiles = {}
		end)

		local function seed(userId: number, opts: SeedOpts?)
			local profile = makeFakeProfile(makeProfileData(opts))
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		describe("getBank", function()
			it("returns the empty bank for a fresh profile and nil when unloaded", function()
				seed(1, {})
				local bank = BankService:getBank(1)
				expect(bank).to.be.ok()
				expect(#(bank :: PlayerDataTypes.Bank).items).to.equal(0)
				expect(BankService:getBank(999)).to.equal(nil)
			end)
		end)

		describe("depositItem / withdrawItem — unique", function()
			it("deposits a unique by uid, moving the exact entry out of inventory", function()
				local profile = seed(1, { items = { unique("phoenix-blade", "w1") } })
				local ok = BankService:depositItem(1, { uid = "w1" })
				expect(ok).to.equal(true)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
				local bankItems = activeSlotOf(profile).bank.items
				expect(#bankItems).to.equal(1)
				expect(deepEqual(bankItems[1], unique("phoenix-blade", "w1"))).to.equal(true)
			end)

			it("withdraws a unique back to inventory intact", function()
				local profile = seed(1, { bankItems = { unique("phoenix-blade", "w1") } })
				local ok = BankService:withdrawItem(1, { uid = "w1" })
				expect(ok).to.equal(true)
				expect(#activeSlotOf(profile).bank.items).to.equal(0)
				expect(deepEqual(activeSlotOf(profile).inventory.items[1], unique("phoenix-blade", "w1"))).to.equal(
					true
				)
			end)

			it("refuses depositing a uid the inventory does not hold, nothing moves", function()
				local profile = seed(1, {})
				local ok, reason = BankService:depositItem(1, { uid = "ghost" })
				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(#activeSlotOf(profile).bank.items).to.equal(0)
			end)
		end)

		describe("depositItem / withdrawItem — stackable (whole holding)", function()
			it("deposits the ENTIRE held quantity, collapsing multiple source stacks via merge-then-spill", function()
				local profile = seed(1, {
					items = {
						{ itemType = "wood", quantity = 30 },
						{ itemType = "wood", quantity = 10 },
					},
				})
				local ok = BankService:depositItem(1, { itemType = "wood" })
				expect(ok).to.equal(true)
				expect(InventoryUtils.countOf(activeSlotOf(profile).inventory, "wood")).to.equal(0)
				-- 40 wood at stackMax 30 → 30 + 10 across two bank stacks.
				expect(InventoryUtils.countOf(activeSlotOf(profile).bank :: any, "wood")).to.equal(40)
			end)

			it("refuses moving a unique itemType by itemType (must be by uid)", function()
				seed(1, { items = { unique("phoenix-blade", "w1") } })
				local ok, reason = BankService:depositItem(1, { itemType = "phoenix-blade" })
				expect(ok).to.equal(false)
				expect((reason :: string):find("unique", 1, true)).to.be.ok()
			end)
		end)

		describe("atomicity", function()
			it("refuses a deposit that would breach CAPACITY, leaving BOTH sides unchanged", function()
				local full: { PlayerDataTypes.InventoryEntry } = {}
				for i = 1, BankConstants.CAPACITY do
					table.insert(full, unique("rusted-saw", `b{i}`))
				end
				local profile = seed(1, { items = { unique("phoenix-blade", "extra") }, bankItems = full })

				local itemsBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).inventory.items)
				local bankBefore = sift.Dictionary.copyDeep(activeSlotOf(profile).bank.items)

				local ok, reason = BankService:depositItem(1, { uid = "extra" })
				expect(ok).to.equal(false)
				expect((reason :: string):find("CAPACITY", 1, true)).to.be.ok()
				expect(deepEqual(activeSlotOf(profile).inventory.items, itemsBefore)).to.equal(true)
				expect(deepEqual(activeSlotOf(profile).bank.items, bankBefore)).to.equal(true)
			end)

			it(
				"refuses a withdrawal that would breach inventory's per-kind cap (re-entry through its validator)",
				function()
					-- weapon KIND_CAP is 30. Fill inventory with 30 weapons, bank holds one more weapon.
					local invWeapons: { PlayerDataTypes.InventoryEntry } = {}
					for i = 1, 30 do
						table.insert(invWeapons, unique("rusted-saw", `inv{i}`))
					end
					local profile = seed(1, { items = invWeapons, bankItems = { unique("phoenix-blade", "b1") } })

					local ok = BankService:withdrawItem(1, { uid = "b1" })
					expect(ok).to.equal(false)
					-- Nothing moved: bank still holds it, inventory still at 30.
					expect(#activeSlotOf(profile).bank.items).to.equal(1)
					expect(#activeSlotOf(profile).inventory.items).to.equal(30)
				end
			)
		end)

		describe("currency", function()
			it("deposits currency, moving it from the slot balance into the bank", function()
				local profile = seed(1, { currency = { jaku = 500 } })
				local ok = BankService:depositCurrency(1, "jaku", 200)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.jaku).to.equal(300)
				expect(activeSlotOf(profile).bank.currency.jaku).to.equal(200)
			end)

			it("withdraws currency back to the slot balance", function()
				local profile = seed(1, { bankCurrency = { jaku = 200 } })
				local ok = BankService:withdrawCurrency(1, "jaku", 150)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).bank.currency.jaku).to.equal(50)
				expect(activeSlotOf(profile).currency.jaku).to.equal(150)
			end)

			it("refuses depositing more currency than the slot holds, nothing moves", function()
				local profile = seed(1, { currency = { jaku = 100 } })
				local ok, reason = BankService:depositCurrency(1, "jaku", 250)
				expect(ok).to.equal(false)
				expect((reason :: string):find("insufficient", 1, true)).to.be.ok()
				expect(activeSlotOf(profile).currency.jaku).to.equal(100)
				expect(activeSlotOf(profile).bank.currency.jaku).to.equal(nil)
			end)
		end)

		describe("slot isolation", function()
			it("depositing on the active slot never touches another character slot's bank", function()
				local profile = seed(1, { items = { unique("phoenix-blade", "w1") } })
				BankService:depositItem(1, { uid = "w1" })
				expect(#profile.Data.slots[2].bank.items).to.equal(0)
			end)
		end)
	end)
end
