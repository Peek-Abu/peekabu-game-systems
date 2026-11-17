--[[
	Unit tests for LockerPurchaseSystem's refusals that come before any profile or transaction work. The full buy paths
	(key and direct purchases, with real fake profiles) are covered by LockerServiceServer.spec.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local LockerPurchaseSystem = require(ServerScriptService.Features.Locker.Systems.LockerPurchaseSystem)

return function()
	local function depsWith(locked, live)
		return {
			isLocked = function()
				return locked
			end,
			restricted = function()
				return false
			end,
			pool = function()
				return {}
			end,
			live = function()
				return live
			end,
		}
	end
	local player = { UserId = 424242 }
	-- The slice is never reached by these refusals.
	local noSlice = {}

	describe("findInPool", function()
		it("finds an item by id", function()
			local pool = { { id = "A" }, { id = "B" } }
			expect(LockerPurchaseSystem.findInPool(pool, "B")).to.equal(pool[2])
		end)

		it("returns nil when the item is not in the pool", function()
			expect(LockerPurchaseSystem.findInPool({ { id = "A" } }, "Z")).to.equal(nil)
		end)
	end)

	describe("buyKey", function()
		it("refuses during a shift", function()
			local ok, reason = LockerPurchaseSystem.buyKey(depsWith(true, nil), noSlice, player, "gloom")
			expect(ok).to.equal(false)
			expect(reason).to.equal("locked during a shift")
		end)

		it("refuses an unknown locker", function()
			local ok, reason = LockerPurchaseSystem.buyKey(depsWith(false, nil), noSlice, player, "nope")
			expect(ok).to.equal(false)
			expect(reason).to.equal("unknown locker")
		end)
	end)

	describe("buyDirect", function()
		it("refuses during a shift", function()
			local ok, reason = LockerPurchaseSystem.buyDirect(depsWith(true, nil), noSlice, player, "gleam", "x")
			expect(ok).to.equal(false)
			expect(reason).to.equal("locked during a shift")
		end)

		it("refuses an unknown locker", function()
			local ok, reason = LockerPurchaseSystem.buyDirect(depsWith(false, nil), noSlice, player, "nope", "x")
			expect(ok).to.equal(false)
			expect(reason).to.equal("unknown locker")
		end)
	end)
end
