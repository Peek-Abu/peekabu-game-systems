--!strict
--[=[
	Unit tests for InventoryServiceServer.
	
	Mock strategy: patch PlayerDataService methods inside beforeAll/afterAll
	so each spec file owns its mock window and doesn't overwrite other specs.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)
local InventoryService = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)

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
		local _origGetSliceShell
		local _origMutate

		beforeAll(function()
			_origGetSliceShell = PlayerDataService._getSliceShell
			_origMutate = PlayerDataService.mutate

			-- SliceOwner.get reads through _getSliceShell (the per-slice snapshot path). The mock
			-- mirrors its nil contract (unloaded profile / missing path) and returns the fake profile
			-- directly — the reader projects the slice out of it, same as production.
			PlayerDataService._getSliceShell = function(_self: any, userId: number, path: string)
				local profile = _profiles[userId]
				if not profile or (profile :: any)[path] == nil then
					return nil
				end
				return profile
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
			PlayerDataService._getSliceShell = _origGetSliceShell
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

			it("should throw for a negative quantity (never write a negative stack)", function()
				_profiles[1] = makeProfile({ sword(5) })
				expect(function()
					InventoryService:addItem(1, sword(-100))
				end).to.throw()
				-- The existing stack is untouched (the guard runs before any mutation).
				expect(_profiles[1].inventory[1].quantity).to.equal(5)
			end)

			it("should throw for a zero quantity", function()
				_profiles[1] = makeProfile({})
				expect(function()
					InventoryService:addItem(1, sword(0))
				end).to.throw()
				expect(#_profiles[1].inventory).to.equal(0)
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

			it("returns a BatchResult tallying applied vs skipped on partial application", function()
				local origMax = InventoryService.MAX_INVENTORY_SIZE
				InventoryService.MAX_INVENTORY_SIZE = 1
				_profiles[1] = makeProfile({ sword(5) })

				local ok, result = InventoryService:addItems(1, {
					blade("new-unique"), -- new stack, no room -> skipped
					sword(3), -- stacks onto existing iron-sword -> applied
				})

				InventoryService.MAX_INVENTORY_SIZE = origMax

				expect(ok).to.equal(true)
				expect(result.applied).to.equal(1)
				expect(result.skipped).to.equal(1)
				expect(result.total).to.equal(2)
			end)

			it("returns a zeroed BatchResult for an empty items list", function()
				_profiles[1] = makeProfile({})
				local ok, result = InventoryService:addItems(1, {})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(0)
				expect(result.skipped).to.equal(0)
				expect(result.total).to.equal(0)
			end)

			it("reports applied = 0 (and boolean false) when the profile is not loaded", function()
				local ok, result = InventoryService:addItems(999, { sword(1) })
				expect(ok).to.equal(false)
				expect(result.applied).to.equal(0)
				expect(result.skipped).to.equal(1)
				expect(result.total).to.equal(1)
			end)

			it("keeps stacking onto existing items after a new item hits the size cap", function()
				-- Inventory holds one stack and is already at the size cap, so a brand-new
				-- item can't fit — but a later item that stacks onto the existing entry
				-- needs no new slot and must still be applied (not dropped by an early exit).
				local origMax = InventoryService.MAX_INVENTORY_SIZE
				InventoryService.MAX_INVENTORY_SIZE = 1
				_profiles[1] = makeProfile({ sword(5) })

				local ok = InventoryService:addItems(1, {
					blade("new-unique"), -- new stack, no room -> skipped
					sword(3), -- stacks onto the existing iron-sword -> applied
				})

				InventoryService.MAX_INVENTORY_SIZE = origMax

				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(1)
				expect(_profiles[1].inventory[1].quantity).to.equal(8)
			end)

			it("skips a malformed entry (no itemType) and still applies the valid ones", function()
				-- Best-effort contract: a bad entry must NOT throw and abort the batch, which would
				-- also leave the already-applied items unsynced. The valid items must land.
				_profiles[1] = makeProfile({})
				local ok, result = InventoryService:addItems(1, {
					sword(2),
					{ quantity = 5 } :: any, -- no itemType -> skipped, must not throw
					blade("i1"),
				})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(2)
				expect(result.skipped).to.equal(1)
				expect(#_profiles[1].inventory).to.equal(2)
			end)

			it("skips an entry with an invalid itemType and applies the valid ones", function()
				_profiles[1] = makeProfile({})
				local ok, result = InventoryService:addItems(1, {
					sword(2),
					{ itemType = "not-a-real-item", quantity = 1 } :: any, -- invalid -> skipped
					blade("i1"),
				})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(2)
				expect(result.skipped).to.equal(1)
				expect(#_profiles[1].inventory).to.equal(2)
			end)

			it("skips an entry with a non-positive quantity and applies the valid ones", function()
				_profiles[1] = makeProfile({})
				local ok, result = InventoryService:addItems(1, {
					sword(2),
					{ itemType = "iron-sword", quantity = -5 } :: any, -- non-positive -> skipped
					blade("i1"),
				})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(2)
				expect(result.skipped).to.equal(1)
				-- The valid iron-sword stack is exactly 2 (the -5 entry never merged in).
				expect(_profiles[1].inventory[1].quantity).to.equal(2)
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

			it("should remove a unique item when amount is 1", function()
				_profiles[1] = makeProfile({ blade("inst-1") })
				local ok = InventoryService:removeItem(1, blade("inst-1"), 1)
				expect(ok).to.equal(true)
				expect(#_profiles[1].inventory).to.equal(0)
			end)

			it("should fail (and keep the item) when removing more than one of a unique item", function()
				_profiles[1] = makeProfile({ blade("inst-1") })
				local ok = InventoryService:removeItem(1, blade("inst-1"), 99)
				expect(ok).to.equal(false)
				expect(#_profiles[1].inventory).to.equal(1)
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

			it("returns a BatchResult tallying applied vs skipped when one request can't be met", function()
				_profiles[1] = makeProfile({ sword(10) })
				local ok, result = InventoryService:removeItems(1, {
					{ item = sword(), amount = 5 }, -- applied
					{ item = blade("missing"), amount = 1 }, -- not present -> skipped
				})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(1)
				expect(result.skipped).to.equal(1)
				expect(result.total).to.equal(2)
			end)

			it("returns a zeroed BatchResult for an empty requests list", function()
				_profiles[1] = makeProfile({})
				local ok, result = InventoryService:removeItems(1, {})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(0)
				expect(result.skipped).to.equal(0)
				expect(result.total).to.equal(0)
			end)

			it("skips a malformed request (non-positive amount) and applies the valid ones", function()
				-- Same best-effort guarantee as addItems: a bad request must be skipped, not throw and
				-- abort the batch leaving the earlier removal unsynced.
				_profiles[1] = makeProfile({ sword(10), blade("inst-1") })
				local ok, result = InventoryService:removeItems(1, {
					{ item = sword(), amount = 4 }, -- applied
					{ item = sword(), amount = -1 } :: any, -- non-positive -> skipped, must not throw
					{ item = blade("inst-1"), amount = 1 }, -- applied
				})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(2)
				expect(result.skipped).to.equal(1)
				-- sword decremented by 4 (only the valid removal), blade gone.
				expect(_profiles[1].inventory[1].quantity).to.equal(6)
				expect(#_profiles[1].inventory).to.equal(1)
			end)

			it("skips a request with an invalid/missing itemType and applies the valid ones", function()
				-- tryRemove asserts itemType presence + validity; the batch must screen them too or a
				-- bad entry throws mid-batch and leaves earlier in-place removals unsynced.
				_profiles[1] = makeProfile({ sword(10), blade("inst-1") })
				local ok, result = InventoryService:removeItems(1, {
					{ item = sword(), amount = 4 }, -- applied
					{ item = { itemType = "not-a-real-item" }, amount = 1 } :: any, -- invalid -> skipped
					{ item = { amount = 1 } :: any, amount = 1 } :: any, -- no itemType -> skipped
					{ item = blade("inst-1"), amount = 1 }, -- applied
				})
				expect(ok).to.equal(true)
				expect(result.applied).to.equal(2)
				expect(result.skipped).to.equal(2)
				expect(_profiles[1].inventory[1].quantity).to.equal(6)
				expect(#_profiles[1].inventory).to.equal(1)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("inventoryOp", function()
			it("mints a transaction operation targeting the inventory path", function()
				local mutator = function(inv: any)
					table.insert(inv, sword(1))
					return true
				end
				local op = InventoryService:inventoryOp(7, mutator)
				expect(op.userId).to.equal(7)
				expect(op.path).to.equal("inventory")
				expect(op.mutator).to.equal(mutator)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					InventoryService:inventoryOp("bad" :: any, function()
						return true
					end)
				end).to.throw()
			end)
		end)
	end)
end
