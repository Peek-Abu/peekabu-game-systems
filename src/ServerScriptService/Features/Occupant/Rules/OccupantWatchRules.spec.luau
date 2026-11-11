local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantWatchRules = require(script.Parent.OccupantWatchRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- The monster stands 30 studs down +Z from the crew member, its head, chest and knees.
local HEAD = Vector3.new(0, 8, 30)
local CHEST = Vector3.new(0, 5, 30)
local KNEES = Vector3.new(0, 1.5, 30)

-- A crew member at the origin (head at y 5), camera 8 studs behind the head looking at the monster's chest, a report
-- received at 100, every ray clear; `extra` overrides any field.
local function viewer(extra)
	local camera = Vector3.new(0, 7, -8)
	local value = {
		alive = true,
		downed = false,
		hidden = false,
		inTruck = false,
		head = Vector3.new(0, 5, 0),
		report = { position = camera, look = (CHEST - camera).Unit, receivedAt = 100 },
		cameraClear = true,
		sightlines = {
			{ point = HEAD, clear = true },
			{ point = CHEST, clear = true },
			{ point = KNEES, clear = true },
		},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function lines(head, chest, knees)
	return {
		{ point = HEAD, clear = head },
		{ point = CHEST, clear = chest },
		{ point = KNEES, clear = knees },
	}
end

return function()
	describe("watching", function()
		it("counts a crew member who looks straight at it with a clear line", function()
			expect(OccupantWatchRules.watching(viewer(), 100.1)).to.equal(true)
		end)

		it("never counts someone dead, knocked down, hidden (even peeking) or in the truck", function()
			expect(OccupantWatchRules.watching(viewer({ alive = false }), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer({ downed = true }), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer({ hidden = true }), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer({ inTruck = true }), 100.1)).to.equal(false)
		end)

		it("needs a camera report", function()
			local v = viewer()
			v.report = nil
			expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
		end)

		it("drops a stale report (0.3 s old or more)", function()
			expect(OccupantWatchRules.watching(viewer(), 100 + C.FREEZE_REPORT_FRESH - 0.01)).to.equal(true)
			expect(OccupantWatchRules.watching(viewer(), 100 + C.FREEZE_REPORT_FRESH)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer(), 101)).to.equal(false)
		end)

		it("refuses a forged camera far from the head", function()
			local far = Vector3.new(0, 7, 20)
			local v = viewer({ report = { position = far, look = (CHEST - far).Unit, receivedAt = 100 } })
			expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
			local edge = Vector3.new(0, 5, -C.FREEZE_CAMERA_RANGE)
			local ok = viewer({ report = { position = edge, look = (CHEST - edge).Unit, receivedAt = 100 } })
			expect(OccupantWatchRules.watching(ok, 100.1)).to.equal(true)
		end)

		it("refuses a camera through a wall (the head-to-camera line is blocked)", function()
			expect(OccupantWatchRules.watching(viewer({ cameraClear = false }), 100.1)).to.equal(false)
		end)

		it("needs the camera to look within 35 degrees of it", function()
			local camera = Vector3.new(0, 7, -8)
			local toChest = (CHEST - camera).Unit
			local function turned(degrees)
				local look = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(toChest)
				return viewer({ report = { position = camera, look = look, receivedAt = 100 } })
			end
			expect(OccupantWatchRules.watching(turned(C.FREEZE_CONE - 6), 100.1)).to.equal(true)
			expect(OccupantWatchRules.watching(turned(60), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(turned(180), 100.1)).to.equal(false)
		end)

		it("refuses a zero or broken look direction", function()
			local camera = Vector3.new(0, 7, -8)
			local v = viewer({ report = { position = camera, look = Vector3.zero, receivedAt = 100 } })
			expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
		end)

		it("counts any one clear ray to its head, chest or knees", function()
			expect(OccupantWatchRules.watching(viewer({ sightlines = lines(true, false, false) }), 100.1)).to.equal(
				true
			)
			expect(OccupantWatchRules.watching(viewer({ sightlines = lines(false, false, true) }), 100.1)).to.equal(
				true
			)
			expect(OccupantWatchRules.watching(viewer({ sightlines = lines(false, false, false) }), 100.1)).to.equal(
				false
			)
		end)

		it(
			"needs a clear ray to a point inside the cone (a clear point behind the camera's view does not count)",
			function()
				local camera = Vector3.new(0, 7, -8)
				local behind = Vector3.new(0, 5, -40)
				local v = viewer({
					report = { position = camera, look = (CHEST - camera).Unit, receivedAt = 100 },
					sightlines = { { point = behind, clear = true }, { point = CHEST, clear = false } },
				})
				expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
			end
		)

		it("caps sight at 80 studs from the camera", function()
			local camera = Vector3.new(0, 7, -8)
			local near = Vector3.new(0, 5, -8 + C.FREEZE_RANGE - 1)
			local far = Vector3.new(0, 5, -8 + C.FREEZE_RANGE + 1)
			local function at(point)
				return viewer({
					report = { position = camera, look = (point - camera).Unit, receivedAt = 100 },
					sightlines = { { point = point, clear = true } },
				})
			end
			expect(OccupantWatchRules.watching(at(near), 100.1)).to.equal(true)
			expect(OccupantWatchRules.watching(at(far), 100.1)).to.equal(false)
		end)
	end)

	describe("the pieces", function()
		it("fresh: under 0.3 s, never without a report", function()
			expect(OccupantWatchRules.fresh({ position = Vector3.zero, look = Vector3.zAxis, receivedAt = 5 }, 5.29)).to.equal(
				true
			)
			expect(OccupantWatchRules.fresh(nil, 5)).to.equal(false)
		end)

		it("cameraNear: within 16 studs of the head", function()
			expect(OccupantWatchRules.cameraNear(Vector3.zero, Vector3.new(0, 0, 16))).to.equal(true)
			expect(OccupantWatchRules.cameraNear(Vector3.zero, Vector3.new(0, 0, 16.5))).to.equal(false)
		end)

		it("inCone: within 35 degrees of the look", function()
			expect(OccupantWatchRules.inCone(Vector3.zero, Vector3.zAxis, Vector3.new(0, 0, 10))).to.equal(true)
			expect(OccupantWatchRules.inCone(Vector3.zero, Vector3.zAxis, Vector3.new(10, 0, 10))).to.equal(false)
			expect(OccupantWatchRules.inCone(Vector3.zero, Vector3.zAxis, Vector3.new(5, 0, 10))).to.equal(true)
			expect(OccupantWatchRules.inCone(Vector3.zero, Vector3.zAxis, Vector3.zero)).to.equal(false)
		end)

		it("eligible: alive, standing, not hiding and outside the truck", function()
			expect(OccupantWatchRules.eligible(viewer())).to.equal(true)
			expect(OccupantWatchRules.eligible(viewer({ hidden = true }))).to.equal(false)
		end)
	end)

	describe("the freeze", function()
		it("starts unfrozen, never unfrozen before", function()
			local state = OccupantWatchRules.newFreeze()
			expect(state.frozen).to.equal(false)
			expect(state.unfrozenAt).to.equal(nil)
		end)

		it("freezes at once when someone watches, remembering when", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			expect(state.frozen).to.equal(true)
			expect(state.frozenAt).to.equal(10)
			local still = OccupantWatchRules.advance(state, true, 12)
			expect(still.frozenAt).to.equal(10)
		end)

		it("holds 0.4 s after the last watcher looks away, then unfreezes", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			local beat = OccupantWatchRules.advance(state, false, 10 + C.FREEZE_UNFREEZE_BEAT - 0.05)
			expect(beat.frozen).to.equal(true)
			local free = OccupantWatchRules.advance(beat, false, 10 + C.FREEZE_UNFREEZE_BEAT)
			expect(free.frozen).to.equal(false)
			expect(free.unfrozenAt).to.equal(10 + C.FREEZE_UNFREEZE_BEAT)
			expect(free.frozenAt).to.equal(nil)
		end)

		it("a glance back inside the beat keeps it frozen and restarts the beat", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			local away = OccupantWatchRules.advance(state, false, 10.3)
			local back = OccupantWatchRules.advance(away, true, 10.35)
			local again = OccupantWatchRules.advance(back, false, 10.6)
			expect(again.frozen).to.equal(true)
			expect(again.frozenAt).to.equal(10)
			local free = OccupantWatchRules.advance(again, false, 10.35 + C.FREEZE_UNFREEZE_BEAT)
			expect(free.frozen).to.equal(false)
		end)

		it("stays unfrozen while nobody watches", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), false, 10)
			expect(state.frozen).to.equal(false)
			expect(state.unfrozenAt).to.equal(nil)
		end)

		it("never changes the state it is given", function()
			local state = OccupantWatchRules.newFreeze()
			OccupantWatchRules.advance(state, true, 10)
			expect(state.frozen).to.equal(false)
		end)
	end)

	describe("the catch block", function()
		it("allows a catch when it was never frozen", function()
			expect(OccupantWatchRules.canCatch(OccupantWatchRules.newFreeze(), 10)).to.equal(true)
		end)

		it("never while frozen", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			expect(OccupantWatchRules.canCatch(state, 10)).to.equal(false)
		end)

		it("not for 0.6 s after unfreezing, then again", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			local free = OccupantWatchRules.advance(state, false, 10.4)
			expect(OccupantWatchRules.canCatch(free, 10.4 + C.FREEZE_CATCH_BLOCK - 0.05)).to.equal(false)
			expect(OccupantWatchRules.canCatch(free, 10.4 + C.FREEZE_CATCH_BLOCK)).to.equal(true)
		end)
	end)
end
