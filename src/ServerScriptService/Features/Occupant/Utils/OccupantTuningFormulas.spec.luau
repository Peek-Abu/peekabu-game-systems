local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTuningFormulas = require(script.Parent.OccupantTuningFormulas)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoHandlingRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoHandlingRules)
local NoiseRules = require(ReplicatedStorage.Shared.Features.Noise.Rules.NoiseRules)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

-- Whether Harlow hears a noise of `radius` from `distance` studs away at this tier and crew size.
local function hears(distance, radius, tier, crew)
	local scale = OccupantTuningFormulas.tuning(tier, crew).hearing
	return NoiseRules.hears(Vector3.zero, Vector3.new(distance, 0, 0), radius, scale)
end

return function()
	describe("tuning", function()
		it("is a little easier on a training run: slower, and hears less", function()
			local shift = OccupantTuningFormulas.tuning(0, 1)
			local training = OccupantTuningFormulas.tuning(0, 1, true)
			expect(training.walkSpeed < shift.walkSpeed).to.equal(true)
			expect(training.runSpeed < shift.runSpeed).to.equal(true)
			expect(training.hearing < shift.hearing).to.equal(true)
			-- Still a chase: he runs faster than he walks.
			expect(training.runSpeed > training.walkSpeed).to.equal(true)
			expect(OccupantTuningFormulas.tuning(0, 1, false).runSpeed).to.equal(shift.runSpeed)
		end)

		it("starts at patrol 10, chase 20 and plain hearing for a crew", function()
			local tuning = OccupantTuningFormulas.tuning(0, 3)
			expect(tuning.walkSpeed).to.equal(10)
			expect(tuning.runSpeed).to.equal(20)
			expect(tuning.hearing).to.equal(1)
		end)

		it("adds 1 patrol speed, 0.5 chase speed and 1.2 hearing per tier", function()
			local tier1 = OccupantTuningFormulas.tuning(1, 3)
			expect(tier1.walkSpeed).to.equal(11)
			expect(tier1.runSpeed).to.equal(20.5)
			expect(tier1.hearing).to.be.near(1.2, 1e-6)
			local tier2 = OccupantTuningFormulas.tuning(2, 4)
			expect(tier2.walkSpeed).to.equal(12)
			expect(tier2.runSpeed).to.equal(21)
			expect(tier2.hearing).to.be.near(1.44, 1e-6)
		end)

		it("goes easier on a solo player: hearing 0.75, chase minus 0.5", function()
			local solo = OccupantTuningFormulas.tuning(0, 1)
			expect(solo.walkSpeed).to.equal(10)
			expect(solo.runSpeed).to.equal(19.5)
			expect(solo.hearing).to.be.near(0.75, 1e-6)
			expect(OccupantTuningFormulas.tuning(2, 1).hearing).to.be.near(1.08, 1e-6)
		end)

		it("treats an empty crew as solo and caps the tier", function()
			expect(OccupantTuningFormulas.tuning(0, 0).runSpeed).to.equal(19.5)
			expect(OccupantTuningFormulas.tuning(5, 3).walkSpeed).to.equal(12)
			expect(OccupantTuningFormulas.tuning(-1, 3).walkSpeed).to.equal(10)
		end)

		it("can close on an empty-handed player without needing a cargo slowdown", function()
			local chase = OccupantTuningFormulas.tuning(0, 1).runSpeed
			expect(chase - 16 >= 3.5).to.equal(true)
			expect(16 * (1 - 0.05 * CargoConstants.WEIGHT.tiny) < chase).to.equal(true)
		end)
	end)

	describe("per kind", function()
		local bramble = OccupantKindRegistry.get("bramble")
		local harlow = OccupantKindRegistry.get("harlow")

		it("is Harlow's tuning with no kind or with Harlow's kind", function()
			for tier = 0, 2 do
				for _, crew in { 1, 3 } do
					local plain = OccupantTuningFormulas.tuning(tier, crew)
					local his = OccupantTuningFormulas.tuning(tier, crew, false, harlow)
					expect(his.walkSpeed).to.equal(plain.walkSpeed)
					expect(his.runSpeed).to.equal(plain.runSpeed)
					expect(his.hearing).to.equal(plain.hearing)
				end
			end
		end)

		it("starts Bramble at patrol 10 and chase 21 for a crew", function()
			local tuning = OccupantTuningFormulas.tuning(0, 3, false, bramble)
			expect(tuning.walkSpeed).to.equal(10)
			expect(tuning.runSpeed).to.equal(21)
			expect(tuning.hearing).to.equal(1)
		end)

		it("keeps Bramble slower than a sprint (23) at the top tier", function()
			expect(OccupantTuningFormulas.tuning(2, 4, false, bramble).runSpeed < 23).to.equal(true)
		end)

		it("applies the training scale to Bramble's speeds too", function()
			local training = OccupantTuningFormulas.tuning(0, 3, true, bramble)
			expect(training.runSpeed).to.be.near(21 * ShiftConstants.TRAINING_SPEED, 1e-6)
		end)
	end)

	describe("who hears what", function()
		it("hears a crew's vacuum within 40 studs at the start", function()
			expect(hears(39, VacuumConstants.NOISE_RADIUS, 0, 3)).to.equal(true)
			expect(hears(41, VacuumConstants.NOISE_RADIUS, 0, 3)).to.equal(false)
		end)

		it("hears further at each pressure tier", function()
			expect(hears(47, VacuumConstants.NOISE_RADIUS, 1, 3)).to.equal(true)
			expect(hears(49, VacuumConstants.NOISE_RADIUS, 1, 3)).to.equal(false)
			expect(hears(57, VacuumConstants.NOISE_RADIUS, 2, 3)).to.equal(true)
			expect(hears(58, VacuumConstants.NOISE_RADIUS, 2, 3)).to.equal(false)
		end)

		it("hears a solo player at three quarters of the radius", function()
			expect(hears(29, VacuumConstants.NOISE_RADIUS, 0, 1)).to.equal(true)
			expect(hears(31, VacuumConstants.NOISE_RADIUS, 0, 1)).to.equal(false)
		end)

		it("hears a heavy drop further than a light one, and the jug's splash across a room", function()
			local bag = CargoHandlingRules.dropNoise(CargoRegistry.get("rubbishBag"))
			local machine = CargoHandlingRules.dropNoise(CargoRegistry.get("coffeeMachine"))
			local jug = CargoHandlingRules.dropNoise(CargoRegistry.get("waterJug"))
			expect(hears(20, bag, 0, 3)).to.equal(false)
			expect(hears(20, machine, 0, 3)).to.equal(true)
			expect(hears(65, jug, 0, 3)).to.equal(true)
			expect(hears(15, CargoConstants.RATTLE_NOISE, 0, 3)).to.equal(false)
			expect(hears(10, CargoConstants.RATTLE_NOISE, 0, 3)).to.equal(true)
		end)
	end)
end
