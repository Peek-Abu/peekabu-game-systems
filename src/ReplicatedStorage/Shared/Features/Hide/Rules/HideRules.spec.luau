local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideRules = require(script.Parent.HideRules)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

local function input(extra)
	local value = {
		alive = true,
		hidden = false,
		catching = false,
		heldSize = nil,
		occupied = false,
		cooling = false,
		rested = true,
		distance = 3,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("canEnter", function()
		local function refused(extra, expected)
			local ok, reason = HideRules.canEnter(input(extra))
			expect(ok).to.equal(false)
			expect(reason).to.equal(expected)
		end

		it("lets an empty-handed, living player in range into a free spot", function()
			expect(HideRules.canEnter(input())).to.equal(true)
		end)

		it("lets a player hide with a small (tiny or light) item, never with anything bigger", function()
			expect(HideRules.canEnter(input({ heldSize = "tiny" }))).to.equal(true)
			expect(HideRules.canEnter(input({ heldSize = "light" }))).to.equal(true)
			refused({ heldSize = "medium" }, "hands full")
			refused({ heldSize = "bulky" }, "hands full")
		end)

		it("refuses the dead, the caught, the already hidden, a taken spot and a spot cooling off", function()
			refused({ alive = false }, "not alive")
			refused({ catching = true }, "caught")
			refused({ hidden = true }, "already hidden")
			refused({ occupied = true }, "taken")
			refused({ cooling = true }, "cramped")
			refused({ rested = false }, "too soon")
		end)

		it("refuses from too far, with the tolerance on top of the prompt's range", function()
			expect(HideRules.canEnter(input({ distance = HideConstants.ENTER_RANGE + HideConstants.RANGE_TOLERANCE }))).to.equal(
				true
			)
			refused({ distance = HideConstants.ENTER_RANGE + HideConstants.RANGE_TOLERANCE + 0.1 }, "too far")
			refused({ distance = 0 / 0 }, "too far")
		end)
	end)

	describe("canLeave", function()
		it("keeps a tap in for at least MIN_STAY_SECONDS before a tap out", function()
			expect(HideRules.canLeave(0)).to.equal(false)
			expect(HideRules.canLeave(HideConstants.MIN_STAY_SECONDS - 0.01)).to.equal(false)
			expect(HideRules.canLeave(HideConstants.MIN_STAY_SECONDS)).to.equal(true)
		end)
	end)

	describe("camping", function()
		it("is fine, then cramped, then pushed out", function()
			expect(HideRules.camp(0)).to.equal("ok")
			expect(HideRules.camp(HideConstants.CAMP_WARN_SECONDS - 0.1)).to.equal("ok")
			expect(HideRules.camp(HideConstants.CAMP_WARN_SECONDS)).to.equal("cramped")
			expect(HideRules.camp(HideConstants.CAMP_SECONDS)).to.equal("out")
		end)

		it("counts down the seconds left, never below zero", function()
			expect(HideRules.secondsLeft(0)).to.equal(HideConstants.CAMP_SECONDS)
			expect(HideRules.secondsLeft(HideConstants.CAMP_SECONDS - 4.2)).to.equal(5)
			expect(HideRules.secondsLeft(HideConstants.CAMP_SECONDS + 3)).to.equal(0)
		end)
	end)
end
