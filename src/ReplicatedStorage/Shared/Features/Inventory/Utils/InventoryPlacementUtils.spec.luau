local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryPlacementUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryPlacementUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local function alwaysRoom()
	return true
end

return function()
	describe("planStackPlacement", function()
		it("opens new stacks for a fresh itemType when there is room", function()
			local items: { PlayerDataTypes.InventoryEntry } = {}
			local plan = InventoryPlacementUtils.planStackPlacement(items, "wood", 25, 30, nil, "misc", alwaysRoom)
			expect(plan.ok).to.equal(true)
			assert(plan.newStacks, "newStacks present")
			expect(#plan.newStacks).to.equal(1)
			expect(plan.newStacks[1]).to.equal(25)
		end)

		it("merges into an existing partial stack before opening a new one", function()
			local items: { PlayerDataTypes.InventoryEntry } = { { itemType = "wood", quantity = 20 } }
			local plan = InventoryPlacementUtils.planStackPlacement(items, "wood", 15, 30, nil, "misc", alwaysRoom)
			expect(plan.ok).to.equal(true)
			assert(plan.updates, "updates present")
			expect(plan.updates[1]).to.equal(30) -- topped up to stackMax
			assert(plan.newStacks, "newStacks present")
			expect(plan.newStacks[1]).to.equal(5) -- spill
		end)

		it("refuses via the injected hasRoom callback, surfacing its reason", function()
			local function noRoom()
				return false, "container full"
			end
			local plan = InventoryPlacementUtils.planStackPlacement({}, "wood", 10, 30, nil, "misc", noRoom)
			expect(plan.ok).to.equal(false)
			expect(plan.reason).to.equal("container full")
		end)

		it("refuses when the spill would exceed the itemType's maxStacks (def-intrinsic, not hasRoom)", function()
			-- maxStacks = 1, one stack already full → the overflow can't open a second stack.
			local items: { PlayerDataTypes.InventoryEntry } = { { itemType = "throwing-knife", quantity = 10 } }
			local plan =
				InventoryPlacementUtils.planStackPlacement(items, "throwing-knife", 5, 10, 1, "consumable", alwaysRoom)
			expect(plan.ok).to.equal(false)
			expect((plan.reason :: string):find("maxStacks", 1, true)).to.be.ok()
		end)
	end)
end
