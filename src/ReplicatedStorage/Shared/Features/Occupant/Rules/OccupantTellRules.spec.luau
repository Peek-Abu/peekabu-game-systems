local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTellRules = require(script.Parent.OccupantTellRules)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

return function()
	describe("lines", function()
		it("draws nothing over his head: the view has no cue", function()
			local view =
				OccupantTellRules.view({ mode = "chase", since = 0, routeIndex = 1, routeStep = 1, grace = {} }, 1)
			expect(view.cue).to.equal(nil)
		end)

		it("voices the spec's lines (never shown)", function()
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
		it("shows a patrol calm, with no phase, gesture or tilt", function()
			local view = OccupantTellRules.view(mind(), 5)
			expect(view.face).to.equal("Calm")
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
				expect(OccupantTellRules.revealed("stare", "open", true, true)).to.equal(true)
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

	describe("beatPeriod", function()
		it("races at CHASE_BEAT while he chases you, however far he is", function()
			expect(OccupantTellRules.beatPeriod(5, "chase", true)).to.equal(OccupantConstants.CHASE_BEAT)
			expect(OccupantTellRules.beatPeriod(200, "chase", true)).to.equal(OccupantConstants.CHASE_BEAT)
			expect(OccupantConstants.CHASE_BEAT < OccupantConstants.BEAT_FAST).to.equal(true)
		end)

		it("follows the near heartbeat otherwise, and is silent out of range", function()
			expect(OccupantTellRules.beatPeriod(10, "patrol", false)).to.equal(OccupantTellRules.period(10))
			expect(OccupantTellRules.beatPeriod(10, "chase", false)).to.equal(OccupantTellRules.period(10))
			expect(OccupantTellRules.beatPeriod(OccupantConstants.HEARTBEAT_RANGE + 1, "patrol", false)).to.equal(nil)
		end)
	end)

	describe("chasePulse", function()
		it("comes up quickly at the chase start and stays visible on every beat", function()
			expect(OccupantTellRules.chasePulse(0, nil)).to.equal(0)
			local settled = OccupantConstants.CHASE_RISE
			for index = 0, 40 do
				local value = OccupantTellRules.chasePulse(settled + index * 0.05, nil)
				expect(value >= OccupantConstants.CHASE_FLOOR - 1e-6 and value <= 1).to.equal(true)
			end
			-- Full on the beat.
			local beat = math.ceil(settled / OccupantConstants.CHASE_BEAT) * OccupantConstants.CHASE_BEAT
			expect(OccupantTellRules.chasePulse(beat, nil)).to.be.near(1, 1e-6)
		end)

		it("fades out over CHASE_FADE once the chase ends", function()
			local at = 3 * OccupantConstants.CHASE_BEAT
			local held = OccupantTellRules.chasePulse(at, nil)
			local fading = OccupantTellRules.chasePulse(at, OccupantConstants.CHASE_FADE / 2)
			expect(fading < held).to.equal(true)
			expect(fading > 0).to.equal(true)
			expect(OccupantTellRules.chasePulse(at, OccupantConstants.CHASE_FADE)).to.equal(0)
			expect(OccupantTellRules.chasePulse(at, 99)).to.equal(0)
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

	describe("chase music", function()
		it("fades the intensity-2 stems in as he closes", function()
			local near, far = OccupantConstants.CHASE_LAYER_NEAR, OccupantConstants.CHASE_LAYER_FAR
			expect(OccupantTellRules.chaseLayer(far + 5)).to.equal(0)
			expect(OccupantTellRules.chaseLayer(far)).to.equal(0)
			expect(OccupantTellRules.chaseLayer((near + far) / 2)).to.be.near(0.5, 1e-9)
			expect(OccupantTellRules.chaseLayer(near)).to.equal(1)
			expect(OccupantTellRules.chaseLayer(0)).to.equal(1)
		end)

		it("moves a layer toward its target no faster than CHASE_LAYER_SECONDS allows", function()
			local step = 0.1 / OccupantConstants.CHASE_LAYER_SECONDS
			expect(OccupantTellRules.easeLayer(0, 1, 0.1)).to.be.near(step, 1e-9)
			expect(OccupantTellRules.easeLayer(1, 0, 0.1)).to.be.near(1 - step, 1e-9)
			expect(OccupantTellRules.easeLayer(0.5, 0.52, 0.1)).to.be.near(0.52, 1e-9)
			expect(OccupantTellRules.easeLayer(0.3, 0.3, 0.1)).to.equal(0.3)
		end)
	end)

	describe("desk sounds", function()
		it("hears him sit when he reaches the chair and starts typing", function()
			expect(OccupantTellRules.sat("toDesk", "type")).to.equal(true)
			expect(OccupantTellRules.sat("type", "type")).to.equal(false)
			expect(OccupantTellRules.sat("tipBack", "typeMore")).to.equal(false)
			expect(OccupantTellRules.sat("", "type")).to.equal(false)
		end)

		it("hears his chair swivel as he rises out of the ambush", function()
			expect(OccupantTellRules.rose("ambush", "")).to.equal(true)
			expect(OccupantTellRules.rose("ambush", "approach")).to.equal(true)
			expect(OccupantTellRules.rose("ambush", "ambush")).to.equal(false)
			expect(OccupantTellRules.rose("type", "ambush")).to.equal(false)
		end)
	end)
end
