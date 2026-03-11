--!strict
--[=[
	Unit tests for InventoryServiceServer.
	
	Mock strategy: patch PlayerDataService methods inside beforeAll/afterAll
	so each spec file owns its mock window and doesn't overwrite other specs.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService =
	require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)
local InventoryService =
	require(ServerScriptService.Services.InventoryService.InventoryServiceServer)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

-- ============================================================
-- Helpers
-- ============================================================
local function makeProfile(inventory: { PlayerDataTypes.InventoryItem }?)
	return {
		currency = { gold = 0, gems = 0 },
		inventory = inventory or {},
	}
end

local function sword(qty: number?): PlayerDataTypes.InventoryItem
	return { itemType = "iron-sword", quantity = qty or 1 }
end

local function blade(instanceId: string?): PlayerDataTypes.InventoryItem
	return { itemType = "phoenix-blade", instanceId = instanceId or "inst-1" }
end

return function()
	describe("InventoryServiceServer", function()
		local _profiles: { [number]: any } = {}
		local _origGetProfile
		local _origMutate

		beforeAll(function()
			_origGetProfile = PlayerDataService.getProfile
			_origMutate = PlayerDataService.mutate

			PlayerDataService.getProfile = function(_self: any, userId: number)
				return _profiles[userId]
			end

			PlayerDataService.mutate = function(
				_self: any,
				userId: number,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				local profile = _profiles[userId]
				if not profile then
					return false
				end
				local data = (profile :: any)[path]
				if data == nil then
					return false
				end
				local result = mutator(data)
				return result ~= false
			end
		end)

		afterAll(function()
			PlayerDataService.getProfile = _origGetProfile
			PlayerDataService.mutate = _origMutate
		end)

		beforeEach(function()
			_profiles = {}
		end)

		-- -------------------------------------------------------------------------
		describe("getInventory", function()
			it("should return inventory for loaded player", function()
				_profiles[1] = makeProfile({ sword(5) })
				local inv = InventoryService:getInventory(1)
				expect(#inv).to.equal(1)
				expect(inv[1].itemType).to.equal("iron-sword")
			end)

			it("should return empty table when profile is not loaded", function()
				local inv = InventoryService:getInventory(999)
				expect(type(inv)).to.equal("table")
				expect(#inv).to.equal(0)
			end)

			it("should throw for non-number userId", function()
				expect(function()
					InventoryService:getInventory("bad" :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("hasItem", function()
			it("should return true when player has the item", function()
				_profiles[1] = makeProfile({ sword(10) })
				expect(InventoryService:hasItem(1, sword())).to.equal(true)
			end)

			it("should return false when item is missing", function()
				_profiles[1] = makeProfile({})
				expect(InventoryService:hasItem(1, sword())).to.equal(false)
			end)

			it("should return true when player has enough quantity", function()
				_profiles[1] = makeProfile({ sword(10) })
				expect(InventoryService:hasItem(1, sword(), 5)).to.equal(true)
				expect(InventoryService:hasItem(1, sword(), 10)).to.equal(true)
			end)

			it("should return false when quantity is insufficient", function()
				_profiles[1] = makeProfile({ sword(3) })
				expect(InventoryService:hasItem(1, sword(), 10)).to.equal(false)
			end)

			it("should match unique items by instanceId", function()
				_profiles[1] = makeProfile({ blade("inst-abc") })
				expect(InventoryService:hasItem(1, blade("inst-abc"))).to.equal(true)
				expect(InventoryService:hasItem(1, blade("inst-xyz"))).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("addItem", function()
			it("should add a new item to the inventory", function()
				_profiles[1] = makeProfile({})
				local ok = InventoryService:addItem(1, sword(1))
				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(1)
			end)

			it("should stack quantities for existing stackable item", function()
				_profiles[1] = makeProfile({ sword(5) })
				local ok = InventoryService:addItem(1, sword(3))
				expect(ok).to.equal(true)
				expect(_profiles[1].inventory[1].quantity).to.equal(8)
			end)

			it("should reject duplicate unique items", function()
				_profiles[1] = makeProfile({ blade("inst-1") })
				local ok = InventoryService:addItem(1, blade("inst-1"))
				expect(ok).to.equal(false)
				expect(#_profiles[1].inventory).to.equal(1)
			end)

			it("should return false when profile is not loaded", function()
				expect(InventoryService:addItem(999, sword(1))).to.equal(false)
			end)

			it("should throw for item with no itemType", function()
				_profiles[1] = makeProfile({})
				expect(function()
					InventoryService:addItem(1, { quantity = 1 } :: any)
				end).to.throw()
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("addItems (batch)", function()
			it("should add multiple items in one call", function()
				_profiles[1] = makeProfile({})
				local ok = InventoryService:addItems(1, {
					sword(2),
					{ itemType = "phoenix-blade", instanceId = "i1" },
				})
				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(2)
			end)

			it("should return true for empty items list", function()
				_profiles[1] = makeProfile({})
				expect(InventoryService:addItems(1, {})).to.equal(true)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("removeItem", function()
			it("should decrement stackable item quantity", function()
				_profiles[1] = makeProfile({ sword(10) })
				local ok = InventoryService:removeItem(1, sword(), 3)
				expect(ok).to.equal(true)
				expect(_profiles[1].inventory[1].quantity).to.equal(7)
			end)

			it("should fully remove item when quantity reaches 0", function()
				_profiles[1] = makeProfile({ sword(5) })
				local ok = InventoryService:removeItem(1, sword(), 5)
				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(0)
			end)

			it("should remove unique item regardless of amount", function()
				_profiles[1] = makeProfile({ blade("inst-1") })
				local ok = InventoryService:removeItem(1, blade("inst-1"), 99)
				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(0)
			end)

			it("should return false when item is not found", function()
				_profiles[1] = makeProfile({})
				expect(InventoryService:removeItem(1, sword(), 1)).to.equal(false)
			end)

			it("should return false when quantity is insufficient", function()
				_profiles[1] = makeProfile({ sword(2) })
				local ok = InventoryService:removeItem(1, sword(), 10)
				expect(ok).to.equal(false)
				expect(_profiles[1].inventory[1].quantity).to.equal(2)
			end)

			it("should return false when profile is not loaded", function()
				expect(InventoryService:removeItem(999, sword(), 1)).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("removeItems (batch)", function()
			it("should remove multiple items in one call", function()
				_profiles[1] = makeProfile({ sword(10), blade("inst-1") })
				local ok = InventoryService:removeItems(1, {
					{ item = sword(), amount = 5 },
					{ item = blade("inst-1"), amount = 1 },
				})
				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(1)
				expect(_profiles[1].inventory[1].quantity).to.equal(5)
			end)

			it("should return true for empty requests list", function()
				_profiles[1] = makeProfile({})
				expect(InventoryService:removeItems(1, {})).to.equal(true)
			end)
		end)
	end)
end
