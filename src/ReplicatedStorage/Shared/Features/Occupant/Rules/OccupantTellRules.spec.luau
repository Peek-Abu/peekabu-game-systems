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

		it("stares in silence, works without a cue, and shows ? in the ambush", function()
			expect(OccupantTellRules.cueFor("stare", "hold")).to.equal("")
			expect(OccupantTellRules.cueFor("work", "type")).to.equal("")
			expect(OccupantTellRules.cueFor("work", "ambush")).to.equal("?")
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

	describe("view", function()
		local function mind(extra)
			local value = { mode = "patrol", since = 0, routeIndex = 1, routeStep = 1, grace = {} }
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end
		it("shows a patrol calm, with no cue, phase, gesture or tilt", function()
			local view = OccupantTellRules.view(mind(), 5)
			expect(view.face).to.equal("Calm")
			expect(view.cue).to.equal("")
			expect(view.phase).to.equal("")
			expect(view.gesture).to.equal("")
			expect(view.target).to.equal(0)
			expect(view.tilt).to.equal(false)
		end)
		it("swivels to the ambush point while it lasts", function()
			local point = Vector3.new(1, 2, 3)
			local view = OccupantTellRules.view(
				mind({ mode = "work", phase = "ambush", phaseAt = 0, point = point, swivelUntil = math.huge }),
				1
			)
			expect(view.gesture).to.equal("swivel")
			expect(view.gestureTarget).to.equal(point)
			expect(view.face).to.equal("Noticing")
			expect(view.cue).to.equal("?")
		end)
		it("tilts his head through the jumpscare of a catch, from under the desk after a sit-in", function()
			local view = OccupantTellRules.view(mind({ mode = "catch", since = 10, sitIn = true, target = 7 }), 10.2)
			expect(view.tilt).to.equal(true)
			expect(view.gesture).to.equal("under")
			expect(view.face).to.equal("Hunting")
			expect(view.target).to.equal(7)
			expect(OccupantTellRules.view(mind({ mode = "catch", since = 10 }), 20).tilt).to.equal(false)
		end)
		it("names the hider he is at as his target", function()
			expect(OccupantTellRules.view(mind({ mode = "stare", phase = "hold", quarry = 9 }), 1).target).to.equal(9)
		end)
	end)

	describe("revealed", function()
		it(
			"turns a hider's camera to his face while he looks under their spot or tips his head under their desk",
			function()
				expect(OccupantTellRules.revealed("stare", "check", true, true)).to.equal(true)
				expect(OccupantTellRules.revealed("work", "tip", true, true)).to.equal(true)
				expect(OccupantTellRules.revealed("work", "tipHold", true, true)).to.equal(true)
			end
		)
		it("never for someone else, someone not hiding, or another moment", function()
			expect(OccupantTellRules.revealed("stare", "check", false, true)).to.equal(false)
			expect(OccupantTellRules.revealed("stare", "check", true, false)).to.equal(false)
			expect(OccupantTellRules.revealed("stare", "hold", true, true)).to.equal(false)
			expect(OccupantTellRules.revealed("work", "type", true, true)).to.equal(false)
		end)
	end)

	describe("typing", function()
		it("types while he sits at a desk, and stops dead otherwise", function()
			expect(OccupantTellRules.typing("work", "type")).to.equal(true)
			expect(OccupantTellRules.typing("work", "typeMore")).to.equal(true)
			expect(OccupantTellRules.typing("work", "ambush")).to.equal(false)
			expect(OccupantTellRules.typing("work", "tip")).to.equal(false)
			expect(OccupantTellRules.typing("patrol", nil)).to.equal(false)
		end)
	end)

	describe("stage", function()
		it("is the chase while he chases you, whatever the distance", function()
			expect(OccupantTellRules.stage(200, "chase", true)).to.equal("chase")
		end)
		it("bands the distance into near, mid and far", function()
			expect(OccupantTellRules.stage(OccupantConstants.STAGE_NEAR - 1, "patrol", false)).to.equal("near")
			expect(OccupantTellRules.stage(OccupantConstants.STAGE_NEAR + 1, "patrol", false)).to.equal("mid")
			expect(OccupantTellRules.stage(OccupantConstants.STAGE_MID + 1, "chase", false)).to.equal("far")
			expect(OccupantTellRules.stage(OccupantConstants.STAGE_FAR + 1, "patrol", false)).to.equal("none")
		end)
		it("is quiet while he rests", function()
			expect(OccupantTellRules.stage(10, "rest", false)).to.equal("none")
		end)
	end)

	describe("paLine", function()
		it("names the called-out player", function()
			expect(OccupantTellRules.paLine("{name}. My office.", "Pippa")).to.equal("Pippa. My office.")
			expect(OccupantTellRules.paLine("All staff.", "Pippa")).to.equal("All staff.")
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
	it("identifies visible emitters without turning fixture housings neon", function()
		expect(OccupantTellRules.isEmitter(Enum.Material.Neon, false)).to.equal(true)
		expect(OccupantTellRules.isEmitter(Enum.Material.SmoothPlastic, true)).to.equal(true)
		expect(OccupantTellRules.isEmitter(Enum.Material.Metal, false)).to.equal(false)
	end)
end
