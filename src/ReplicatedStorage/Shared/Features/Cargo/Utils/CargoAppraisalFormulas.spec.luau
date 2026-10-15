local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoAppraisalFormulas = require(script.Parent.CargoAppraisalFormulas)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

-- A Random stand-in that returns scripted draws.
local function scripted(integers, numbers)
	local i, n = 0, 0
	return {
		NextInteger = function(_self, min, max)
			i += 1
			local value = integers[i]
			assert(value >= min and value <= max, "scripted integer out of range")
			return value
		end,
		NextNumber = function(_self)
			n += 1
			return numbers[n]
		end,
	}
end

return function()
	describe("depthMultiplier", function()
		it("pays x1 next to the bay and 0.15 more per room after, capped at 1.6", function()
			expect(CargoAppraisalFormulas.depthMultiplier(0)).to.equal(1)
			expect(CargoAppraisalFormulas.depthMultiplier(1)).to.equal(1)
			expect(CargoAppraisalFormulas.depthMultiplier(2)).to.be.near(1.15, 1e-9)
			expect(CargoAppraisalFormulas.depthMultiplier(3)).to.be.near(1.3, 1e-9)
			expect(CargoAppraisalFormulas.depthMultiplier(5)).to.be.near(1.6, 1e-9)
			expect(CargoAppraisalFormulas.depthMultiplier(12)).to.be.near(1.6, 1e-9)
		end)
	end)

	describe("roll", function()
		it("rolls the range, scales by depth and leaves the plain value without a jackpot", function()
			local monitor = CargoRegistry.get("monitor")
			local roll, plain = CargoAppraisalFormulas.roll(monitor, 3, scripted({ 100 }, { 0.5 }))
			expect(roll.base).to.equal(130)
			expect(roll.variant).to.equal(nil)
			expect(plain).to.equal(130)
		end)

		it("multiplies a jackpot hit and names it, while the plain value stays unmultiplied", function()
			local monitor = CargoRegistry.get("monitor")
			local roll, plain = CargoAppraisalFormulas.roll(monitor, 1, scripted({ 100 }, { 0.05 }))
			expect(roll.base).to.equal(250)
			expect(roll.variant).to.equal("Gold-trim")
			expect(plain).to.equal(100)
		end)

		it("always draws the jackpot number, even for a kind without one (same rng use for every kind)", function()
			local plant = CargoRegistry.get("officePlant")
			local draws = 0
			local rng = {
				NextInteger = function(_self, min)
					return min
				end,
				NextNumber = function(_self)
					draws += 1
					return 0
				end,
			}
			local roll = CargoAppraisalFormulas.roll(plant, 1, rng)
			expect(draws).to.equal(1)
			expect(roll.variant).to.equal(nil)
			expect(roll.base).to.equal(45)
		end)

		it("stays inside the scaled range for real seeds", function()
			for _, id in CargoRegistry.ids() do
				local def = CargoRegistry.get(id)
				if def.grimy then
					local rng = Random.new(5)
					for depth = 0, 6 do
						local roll, plain = CargoAppraisalFormulas.roll(def, depth, rng)
						local scale = CargoAppraisalFormulas.depthMultiplier(depth)
						expect(plain >= math.floor(def.valueMin * scale) and plain <= math.ceil(def.valueMax * scale)).to.equal(
							true
						)
						expect(roll.base >= plain).to.equal(true)
					end
				end
			end
		end)
	end)

	describe("grimeFactor", function()
		it("pays 30% grimy, 100% clean, linearly between, clamped", function()
			expect(CargoAppraisalFormulas.grimeFactor(0)).to.be.near(0.3, 1e-9)
			expect(CargoAppraisalFormulas.grimeFactor(0.5)).to.be.near(0.65, 1e-9)
			expect(CargoAppraisalFormulas.grimeFactor(1)).to.be.near(1, 1e-9)
			expect(CargoAppraisalFormulas.grimeFactor(-1)).to.be.near(0.3, 1e-9)
			expect(CargoAppraisalFormulas.grimeFactor(2)).to.be.near(1, 1e-9)
		end)
	end)

	describe("value", function()
		it("multiplies base, fragile tier and grime, rounded", function()
			local monitor = CargoRegistry.get("monitor")
			expect(CargoAppraisalFormulas.value(monitor, 100, 0, 1)).to.equal(100)
			expect(CargoAppraisalFormulas.value(monitor, 100, 0, 0)).to.equal(30)
			expect(CargoAppraisalFormulas.value(monitor, 100, 1, 0.6)).to.equal(36)
			expect(CargoAppraisalFormulas.value(monitor, 100, 5, 1)).to.equal(25)
		end)

		it("ignores impacts on a sturdy item", function()
			local plant = CargoRegistry.get("officePlant")
			expect(CargoAppraisalFormulas.value(plant, 80, 3, 1)).to.equal(80)
		end)
	end)

	describe("appraisal", function()
		it("appraises at 65% clean and never un-appraises", function()
			expect(CargoAppraisalFormulas.isAppraised(0.64, false)).to.equal(false)
			expect(CargoAppraisalFormulas.isAppraised(0.65, false)).to.equal(true)
			expect(CargoAppraisalFormulas.isAppraised(0, true)).to.equal(true)
		end)

		it("builds a fresh, fully grimy appraisal from a roll", function()
			local fresh = CargoAppraisalFormulas.fresh({ base = 90, variant = "Gold-trim" })
			expect(fresh.base).to.equal(90)
			expect(fresh.variant).to.equal("Gold-trim")
			expect(fresh.clean).to.equal(0)
			expect(fresh.appraised).to.equal(false)
		end)
	end)

	describe("cleanAt", function()
		it("cleans the remaining grime as the channel progresses", function()
			expect(CargoAppraisalFormulas.cleanAt(0, 0.4)).to.be.near(0.4, 1e-9)
			expect(CargoAppraisalFormulas.cleanAt(0.5, 0.5)).to.be.near(0.75, 1e-9)
			expect(CargoAppraisalFormulas.cleanAt(0.5, 0)).to.be.near(0.5, 1e-9)
			expect(CargoAppraisalFormulas.cleanAt(0.2, 1)).to.be.near(1, 1e-9)
			expect(CargoAppraisalFormulas.cleanAt(0.2, 3)).to.be.near(1, 1e-9)
		end)
	end)

	describe("displayName", function()
		it("names a jackpot only once appraised", function()
			local monitor = CargoRegistry.get("monitor")
			expect(CargoAppraisalFormulas.displayName(monitor, "Gold-trim", false)).to.equal("Monitor")
			expect(CargoAppraisalFormulas.displayName(monitor, "Gold-trim", true)).to.equal("Gold-trim monitor")
			expect(CargoAppraisalFormulas.displayName(monitor, nil, true)).to.equal("Monitor")
		end)
	end)
end
