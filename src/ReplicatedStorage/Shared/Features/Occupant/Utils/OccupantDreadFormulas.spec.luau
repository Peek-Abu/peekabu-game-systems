local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantDreadFormulas = require(script.Parent.OccupantDreadFormulas)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local DREAD = OccupantConstants.DREAD
local ME = 7

local function input(extra)
	local value = {
		active = true,
		spectating = false,
		mode = "patrol",
		phase = "",
		target = 0,
		me = ME,
		proximity = 0.5,
		crew = 0,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("proximity", function()
		it("is 0 from RANGE_FAR out and 1 within RANGE_FULL in clear sight", function()
			expect(OccupantDreadFormulas.proximity(DREAD.RANGE_FAR + 1, 1)).to.equal(0)
			expect(OccupantDreadFormulas.proximity(DREAD.RANGE_FAR, 1)).to.equal(0)
			expect(OccupantDreadFormulas.proximity(DREAD.RANGE_FULL, 1)).to.equal(1)
			expect(OccupantDreadFormulas.proximity(0, 1)).to.equal(1)
			local middle = (DREAD.RANGE_FAR + DREAD.RANGE_FULL) / 2
			expect(OccupantDreadFormulas.proximity(middle, 1)).to.be.near(0.5, 1e-9)
		end)

		it("counts him farther with no line of sight", function()
			local seen = OccupantDreadFormulas.proximity(35, 1)
			local hidden = OccupantDreadFormulas.proximity(35, 0)
			local half = OccupantDreadFormulas.proximity(35, 0.5)
			expect(hidden < seen).to.equal(true)
			expect(half > hidden and half < seen).to.equal(true)
			expect(OccupantDreadFormulas.proximity(DREAD.RANGE_FAR / DREAD.OCCLUDED_SCALE + 1, 0)).to.equal(0)
		end)
	end)

	describe("crewWeight", function()
		it("is 1 next to the chased crewmate, CREW_FLOOR at the edge, 0 beyond", function()
			expect(OccupantDreadFormulas.crewWeight(0)).to.equal(1)
			expect(OccupantDreadFormulas.crewWeight(DREAD.CREW_RANGE)).to.be.near(DREAD.CREW_FLOOR, 1e-9)
			expect(OccupantDreadFormulas.crewWeight(DREAD.CREW_RANGE + 1)).to.equal(0)
		end)
	end)

	describe("stage", function()
		it("feels nothing outside a shift, in the hub, or with him far", function()
			expect(OccupantDreadFormulas.stage(input({ active = false }))).to.equal("none")
			expect(OccupantDreadFormulas.stage(input({ proximity = 0 }))).to.equal("none")
			expect(OccupantDreadFormulas.stage(input({ active = false, mode = "chase", target = ME }))).to.equal("none")
		end)

		it("is near while he walks or works unaware, and nothing on his break", function()
			expect(OccupantDreadFormulas.stage(input({ mode = "patrol" }))).to.equal("near")
			expect(OccupantDreadFormulas.stage(input({ mode = "work", phase = "type" }))).to.equal("near")
			expect(OccupantDreadFormulas.stage(input({ mode = "rest" }))).to.equal("none")
			expect(OccupantDreadFormulas.stage(input({ mode = nil }))).to.equal("none")
		end)

		it("is aware while he hunts, stares or turns on you", function()
			for _, mode in { "investigate", "search", "stare" } do
				expect(OccupantDreadFormulas.stage(input({ mode = mode }))).to.equal("aware")
			end
			expect(OccupantDreadFormulas.stage(input({ mode = "chase", target = 99 }))).to.equal("aware")
			expect(OccupantDreadFormulas.stage(input({ mode = "work", phase = "ambush", target = ME }))).to.equal(
				"aware"
			)
		end)

		it("is the chase while he chases you, however far he is", function()
			expect(OccupantDreadFormulas.stage(input({ mode = "chase", target = ME }))).to.equal("chase")
			expect(OccupantDreadFormulas.stage(input({ mode = "chase", target = ME, proximity = 0 }))).to.equal("chase")
		end)

		it("lets go while he is catching you (the jumpscare owns the screen)", function()
			expect(OccupantDreadFormulas.stage(input({ mode = "catch", target = ME }))).to.equal("none")
		end)

		it("gives the crew look when a chased crewmate is near and he is not", function()
			expect(OccupantDreadFormulas.stage(input({ mode = "chase", target = 99, proximity = 0, crew = 0.6 }))).to.equal(
				"crew"
			)
			expect(OccupantDreadFormulas.stage(input({ mode = "chase", target = 99, proximity = 0, crew = 0 }))).to.equal(
				"none"
			)
		end)

		it("gives a spectator only the crew look", function()
			expect(OccupantDreadFormulas.stage(input({ spectating = true, mode = "patrol" }))).to.equal("none")
			expect(OccupantDreadFormulas.stage(input({ spectating = true, mode = "chase", target = 99, crew = 1 }))).to.equal(
				"crew"
			)
		end)
	end)

	describe("target", function()
		it("is all zero for none", function()
			local look = OccupantDreadFormulas.target("none", 1, 1, 1, false)
			for _, value in look do
				expect(value).to.equal(0)
			end
		end)

		it("scales the near look by proximity", function()
			local half = OccupantDreadFormulas.target("near", 0.5, 0, 0, false)
			expect(half.vignette).to.be.near(DREAD.LOOKS.near.vignette * 0.5, 1e-9)
			expect(half.heart).to.be.near(DREAD.LOOKS.near.heart * 0.5, 1e-9)
			expect(half.duck).to.be.near(DREAD.LOOKS.near.duck * 0.5, 1e-9)
		end)

		it("escalates near < aware < chase", function()
			local near = OccupantDreadFormulas.target("near", 1, 0, 0, false)
			local aware = OccupantDreadFormulas.target("aware", 1, 0, 0, false)
			local chase = OccupantDreadFormulas.target("chase", 1, 1, 0, false)
			for _, key in { "heart", "vignette", "red", "grain" } do
				expect(aware[key] > near[key]).to.equal(true)
				expect(chase[key] > aware[key]).to.equal(true)
			end
			expect(chase.duck < aware.duck).to.equal(true)
			expect(chase.squeeze > 0).to.equal(true)
			expect(near.squeeze).to.equal(0)
		end)

		it("never shows aware weaker than AWARE_FLOOR", function()
			local far = OccupantDreadFormulas.target("aware", 0.1, 0, 0, false)
			expect(far.vignette).to.be.near(DREAD.LOOKS.aware.vignette * DREAD.AWARE_FLOOR, 1e-9)
		end)

		it("closes the chase in as he closes: tighter, more muffled, narrower", function()
			local far = OccupantDreadFormulas.target("chase", 0, 0, 0, false)
			local near = OccupantDreadFormulas.target("chase", 0, 1, 0, false)
			expect(far.squeeze).to.equal(DREAD.LOOKS.chaseFar.squeeze)
			expect(near.squeeze).to.equal(DREAD.LOOKS.chaseNear.squeeze)
			expect(near.muffle < far.muffle).to.equal(true)
			expect(near.vignette > far.vignette).to.equal(true)
		end)

		it("hands the chase's sound to the music: no dread loop in a chase", function()
			expect(OccupantDreadFormulas.target("chase", 1, 1, 0, false).dread).to.equal(0)
		end)

		it("weights the crew look and keeps it lighter than the chase", function()
			local crew = OccupantDreadFormulas.target("crew", 0, 0, 1, false)
			local chase = OccupantDreadFormulas.target("chase", 0, 0, 0, false)
			expect(crew.vignette < chase.vignette).to.equal(true)
			expect(crew.heart < chase.heart).to.equal(true)
			expect(crew.squeeze).to.equal(0)
			local half = OccupantDreadFormulas.target("crew", 0, 0, 0.5, false)
			expect(half.vignette).to.be.near(crew.vignette * 0.5, 1e-9)
		end)

		it("hiding near him: the heart loud, the world muffled", function()
			local open = OccupantDreadFormulas.target("near", 0.3, 0, 0, false)
			local hid = OccupantDreadFormulas.target("near", 0.3, 0, 0, true)
			expect(hid.heart).to.equal(DREAD.HIDDEN_HEART)
			expect(hid.muffle <= DREAD.HIDDEN_MUFFLE).to.equal(true)
			expect(hid.duck <= DREAD.HIDDEN_DUCK).to.equal(true)
			expect(hid.vignette).to.be.near(open.vignette + DREAD.HIDDEN_VIGNETTE, 1e-9)
			-- Hiding with him far away changes nothing.
			local away = OccupantDreadFormulas.target("none", 0, 0, 0, true)
			expect(away.heart).to.equal(0)
		end)

		it("stays kid-safe: vignette and grain never exceed 1", function()
			local look = OccupantDreadFormulas.target("chase", 1, 1, 0, true)
			expect(look.vignette <= 1).to.equal(true)
			expect(look.grain <= 1).to.equal(true)
		end)
	end)

	describe("ease", function()
		it("moves toward the target, rising faster than it falls", function()
			local zero = OccupantDreadFormulas.ZERO
			local full = OccupantDreadFormulas.target("aware", 1, 0, 0, false)
			local up = OccupantDreadFormulas.ease(zero, full, 0.1)
			local down = OccupantDreadFormulas.ease(full, zero, 0.1)
			expect(up.vignette > 0 and up.vignette < full.vignette).to.equal(true)
			local rose = up.vignette / full.vignette
			local fell = 1 - down.vignette / full.vignette
			expect(rose > fell).to.equal(true)
			expect(up.duck < 0 and up.duck > full.duck).to.equal(true)
		end)

		it("settles on the target", function()
			local full = OccupantDreadFormulas.target("near", 1, 0, 0, false)
			local look = OccupantDreadFormulas.ZERO
			for _ = 1, 400 do
				look = OccupantDreadFormulas.ease(look, full, 1 / 30)
			end
			expect(look.vignette).to.be.near(full.vignette, 1e-3)
		end)
	end)

	describe("reduce", function()
		it("drops the squeeze and the edge fringe with reduce motion", function()
			local look = OccupantDreadFormulas.target("chase", 1, 1, 0, false)
			local reduced = OccupantDreadFormulas.reduce(look, true)
			expect(reduced.squeeze).to.equal(0)
			expect(reduced.edge).to.equal(0)
			expect(reduced.vignette).to.equal(look.vignette)
			expect(OccupantDreadFormulas.reduce(look, false)).to.equal(look)
		end)
	end)

	describe("heartbeat", function()
		it("speeds up as he closes while he is unaware", function()
			local far = OccupantDreadFormulas.beatPeriod("near", 0)
			local close = OccupantDreadFormulas.beatPeriod("near", 1)
			expect(far).to.be.near(DREAD.BEAT_NEAR_SLOW, 1e-9)
			expect(close).to.be.near(DREAD.BEAT_NEAR_FAST, 1e-9)
		end)

		it("beats faster aware than near; the chase follows the music, none is silent", function()
			expect(OccupantDreadFormulas.beatPeriod("aware", 0.2) < DREAD.BEAT_NEAR_FAST).to.equal(true)
			expect(OccupantDreadFormulas.beatPeriod("crew", 0)).to.equal(DREAD.BEAT_CREW)
			expect(OccupantDreadFormulas.beatPeriod("chase", 1)).to.equal(nil)
			expect(OccupantDreadFormulas.beatPeriod("none", 1)).to.equal(nil)
		end)

		it("pulses full on the beat and is gone PULSE_WIDTH of the way to the next", function()
			expect(OccupantDreadFormulas.pulse(0, 1)).to.equal(1)
			expect(OccupantDreadFormulas.pulse(DREAD.PULSE_WIDTH, 1)).to.equal(0)
			expect(OccupantDreadFormulas.pulse(0.9, 1)).to.equal(0)
			local early = OccupantDreadFormulas.pulse(0.1, 1)
			local later = OccupantDreadFormulas.pulse(0.3, 1)
			expect(early > later and later > 0).to.equal(true)
		end)

		it("counts the music's beats from the stems' position", function()
			local beat = OccupantConstants.CHASE_BEAT
			expect(OccupantDreadFormulas.musicBeat(0)).to.equal(0)
			expect(OccupantDreadFormulas.musicBeat(beat * 0.99)).to.equal(0)
			expect(OccupantDreadFormulas.musicBeat(beat * 1.01)).to.equal(1)
			expect(OccupantDreadFormulas.musicBeat(beat * 5.5)).to.equal(5)
		end)
	end)

	describe("footfallTrauma", function()
		it("shakes on his steps only while he sees or chases you, close", function()
			expect(OccupantDreadFormulas.footfallTrauma("chase", 0)).to.be.near(DREAD.SHAKE_TRAUMA, 1e-9)
			expect(OccupantDreadFormulas.footfallTrauma("aware", DREAD.SHAKE_RANGE / 2)).to.be.near(
				DREAD.SHAKE_TRAUMA / 2,
				1e-9
			)
			expect(OccupantDreadFormulas.footfallTrauma("chase", DREAD.SHAKE_RANGE + 1)).to.equal(0)
			expect(OccupantDreadFormulas.footfallTrauma("near", 2)).to.equal(0)
			expect(OccupantDreadFormulas.footfallTrauma("crew", 2)).to.equal(0)
			expect(OccupantDreadFormulas.footfallTrauma("none", 2)).to.equal(0)
		end)
	end)

	describe("eq", function()
		it("ducks every band and muffles the highs, the mids by MUFFLE_MID", function()
			local low, mid, high = OccupantDreadFormulas.eq(-6, -20)
			expect(low).to.equal(-6)
			expect(mid).to.be.near(-6 - 20 * DREAD.MUFFLE_MID, 1e-9)
			expect(high).to.equal(-26)
			local a, b, c = OccupantDreadFormulas.eq(0, 0)
			expect(a == 0 and b == 0 and c == 0).to.equal(true)
		end)
	end)
end
