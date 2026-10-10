local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantCatchRules = require(script.Parent.OccupantCatchRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local ZONE = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) }

local function input(extra)
	local value = {
		distance = 3,
		position = Vector3.new(60, 3, 60),
		alive = true,
		catching = false,
		inGrace = false,
		resting = false,
		zone = ZONE,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	local function refused(extra, expected)
		local ok, reason = OccupantCatchRules.canCatch(input(extra))
		expect(ok).to.equal(false)
		expect(reason).to.equal(expected)
	end

	describe("canCatch", function()
		it("catches a living player within reach outside the loading bay", function()
			expect(OccupantCatchRules.canCatch(input())).to.equal(true)
			expect(
				OccupantCatchRules.canCatch(
					input({ distance = OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK })
				)
			).to.equal(true)
		end)

		it("refuses a player out of reach", function()
			refused({ distance = OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK + 0.1 }, "too far")
		end)

		it("refuses a NaN distance", function()
			refused({ distance = 0 / 0 }, "too far")
		end)

		it("refuses a player in the safe zone, even at arm's length", function()
			refused({ position = Vector3.new(38, 3, 28), distance = 2 }, "safe zone")
		end)

		it("refuses a dead player, one mid-catch, one in grace, and anyone on his break", function()
			refused({ alive = false }, "not alive")
			refused({ catching = true }, "already caught")
			refused({ inGrace = true }, "grace")
			refused({ resting = true }, "on break")
		end)
	end)

	describe("launch", function()
		it("throws the player away from him and up", function()
			local velocity = OccupantCatchRules.launch(Vector3.new(0, 5, 0), Vector3.new(10, 3, 0), 45, 35)
			expect(velocity.X).to.be.near(45, 1e-6)
			expect(velocity.Y).to.be.near(35, 1e-6)
			expect(velocity.Z).to.be.near(0, 1e-6)
		end)

		it("throws at full speed on a diagonal", function()
			local velocity = OccupantCatchRules.launch(Vector3.zero, Vector3.new(3, 0, 4), 45, 35)
			expect(Vector3.new(velocity.X, 0, velocity.Z).Magnitude).to.be.near(45, 1e-6)
		end)

		it("still throws when they stand on the same spot", function()
			local velocity = OccupantCatchRules.launch(Vector3.zero, Vector3.new(0, 2, 0), 45, 35)
			expect(velocity.X).to.be.near(45, 1e-6)
			expect(velocity.Y).to.be.near(35, 1e-6)
		end)
	end)
end
