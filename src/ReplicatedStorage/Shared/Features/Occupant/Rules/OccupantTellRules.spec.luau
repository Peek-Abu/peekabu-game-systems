local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTellRules = require(script.Parent.OccupantTellRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

return function()
	describe("cues and lines", function()
		it("shows ? while he investigates or searches and ! while he chases", function()
			expect(OccupantTellRules.cueFor("investigate")).to.equal("?")
			expect(OccupantTellRules.cueFor("search")).to.equal("?")
			expect(OccupantTellRules.cueFor("chase")).to.equal("!")
			expect(OccupantTellRules.cueFor("patrol")).to.equal("")
			expect(OccupantTellRules.cueFor("rest")).to.equal("")
			expect(OccupantTellRules.cueFor(nil)).to.equal("")
		end)

		it("speaks the spec's lines", function()
			expect(OccupantTellRules.lineFor("spotted")).to.equal("Those are COMPANY ASSETS.")
			expect(OccupantTellRules.lineFor("curious")).to.equal("Per my last email…")
			expect(OccupantTellRules.lineFor("caught")).to.equal("You're FIRED!")
			expect(OccupantTellRules.lineFor("giveUp")).to.equal(OccupantConstants.LINES.giveUp)
			expect(OccupantTellRules.lineFor(nil)).to.equal(nil)
			expect(OccupantTellRules.lineFor("nonsense")).to.equal(nil)
		end)
	end)

	describe("heartbeat", function()
		it("beats when he is near and has not seen you", function()
			expect(OccupantTellRules.heartbeat(20, "patrol", false)).to.equal(true)
			expect(OccupantTellRules.heartbeat(20, "chase", false)).to.equal(true)
			expect(OccupantTellRules.heartbeat(20, "investigate", true)).to.equal(true)
		end)

		it("stops when he is far or chasing you", function()
			expect(OccupantTellRules.heartbeat(OccupantConstants.HEARTBEAT_RANGE + 1, "patrol", false)).to.equal(false)
			expect(OccupantTellRules.heartbeat(10, "chase", true)).to.equal(false)
		end)

		it("beats faster the closer he is", function()
			expect(OccupantTellRules.period(0)).to.be.near(OccupantConstants.BEAT_FAST, 1e-6)
			expect(OccupantTellRules.period(OccupantConstants.HEARTBEAT_RANGE)).to.be.near(
				OccupantConstants.BEAT_SLOW,
				1e-6
			)
			expect(OccupantTellRules.period(999)).to.be.near(OccupantConstants.BEAT_SLOW, 1e-6)
			expect(OccupantTellRules.period(10) < OccupantTellRules.period(30)).to.equal(true)
		end)

		it("pulses from full at each beat and fades within it", function()
			expect(OccupantTellRules.pulse(0, 20)).to.equal(1)
			local period = OccupantTellRules.period(20)
			expect(OccupantTellRules.pulse(period * 0.9, 20)).to.equal(0)
			expect(OccupantTellRules.pulse(period, 20)).to.be.near(1, 1e-6)
			for index = 0, 50 do
				local value = OccupantTellRules.pulse(index * 0.07, 15)
				expect(value >= 0 and value <= 1).to.equal(true)
			end
		end)
	end)

	describe("flicker", function()
		it("leaves lights far from him alone", function()
			for index = 0, 50 do
				expect(OccupantTellRules.flicker(OccupantConstants.FLICKER_RADIUS + 1, index * 0.05, 0.37)).to.equal(
					true
				)
			end
		end)

		it("flickers lights near him: mostly on, sometimes off", function()
			local on, off = 0, 0
			for index = 0, 399 do
				if OccupantTellRules.flicker(5, index * 0.05, 0.37) then
					on += 1
				else
					off += 1
				end
			end
			expect(on > 0).to.equal(true)
			expect(off > 0).to.equal(true)
			expect(on > off).to.equal(true)
		end)
	end)
end
