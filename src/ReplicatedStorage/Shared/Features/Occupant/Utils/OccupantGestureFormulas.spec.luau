local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantGestureFormulas = require(script.Parent.OccupantGestureFormulas)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local function near(a, b)
	return a:ToObjectSpace(b).Position.Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.9999
end

return function()
	describe("gestureFor", function()
		it("swivels while his head is turned to an ambush point", function()
			expect(OccupantGestureFormulas.gestureFor("work", "ambush", true, false, false)).to.equal("swivel")
			expect(OccupantGestureFormulas.gestureFor("chase", nil, true, false, false)).to.equal("swivel")
		end)
		it("tips under the desk in a sit-in and peeks in a stare's check", function()
			expect(OccupantGestureFormulas.gestureFor("work", "tip", false, true, false)).to.equal("under")
			expect(OccupantGestureFormulas.gestureFor("work", "tipHold", false, true, false)).to.equal("under")
			expect(OccupantGestureFormulas.gestureFor("work", "tipBack", false, true, false)).to.equal("")
			expect(OccupantGestureFormulas.gestureFor("stare", "check", false, false, true)).to.equal("peek")
			expect(OccupantGestureFormulas.gestureFor("stare", "hold", false, false, true)).to.equal("")
		end)
		it("mirrors the check from the spot's other side, through its catch too", function()
			expect(OccupantGestureFormulas.gestureFor("stare", "check", false, false, true, true)).to.equal(
				"peekMirror"
			)
			expect(OccupantGestureFormulas.gestureFor("catch", nil, false, false, true, true)).to.equal("peekMirror")
			expect(OccupantGestureFormulas.gestureFor("stare", "check", false, false, true, false)).to.equal("peek")
			local mirror = C.GESTURES.peekMirror.joints.Neck
			local plain = C.GESTURES.peek.joints.Neck
			expect(mirror.Z).to.equal(-plain.Z)
			expect(mirror.X).to.equal(plain.X)
		end)

		it("keeps the pose through a catch made from it", function()
			expect(OccupantGestureFormulas.gestureFor("catch", nil, false, true, false)).to.equal("under")
			expect(OccupantGestureFormulas.gestureFor("catch", nil, false, false, true)).to.equal("peek")
			expect(OccupantGestureFormulas.gestureFor("catch", nil, false, false, false)).to.equal("")
		end)
	end)

	describe("pose", function()
		it("names no joints for no gesture", function()
			expect(next(OccupantGestureFormulas.pose("", 0))).to.equal(nil)
		end)
		it("turns the neck by the yaw for a swivel", function()
			local pose = OccupantGestureFormulas.pose("swivel", math.pi / 2)
			expect(near(pose.Neck, CFrame.Angles(0, math.pi / 2, 0))).to.equal(true)
		end)
		it("uses the authored joints for a peek", function()
			local pose = OccupantGestureFormulas.pose("peek", 0)
			local waist = C.GESTURES.peek.joints.Waist
			expect(near(pose.Waist, CFrame.Angles(math.rad(waist.X), math.rad(waist.Y), math.rad(waist.Z)))).to.equal(
				true
			)
		end)
	end)

	describe("progress", function()
		it("eases from 0 to 1 over the gesture's seconds", function()
			expect(OccupantGestureFormulas.progress("peek", 0)).to.equal(0)
			expect(OccupantGestureFormulas.progress("peek", C.GESTURES.peek.seconds)).to.equal(1)
			local half = OccupantGestureFormulas.progress("peek", C.GESTURES.peek.seconds / 2)
			expect(half > 0.5 and half < 1).to.equal(true)
		end)
		it("lets go over GESTURE_RELEASE", function()
			expect(OccupantGestureFormulas.progress("", C.GESTURE_RELEASE)).to.equal(1)
		end)
	end)

	describe("blend", function()
		it("goes from one pose to the other, joints missing on a side counting as still", function()
			local from = { Neck = CFrame.Angles(0, 1, 0) }
			local to = { Waist = CFrame.Angles(-1, 0, 0) }
			local start = OccupantGestureFormulas.blend(from, to, 0)
			expect(near(start.Neck, from.Neck)).to.equal(true)
			expect(near(start.Waist, CFrame.identity)).to.equal(true)
			local finish = OccupantGestureFormulas.blend(from, to, 1)
			expect(near(finish.Neck, CFrame.identity)).to.equal(true)
			expect(near(finish.Waist, to.Waist)).to.equal(true)
		end)
	end)

	describe("along (a keyed path)", function()
		local KEYS = {
			{ at = 0.25, back = 2, joints = {} },
			{ at = 0.75, back = 2, joints = { Waist = Vector3.new(-90, 0, 0) } },
			{ at = 1, back = 0.5, joints = { Waist = Vector3.new(-90, 0, 0) } },
		}

		it("starts at rest and reaches each key at its time", function()
			local start, startBack = OccupantGestureFormulas.along(KEYS, 0)
			expect(startBack).to.equal(0)
			expect(start.Waist).to.equal(nil)
			local first, firstBack = OccupantGestureFormulas.along(KEYS, 0.25)
			expect(firstBack).to.be.near(2)
			expect(first.Waist).to.equal(nil)
			local second, secondBack = OccupantGestureFormulas.along(KEYS, 0.75)
			expect(secondBack).to.be.near(2)
			expect(near(second.Waist, CFrame.Angles(math.rad(-90), 0, 0))).to.equal(true)
			local _, lastBack = OccupantGestureFormulas.along(KEYS, 1)
			expect(lastBack).to.be.near(0.5)
		end)

		it("keeps the fold out of the first leg: he draws back before he bends", function()
			local mid, back = OccupantGestureFormulas.along(KEYS, 0.2)
			expect(mid.Waist).to.equal(nil)
			expect(back > 0 and back < 2).to.equal(true)
		end)

		it("holds the last key past the end, and starts from a given waypoint", function()
			local _, back = OccupantGestureFormulas.along(KEYS, 3)
			expect(back).to.be.near(0.5)
			local _, from = OccupantGestureFormulas.along(KEYS, 0, { back = 1, joints = {} })
			expect(from).to.be.near(1)
		end)

		it("keys the peek and the sit-in, both ending at their authored fold", function()
			for _, name in { "peek", "under" } do
				local keys, seconds = OccupantGestureFormulas.keyed(name)
				expect(keys).to.be.ok()
				expect(seconds).to.equal(C.GESTURES[name].seconds)
				local final = OccupantGestureFormulas.along(keys, 1)
				local waist = C.GESTURES[name].joints.Waist
				expect(near(final.Waist, CFrame.Angles(math.rad(waist.X), math.rad(waist.Y), math.rad(waist.Z)))).to.equal(
					true
				)
			end
			expect(OccupantGestureFormulas.keyed("swivel")).to.equal(nil)
		end)

		it("leaves a keyed gesture by its exit path, from its last key back to rest", function()
			local keys, seconds, start = OccupantGestureFormulas.exit("under")
			expect(keys).to.be.ok()
			expect(seconds).to.equal(C.GESTURES.under.exitSeconds)
			expect(start.back).to.equal(C.GESTURES.under.keys[#C.GESTURES.under.keys].back)
			local rest, back = OccupantGestureFormulas.along(keys, 1, start)
			expect(back).to.be.near(0)
			expect(next(rest)).to.equal(nil)
			expect(OccupantGestureFormulas.exit("swivel")).to.equal(nil)
			expect(OccupantGestureFormulas.exit("")).to.equal(nil)
		end)
	end)

	describe("overlaps", function()
		local function box(x, y, z, size)
			return { cframe = CFrame.new(x, y, z), size = size or Vector3.one * 2 }
		end
		it("meets boxes that interpenetrate, not ones that only touch or stand apart", function()
			expect(OccupantGestureFormulas.overlaps(box(0, 0, 0), box(1, 0, 0), 0.05)).to.equal(true)
			expect(OccupantGestureFormulas.overlaps(box(0, 0, 0), box(2, 0, 0), 0.05)).to.equal(false)
			expect(OccupantGestureFormulas.overlaps(box(0, 0, 0), box(5, 0, 0), 0)).to.equal(false)
		end)
		it("sees a turned box miss a corner it would hit unturned", function()
			local turned =
				{ cframe = CFrame.new(2.9, 2.9, 0) * CFrame.Angles(0, 0, math.rad(45)), size = Vector3.one * 2 }
			expect(OccupantGestureFormulas.overlaps(box(0, 0, 0, Vector3.one * 4), turned, 0)).to.equal(false)
			expect(OccupantGestureFormulas.overlaps(box(0, 0, 0, Vector3.one * 4), box(2.6, 2.6, 0), 0)).to.equal(true)
		end)
	end)

	describe("yawTo", function()
		it("is 0 straight ahead and turns toward a target to the side or behind", function()
			local torso = CFrame.new()
			expect(OccupantGestureFormulas.yawTo(torso, Vector3.new(0, 0, -10))).to.be.near(0)
			expect(math.abs(OccupantGestureFormulas.yawTo(torso, Vector3.new(0, 0, 10)))).to.be.near(math.pi)
			-- A target on his left (-X): a positive turn about Y brings -Z round to -X.
			expect(OccupantGestureFormulas.yawTo(torso, Vector3.new(-10, 0, 0))).to.be.near(math.pi / 2)
		end)
	end)

	describe("tilt", function()
		it("rolls the head to TILT_DEGREES", function()
			local tilt = OccupantGestureFormulas.tilt(C.TILT_SECONDS, false)
			local _, _, roll = tilt:ToEulerAnglesXYZ()
			expect(math.deg(roll)).to.be.near(C.TILT_DEGREES, 0.01)
		end)
		it("starts level", function()
			expect(near(OccupantGestureFormulas.tilt(0, false), CFrame.identity)).to.equal(true)
		end)
	end)

	describe("the slow turns (behaviours design §11)", function()
		it("turns slowly through the slow turn and the stare, and whips through the jerk", function()
			expect(OccupantGestureFormulas.gestureFor("alert", "slowTurn", true, false, false)).to.equal("slowSwivel")
			expect(OccupantGestureFormulas.gestureFor("work", "slowTurn", true, false, false)).to.equal("slowSwivel")
			expect(OccupantGestureFormulas.gestureFor("alert", "staring", true, false, false)).to.equal("slowSwivel")
			expect(OccupantGestureFormulas.gestureFor("chase", "jerk", true, false, false)).to.equal("whip")
			expect(OccupantGestureFormulas.gestureFor("chase", "jerk", false, false, false)).to.equal("")
		end)

		it("carries one turn fraction across the slow swivel and the whip", function()
			expect(OccupantGestureFormulas.turning("slowSwivel")).to.equal(true)
			expect(OccupantGestureFormulas.turning("whip")).to.equal(true)
			expect(OccupantGestureFormulas.turning("swivel")).to.equal(false)
			expect(OccupantGestureFormulas.advance(0, "slowSwivel", C.SLOW_TURN_SECONDS / 2)).to.be.near(0.5)
			expect(OccupantGestureFormulas.advance(0.5, "whip", C.WHIP_SECONDS / 2)).to.be.near(1)
			expect(OccupantGestureFormulas.advance(0.9, "slowSwivel", 10)).to.equal(1)
		end)

		it("turns the head all the way by the end, the waist leading so the smile comes round last", function()
			local total = math.rad(170)
			local function yaws(turned)
				local pose = OccupantGestureFormulas.turnPose(total, turned)
				local _, waist = (pose.Waist or CFrame.identity):ToOrientation()
				local _, neck = (pose.Neck or CFrame.identity):ToOrientation()
				return waist, neck
			end
			local w0, n0 = yaws(0)
			expect(math.abs(w0) + math.abs(n0) < 1e-6).to.equal(true)
			local w1, n1 = yaws(1)
			expect(w1).to.be.near(total * C.SLOW_WAIST_SHARE, 1e-4)
			expect(w1 + n1).to.be.near(total, 1e-4)
			local wLead, _ = yaws(C.SLOW_WAIST_LEAD)
			expect(wLead).to.be.near(total * C.SLOW_WAIST_SHARE, 1e-4)
			local wEarly, nEarly = yaws(0.3)
			expect(wEarly / (wEarly + nEarly) > C.SLOW_WAIST_SHARE).to.equal(true)
			local wHalf, nHalf = yaws(0.5)
			expect(wHalf + nHalf).to.be.near(total * 0.5, 1e-4)
		end)
	end)
end
