local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoInventoryRules = require(script.Parent.CargoInventoryRules)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local function state(overrides)
	local base = { selected = 1, hands = nil, handsBig = false, filled = {} }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("isSmall", function()
		it("calls tiny and light items small, everything else big", function()
			expect(CargoInventoryRules.isSmall(CargoRegistry.get("plaque"))).to.equal(true)
			expect(CargoInventoryRules.isSmall(CargoRegistry.get("rubbishBag"))).to.equal(true)
			expect(CargoInventoryRules.isSmall(CargoRegistry.get("monitor"))).to.equal(false)
			expect(CargoInventoryRules.isSmall(CargoRegistry.get("waterJug"))).to.equal(false)
			expect(CargoInventoryRules.isSmall(CargoRegistry.get("filingCabinet"))).to.equal(false)
		end)
	end)

	describe("handsFree", function()
		it("leaves pick-ups open with empty hands or a small item in one hand", function()
			expect(CargoInventoryRules.handsFree(nil)).to.equal(true)
			expect(CargoInventoryRules.handsFree("keyring")).to.equal(true)
			expect(CargoInventoryRules.handsFree("rubbishBag")).to.equal(true)
		end)

		it("closes them while a big item, or anything that is not cargo, fills the hands", function()
			expect(CargoInventoryRules.handsFree("monitor")).to.equal(false)
			expect(CargoInventoryRules.handsFree("filingCabinet")).to.equal(false)
			expect(CargoInventoryRules.handsFree("egg")).to.equal(false)
		end)
	end)

	describe("pickUpPlan", function()
		it("pockets a small item into a free slot, whatever is in hand", function()
			expect(CargoInventoryRules.pickUpPlan(CargoRegistry.get("coffeeMug"), 1, false)).to.equal("pocket")
			expect(CargoInventoryRules.pickUpPlan(CargoRegistry.get("plaque"), 4, false)).to.equal("pocket")
		end)

		it("holds a big item in both hands when a slot is free", function()
			expect(CargoInventoryRules.pickUpPlan(CargoRegistry.get("monitor"), 2, false)).to.equal("hold")
		end)

		it("refuses anything once every item slot is full", function()
			local plan, reason = CargoInventoryRules.pickUpPlan(CargoRegistry.get("keyring"), nil, false)
			expect(plan).to.equal(nil)
			expect(reason).to.equal("inventory full")
			local bigPlan = CargoInventoryRules.pickUpPlan(CargoRegistry.get("monitor"), nil, false)
			expect(bigPlan).to.equal(nil)
		end)

		it("refuses every pick-up while a big item fills the hands", function()
			local plan, reason = CargoInventoryRules.pickUpPlan(CargoRegistry.get("keyring"), 2, true)
			expect(plan).to.equal(nil)
			expect(reason).to.equal("hands full")
			expect(CargoInventoryRules.pickUpPlan(CargoRegistry.get("monitor"), 2, true)).to.equal(nil)
		end)

		it("refuses what is not cargo", function()
			local plan, reason = CargoInventoryRules.pickUpPlan(nil, 1, false)
			expect(plan).to.equal(nil)
			expect(reason).to.equal("not cargo")
		end)
	end)

	describe("selectPlan", function()
		it("takes the vacuum out from empty hands", function()
			local plan = CargoInventoryRules.selectPlan(1, state({ selected = 3 }))
			expect(plan.vacuum).to.equal(true)
			expect(plan.stash).to.equal(false)
			expect(plan.draw).to.equal(nil)
			expect(plan.selected).to.equal(1)
		end)

		it("puts a small hands item back in its slot before the vacuum comes out", function()
			local plan = CargoInventoryRules.selectPlan(1, state({ selected = 3, hands = 2, filled = { [2] = true } }))
			expect(plan.stash).to.equal(true)
			expect(plan.vacuum).to.equal(true)
			expect(plan.selected).to.equal(1)
		end)

		it("puts the vacuum away when slot 1 is chosen again", function()
			local plan = CargoInventoryRules.selectPlan(1, state({ selected = 1 }))
			expect(plan.vacuum).to.equal(false)
			expect(plan.selected).to.equal(0)
		end)

		it("draws a filled item slot into one hand and puts the vacuum away", function()
			local plan = CargoInventoryRules.selectPlan(3, state({ selected = 1, filled = { [2] = true } }))
			expect(plan.draw).to.equal(2)
			expect(plan.stash).to.equal(false)
			expect(plan.vacuum).to.equal(false)
			expect(plan.selected).to.equal(3)
		end)

		it("swaps one small hands item for another", function()
			local plan = CargoInventoryRules.selectPlan(
				4,
				state({ selected = 2, hands = 1, filled = { [1] = true, [3] = true } })
			)
			expect(plan.stash).to.equal(true)
			expect(plan.draw).to.equal(3)
			expect(plan.selected).to.equal(4)
		end)

		it("empties the hands on an empty slot", function()
			local plan = CargoInventoryRules.selectPlan(5, state({ selected = 2, hands = 1, filled = { [1] = true } }))
			expect(plan.stash).to.equal(true)
			expect(plan.draw).to.equal(nil)
			expect(plan.vacuum).to.equal(false)
			expect(plan.selected).to.equal(5)
		end)

		it("puts the hands item away when its own slot is chosen again", function()
			local plan = CargoInventoryRules.selectPlan(2, state({ selected = 2, hands = 1, filled = { [1] = true } }))
			expect(plan.stash).to.equal(true)
			expect(plan.draw).to.equal(nil)
			expect(plan.selected).to.equal(0)
		end)

		it("locks every slot while a big item fills the hands", function()
			for slot = 1, 5 do
				local plan, reason = CargoInventoryRules.selectPlan(
					slot,
					state({ selected = 3, hands = 2, handsBig = true, filled = { [2] = true } })
				)
				expect(plan).to.equal(nil)
				expect(reason).to.equal("hands full: drop it first")
			end
		end)

		it("refuses a slot that does not exist", function()
			expect(CargoInventoryRules.selectPlan(0, state())).to.equal(nil)
			expect(CargoInventoryRules.selectPlan(6, state())).to.equal(nil)
			expect(CargoInventoryRules.selectPlan(2.5, state())).to.equal(nil)
		end)
	end)

	describe("step", function()
		it("steps to the next or previous slot, wrapping round the five", function()
			expect(CargoInventoryRules.step(1, 1)).to.equal(2)
			expect(CargoInventoryRules.step(5, 1)).to.equal(1)
			expect(CargoInventoryRules.step(1, -1)).to.equal(5)
			expect(CargoInventoryRules.step(3, -1)).to.equal(2)
		end)

		it("starts from either end with nothing chosen", function()
			expect(CargoInventoryRules.step(0, 1)).to.equal(1)
			expect(CargoInventoryRules.step(0, -1)).to.equal(5)
		end)
	end)

	describe("load", function()
		it("adds SMALL_LOAD per small item to the big item's weight", function()
			expect(CargoInventoryRules.load(0, nil)).to.equal(0)
			expect(CargoInventoryRules.load(4, nil)).to.be.near(2, 1e-9)
			expect(CargoInventoryRules.load(3, CargoRegistry.get("monitor"))).to.be.near(5.5, 1e-9)
			expect(CargoInventoryRules.load(0, CargoRegistry.get("filingCabinet"))).to.be.near(10, 1e-9)
		end)

		it("never counts a small kind as the big item", function()
			expect(CargoInventoryRules.load(1, CargoRegistry.get("plaque"))).to.be.near(0.5, 1e-9)
		end)
	end)
end
