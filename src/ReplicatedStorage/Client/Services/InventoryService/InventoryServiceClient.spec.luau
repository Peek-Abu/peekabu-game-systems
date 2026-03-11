--!strict
--[=[
	Unit tests for InventoryServiceClient.

	Mock strategy: patch PlayerDataServiceClient.getProfile/.mutate and capture the
	InventoryDelta / InventoryBatchDelta handlers via the packets' `.listen`. Item types
	must be real (GameItems.init runs before the suite), so we use "iron-sword" (stackable)
	and "phoenix-blade" (unique).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServiceClient = require(ReplicatedStorage.Client.Services.PlayerDataService.PlayerDataServiceClient)
local InventoryServiceClient = require(ReplicatedStorage.Client.Services.InventoryService.InventoryServiceClient)
local InventoryEvents = require(ReplicatedStorage.Shared.Events.InventoryEvents)
local InventorySignals = require(ReplicatedStorage.Client.Signals.InventorySignals)

return function()
	describe("InventoryServiceClient", function()
		local fakeProfile: any
		local origGetProfile
		local origMutate

		beforeAll(function()
			origGetProfile = PlayerDataServiceClient.getProfile
			origMutate = PlayerDataServiceClient.mutate

			PlayerDataServiceClient.getProfile = function(_self: any)
				return fakeProfile
			end
			PlayerDataServiceClient.mutate = function(
				_self: any,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				if not fakeProfile then
					return false
				end
				local data = fakeProfile[path]
				if data == nil then
					return false
				end
				return mutator(data) ~= false
			end
		end)

		afterAll(function()
			PlayerDataServiceClient.getProfile = origGetProfile
			PlayerDataServiceClient.mutate = origMutate
		end)

		beforeEach(function()
			fakeProfile = { currency = { gold = 0, gems = 0 }, inventory = {} }
		end)

		-- ---------------------------------------------------------------------
		describe("getInventory", function()
			it("returns the inventory array when a profile is loaded", function()
				fakeProfile.inventory = { { itemType = "iron-sword", quantity = 3 } }
				local inv = InventoryServiceClient:getInventory()
				expect(#inv).to.equal(1)
				expect(inv[1].itemType).to.equal("iron-sword")
			end)

			it("returns an empty table when no profile is loaded", function()
				fakeProfile = nil
				local inv = InventoryServiceClient:getInventory()
				expect(type(inv)).to.equal("table")
				expect(#inv).to.equal(0)
			end)
		end)

		-- ---------------------------------------------------------------------
		describe("delta sync (init)", function()
			local deltaHandler: ((any) -> ())?
			local batchHandler: ((any) -> ())?
			local origDeltaListen
			local origBatchListen

			beforeEach(function()
				deltaHandler = nil
				batchHandler = nil
				origDeltaListen = InventoryEvents.packets.InventoryDelta.listen
				origBatchListen = InventoryEvents.packets.InventoryBatchDelta.listen

				InventoryEvents.packets.InventoryDelta.listen = function(handler)
					deltaHandler = handler
					return function() end
				end
				InventoryEvents.packets.InventoryBatchDelta.listen = function(handler)
					batchHandler = handler
					return function() end
				end

				InventoryServiceClient.init(InventoryServiceClient)
			end)

			afterEach(function()
				InventoryEvents.packets.InventoryDelta.listen = origDeltaListen
				InventoryEvents.packets.InventoryBatchDelta.listen = origBatchListen
				InventoryServiceClient.stop(InventoryServiceClient)
			end)

			it("registers delta and batch listeners", function()
				expect(deltaHandler).to.be.a("function")
				expect(batchHandler).to.be.a("function")
			end)

			it("applies an 'add' delta and fires InventorySignals.Changed", function()
				local firedAction, firedItem
				local conn = InventorySignals.Changed:Connect(function(action, item)
					firedAction, firedItem = action, item
				end)

				local handler = assert(deltaHandler, "delta handler was not captured")
				handler({ action = "add", item = { itemType = "iron-sword", quantity = 2 } })

				-- SignalPlus fires connections via task.defer; yield once so the connection runs.
				task.wait()
				conn:Disconnect()

				expect(#fakeProfile.inventory).to.equal(1)
				expect(fakeProfile.inventory[1].itemType).to.equal("iron-sword")
				expect(firedAction).to.equal("add")
				expect(firedItem.itemType).to.equal("iron-sword")
			end)

			it("applies a 'remove' delta", function()
				fakeProfile.inventory = { { itemType = "phoenix-blade", instanceId = "i1" } }
				local handler = assert(deltaHandler, "delta handler was not captured")
				handler({ action = "remove", item = { itemType = "phoenix-blade", instanceId = "i1" } })
				expect(#fakeProfile.inventory).to.equal(0)
			end)

			it("applies a batch delta (added + removed)", function()
				fakeProfile.inventory = { { itemType = "iron-sword", quantity = 5 } }
				local handler = assert(batchHandler, "batch handler was not captured")
				handler({
					added = { { itemType = "phoenix-blade", instanceId = "i2" } },
					removed = { { itemType = "iron-sword", quantity = 5 } },
					updated = {},
				})
				-- iron-sword removed (full entry), phoenix-blade added
				expect(#fakeProfile.inventory).to.equal(1)
				expect(fakeProfile.inventory[1].itemType).to.equal("phoenix-blade")
			end)
		end)
	end)
end
