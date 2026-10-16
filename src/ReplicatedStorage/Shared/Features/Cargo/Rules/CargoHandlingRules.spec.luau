local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoHandlingRules = require(script.Parent.CargoHandlingRules)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

return function()
	describe("impacts and spills", function()
		it("counts every drop reason except destruction as an impact", function()
			for _, reason in { "drop", "throw", "forced", "death", "removed" } do
				expect(CargoHandlingRules.isImpact(reason)).to.equal(true)
			end
			expect(CargoHandlingRules.isImpact("destroyed")).to.equal(false)
		end)

		it("preserves recycling identity on ordinary release and spills only a deliberate throw", function()
			local box = CargoRegistry.get("recyclingBox")
			for _, reason in { "drop", "forced", "death", "removed", "destroyed" } do
				expect(CargoHandlingRules.shouldSpill(box, reason)).to.equal(false)
			end
			expect(CargoHandlingRules.shouldSpill(box, "throw")).to.equal(true)
			expect(CargoHandlingRules.shouldSpill(box, "destroyed")).to.equal(false)
			expect(CargoHandlingRules.shouldSpill(CargoRegistry.get("rubbishBag"), "drop")).to.equal(false)
		end)
	end)

	describe("dropNoise", function()
		it("scales with size and splashes loudest", function()
			expect(CargoHandlingRules.dropNoise(CargoRegistry.get("plaque"))).to.equal(CargoConstants.DROP_NOISE.tiny)
			expect(CargoHandlingRules.dropNoise(CargoRegistry.get("coffeeMachine"))).to.equal(
				CargoConstants.DROP_NOISE.heavy
			)
			expect(CargoHandlingRules.dropNoise(CargoRegistry.get("waterJug"))).to.equal(CargoConstants.SPLASH_NOISE)
			expect(CargoConstants.SPLASH_NOISE > CargoConstants.DROP_NOISE.bulky).to.equal(true)
		end)
	end)

	describe("traits (M2)", function()
		it("rattles only a rattly item", function()
			expect(CargoHandlingRules.rattles(CargoRegistry.get("bottleBag"))).to.equal(true)
			expect(CargoHandlingRules.rattles(CargoRegistry.get("coffeeMachine"))).to.equal(true)
			expect(CargoHandlingRules.rattles(CargoRegistry.get("fishTank"))).to.equal(true)
			expect(CargoHandlingRules.rattles(CargoRegistry.get("officePlant"))).to.equal(false)
		end)

		it("leaves a puddle only when the jug hits the floor", function()
			local jug = CargoRegistry.get("waterJug")
			expect(CargoHandlingRules.leavesPuddle(jug, "drop")).to.equal(true)
			expect(CargoHandlingRules.leavesPuddle(jug, "throw")).to.equal(true)
			expect(CargoHandlingRules.leavesPuddle(jug, "death")).to.equal(true)
			expect(CargoHandlingRules.leavesPuddle(jug, "destroyed")).to.equal(false)
			expect(CargoHandlingRules.leavesPuddle(CargoRegistry.get("coffeeMachine"), "drop")).to.equal(false)
		end)
	end)

	describe("slips", function()
		local SIZE = Vector3.new(7, 0.15, 7)

		it("slips a player crossing a puddle at walking speed", function()
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 14, 10, -math.huge)).to.equal(true)
			expect(CargoHandlingRules.slips(Vector3.new(3.4, 3, -3.4), SIZE, 10.4, 10, -math.huge)).to.equal(true)
		end)

		it("lets a player stand or creep in it", function()
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 2, 10, -math.huge)).to.equal(false)
		end)

		it("ignores a player beside it or high above it", function()
			expect(CargoHandlingRules.slips(Vector3.new(5, 3, 0), SIZE, 14, 10, -math.huge)).to.equal(false)
			expect(CargoHandlingRules.slips(Vector3.new(0, 9, 0), SIZE, 14, 10, -math.huge)).to.equal(false)
		end)

		it("does not slip again straight after a slip", function()
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 14, 10, 9)).to.equal(false)
			expect(CargoHandlingRules.slips(Vector3.new(0, 3, 0), SIZE, 14, 12, 9)).to.equal(true)
		end)
	end)
end
