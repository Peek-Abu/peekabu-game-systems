--!strict
--[=[
	Unit tests for EquipmentServiceClient — a thin read-facade over StateSyncClientStore.equipment.
	Seeds the atom directly and asserts the accessors read it. Replication is covered by the
	StateSync/StateSyncClientStore specs.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentServiceClient = require(ReplicatedStorage.Client.Features.Equipment.EquipmentServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)

return function()
	describe("EquipmentServiceClient", function()
		beforeAll(function()
			-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM. getState's
			-- aggregatedBonuses field folds in equipped items' statBonuses via EquipmentBonusFormulas.
			ItemContentRegistry.init()
		end)

		afterEach(function()
			StateSyncClientStore.equipment({ slots = {} }) -- restore the empty default for other specs
		end)

		describe("getEquipment", function()
			it("returns the equipment wrapper from the store", function()
				StateSyncClientStore.equipment({ slots = { helmet = { itemType = "chambered-helmet", uid = "u1" } } })
				local equipment = EquipmentServiceClient:getEquipment()
				expect(equipment.slots.helmet.itemType).to.equal("chambered-helmet")
			end)

			it("returns an empty slots table before the first sync", function()
				StateSyncClientStore.equipment({ slots = {} })
				local equipment = EquipmentServiceClient:getEquipment()
				expect(type(equipment.slots)).to.equal("table")
				expect(next(equipment.slots)).to.equal(nil)
			end)
		end)

		describe("getEquippedInSlot", function()
			it("returns the entry occupying the given slot", function()
				StateSyncClientStore.equipment({ slots = { helmet = { itemType = "chambered-helmet", uid = "u1" } } })
				local entry = EquipmentServiceClient:getEquippedInSlot("helmet")
				expect(entry).to.be.ok()
				expect(entry.itemType).to.equal("chambered-helmet")
			end)

			it("returns nil for an empty slot", function()
				StateSyncClientStore.equipment({ slots = { helmet = { itemType = "chambered-helmet", uid = "u1" } } })
				local entry = EquipmentServiceClient:getEquippedInSlot("weapon")
				expect(entry).to.equal(nil)
			end)
		end)

		describe("getState", function()
			it("reports the equipped itemType per occupied slot and the aggregated bonuses", function()
				StateSyncClientStore.equipment({ slots = { helmet = { itemType = "chambered-helmet", uid = "h1" } } })
				local state = EquipmentServiceClient:getState()
				local equipped = state.equipped :: { [string]: string }
				expect(equipped.helmet).to.equal("chambered-helmet")
				expect(equipped.weapon).to.equal(nil)
				local bonuses = state.aggregatedBonuses :: { [string]: number }
				expect(bonuses.rotEndurance).to.equal(8)
			end)

			it("reports an empty map before the first sync", function()
				StateSyncClientStore.equipment({ slots = {} })
				local state = EquipmentServiceClient:getState()
				local equipped = state.equipped :: { [string]: string }
				expect(next(equipped)).to.equal(nil)
				local bonuses = state.aggregatedBonuses :: { [string]: number }
				expect(next(bonuses)).to.equal(nil)
			end)
		end)
	end)
end
