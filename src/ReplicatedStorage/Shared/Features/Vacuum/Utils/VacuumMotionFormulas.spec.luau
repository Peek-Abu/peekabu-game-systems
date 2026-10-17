local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumMotionFormulas = require(script.Parent.VacuumMotionFormulas)
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)

return function()
	-- A Pippa-like hold in root space: the right hand's wand point 0.6 up and 0.9 forward, the floor head's bottom
	-- 0.06 over a floor 1.375 below the root, out in front of and below the hand.
	local PIVOT = Vector3.new(0.3, 0.6, -0.9)
	local FLOOR = -1.375
	local HEAD_Y = FLOOR + 0.06
	local REST = {
		pivot = PIVOT,
		floorY = FLOOR,
		corners = {
			Vector3.new(-0.9, HEAD_Y, -2.0),
			Vector3.new(0.3, HEAD_Y, -2.0),
			Vector3.new(-0.9, HEAD_Y, -1.75),
			Vector3.new(0.3, HEAD_Y, -1.75),
		},
	}
	local NONE = { offset = Vector3.zero, pitch = 0, yaw = 0, roll = 0 }
	-- A layers' state: every layer off but those given.
	local function layers(given)
		local all =
			{ raise = 0, reach = 0, brace = 0, kick = 0, shimmyYaw = 0, shimmyRoll = 0, swayYaw = 0, swayPitch = 0 }
		for key, value in given do
			all[key] = value
		end
		return all
	end
	local MARGIN = Constants.floorMargin

	local function lowest(transform)
		local y = math.huge
		for _, corner in REST.corners do
			y = math.min(y, (transform * corner).Y)
		end
		return y
	end

	describe("step", function()
		it("settles a critically damped spring on its target without overshoot", function()
			local x, v, peak = 0, 0, 0
			for _ = 1, 120 do
				x, v = VacuumMotionFormulas.step(x, v, 1, 1 / 60, 3, 1)
				peak = math.max(peak, x)
			end
			expect(x).to.be.near(1, 1e-3)
			expect(peak <= 1 + 1e-6).to.equal(true)
		end)

		it("overshoots when underdamped", function()
			local x, v, peak = 0, 0, 0
			for _ = 1, 120 do
				x, v = VacuumMotionFormulas.step(x, v, 1, 1 / 60, 3, 0.3)
				peak = math.max(peak, x)
			end
			expect(peak > 1.2).to.equal(true)
		end)

		it("is exact: one big step lands where many small ones do", function()
			local x1, v1 = VacuumMotionFormulas.step(0.3, -2, 1, 0.09, 4, 0.4)
			local x2, v2 = 0.3, -2
			for _ = 1, 90 do
				x2, v2 = VacuumMotionFormulas.step(x2, v2, 1, 0.001, 4, 0.4)
			end
			expect(x1).to.be.near(x2, 1e-6)
			expect(v1).to.be.near(v2, 1e-5)
			-- And for a critically damped and an overdamped one.
			for _, damping in { 1, 1.6 } do
				local a = VacuumMotionFormulas.step(0, 3, 1, 0.08, 2, damping)
				local b, w = 0, 3
				for _ = 1, 80 do
					b, w = VacuumMotionFormulas.step(b, w, 1, 0.001, 2, damping)
				end
				expect(a).to.be.near(b, 1e-6)
			end
		end)

		it("survives a long hitch (advances at most maxStep)", function()
			local x, v = VacuumMotionFormulas.step(0, 0, 1, 5, 3, 1)
			expect(x <= 1 + 1e-6 and x > 0).to.equal(true)
			expect(math.abs(v) < 100).to.equal(true)
		end)
	end)

	describe("aim", function()
		local tuning = Constants.aim

		it("holds the planned pose in the default third-person view", function()
			for _, look in { tuning.deadLow, math.rad(-20), tuning.deadHigh } do
				local raise, reach = VacuumMotionFormulas.aim(look, tuning)
				expect(raise).to.equal(0)
				expect(reach).to.equal(0)
			end
		end)

		it("raises the floor head as the camera looks up, to its most", function()
			local a = VacuumMotionFormulas.aim(math.rad(10), tuning)
			local b = VacuumMotionFormulas.aim(math.rad(30), tuning)
			expect(a > 0 and b > a).to.equal(true)
			expect(VacuumMotionFormulas.aim(math.rad(89), tuning)).to.be.near(tuning.maxUp, 1e-6)
		end)

		it("reaches for the floor as the camera looks down, fully at fullDown", function()
			local _, half = VacuumMotionFormulas.aim((tuning.deadLow + tuning.fullDown) / 2, tuning)
			local _, full = VacuumMotionFormulas.aim(math.rad(-89), tuning)
			expect(half).to.be.near(0.5, 1e-6)
			expect(full).to.equal(1)
		end)
	end)

	describe("encodeAim / decodeAim", function()
		it("quantises the look pitch to a byte and back, in whole quanta of degrees", function()
			local byte = VacuumMotionFormulas.encodeAim(math.rad(-22))
			expect(byte >= 0 and byte <= 36).to.equal(true)
			expect(VacuumMotionFormulas.decodeAim(byte)).to.equal(-20)
			expect(VacuumMotionFormulas.decodeAim(VacuumMotionFormulas.encodeAim(math.rad(90)))).to.equal(90)
			expect(VacuumMotionFormulas.decodeAim(VacuumMotionFormulas.encodeAim(math.rad(-200)))).to.equal(-90)
		end)

		it("refuses anything that is not a byte the client can send", function()
			expect(VacuumMotionFormulas.decodeAim(37)).to.equal(nil)
			expect(VacuumMotionFormulas.decodeAim(-1)).to.equal(nil)
			expect(VacuumMotionFormulas.decodeAim(2.5)).to.equal(nil)
			expect(VacuumMotionFormulas.decodeAim(0 / 0)).to.equal(nil)
		end)
	end)

	describe("wand", function()
		it("is the identity with no layers on (the hands on the planned hold)", function()
			local transform = VacuumMotionFormulas.wand(REST, NONE, MARGIN)
			expect((transform.Position - Vector3.zero).Magnitude < 1e-6).to.equal(true)
			expect(transform.LookVector:Dot(Vector3.new(0, 0, -1))).to.be.near(1, 1e-6)
		end)

		it("turns about the right hand: the pivot stays put, so both grips move with the one rigid wand", function()
			local transform =
				VacuumMotionFormulas.wand(REST, { offset = Vector3.zero, pitch = 0.4, yaw = 0.2, roll = 0.1 }, MARGIN)
			expect(((transform * PIVOT) - PIVOT).Magnitude < 1e-5).to.equal(true)
		end)

		it("raises the floor head off the floor for a positive pitch", function()
			local transform = VacuumMotionFormulas.wand(
				REST,
				{ offset = Vector3.zero, pitch = math.rad(30), yaw = 0, roll = 0 },
				MARGIN
			)
			expect(lowest(transform) > HEAD_Y + 0.3).to.equal(true)
		end)

		it("never lets the floor head under the floor: a dip is flattened out until it just clears", function()
			local down = { offset = Vector3.new(0, -0.3, -0.1), pitch = -0.2, yaw = 0, roll = 0 }
			local transform, pitch = VacuumMotionFormulas.wand(REST, down, MARGIN)
			expect(lowest(transform)).to.be.near(FLOOR + MARGIN, 1e-3)
			-- Flattened (more pitch), the hands still moved down and the head further out in front.
			expect(pitch > -0.2).to.equal(true)
			expect((transform * PIVOT).Y).to.be.near(PIVOT.Y - 0.3, 1e-4)
			local before = (REST.corners[1] + REST.corners[4]) / 2
			expect((transform * before).Z < before.Z).to.equal(true)
		end)

		it("scales every layer back together until the left paw can still reach its grip", function()
			-- GripLower down the wand from the right hand, the left shoulder above and behind it, the arm just long enough.
			local at = PIVOT + Vector3.new(-0.5, -0.6, -0.5)
			local shoulder = at + Vector3.new(-0.4, 1.1, 0.5)
			local reach = (at - shoulder).Magnitude / Constants.reachUse + 0.02
			local holding = table.clone(REST)
			holding.left = { at = at, shoulder = shoulder, reach = reach }
			local swing = { offset = Vector3.new(0, 0, -0.3), pitch = 0.5, yaw = -0.4, roll = 0 }
			local free = VacuumMotionFormulas.wand(REST, swing, MARGIN)
			expect(((free * at) - shoulder).Magnitude > Constants.reachUse * reach).to.equal(true)
			local held = VacuumMotionFormulas.wand(holding, swing, MARGIN)
			local distance = ((held * at) - shoulder).Magnitude
			expect(distance <= Constants.reachUse * reach + 1e-4).to.equal(true)
			-- Scaled back only as far as it must: right at the edge, still moved.
			expect(distance).to.be.near(Constants.reachUse * reach, 2e-3)
			expect(held.Position.Magnitude > 1e-3).to.equal(true)
		end)

		it("counts the brace's lean: the shoulder drops and tips forward with it", function()
			local motion = VacuumMotionFormulas.motion(Vector3.new(0, 0.2, 0), 0.2, math.rad(11))
			local shoulder = Vector3.new(-0.5, 1, 0)
			expect((motion * shoulder).Y < shoulder.Y - 0.15).to.equal(true)
			expect((motion * shoulder).Z < shoulder.Z - 0.1).to.equal(true)
			expect(VacuumMotionFormulas.motion(nil, 0.2, 0.3)).to.equal(CFrame.identity)
		end)

		it("lifts the wand when no flattening can clear the floor", function()
			local sunk = { offset = Vector3.new(0, -3, 0), pitch = 0, yaw = 0, roll = 0 }
			local transform = VacuumMotionFormulas.wand(REST, sunk, MARGIN)
			expect(lowest(transform) >= FLOOR + MARGIN - 1e-4).to.equal(true)
		end)
	end)

	describe("offsetOf", function()
		it("raises the wand for the aim, and moves the hands down and out for the reach", function()
			local raised = VacuumMotionFormulas.offsetOf(layers({ raise = 0.3 }))
			expect(raised.pitch).to.be.near(0.3, 1e-6)
			expect(raised.offset.Magnitude).to.equal(0)
			local reached = VacuumMotionFormulas.offsetOf(layers({ reach = 1 }))
			expect(reached.offset.Y).to.be.near(-Constants.aim.reachDrop, 1e-6)
			expect(reached.offset.Z).to.be.near(-Constants.aim.reachForward, 1e-6)
		end)

		it("brings the hands down and in toward the body for the brace", function()
			local braced = VacuumMotionFormulas.offsetOf(layers({ brace = 1 }))
			expect(braced.offset.Y).to.be.near(-Constants.brace.handDrop, 1e-6)
			expect(braced.offset.Z).to.be.near(Constants.brace.pull, 1e-6)
		end)
	end)

	describe("kick", function()
		it("jolts the hands back and up and hops the floor head, by the kick's size", function()
			local kicked = VacuumMotionFormulas.offsetOf(layers({ kick = 1 }))
			local tuning = Constants.kick
			expect(kicked.offset.Y).to.be.near(tuning.lift, 1e-6)
			expect(kicked.offset.Z).to.be.near(tuning.lift * tuning.back, 1e-6)
			expect(kicked.pitch).to.be.near(tuning.pitch, 1e-6)
		end)

		it("kicks a bigger pile harder, within its bounds", function()
			local tuning = Constants.kick
			expect(VacuumMotionFormulas.kickScale(tuning.sizeRef)).to.be.near(1, 1e-6)
			expect(VacuumMotionFormulas.kickScale(0.1)).to.equal(tuning.minScale)
			expect(VacuumMotionFormulas.kickScale(100)).to.equal(tuning.maxScale)
		end)

		it("is an impulse that peaks at its scale, then settles back to rest in about 0.3 s", function()
			local tuning = Constants.kick
			local x, v = 0, VacuumMotionFormulas.kickImpulse(1)
			local peak, peakAt, settledAt = 0, 0, nil
			for i = 1, 120 do
				x, v = VacuumMotionFormulas.step(x, v, 0, 1 / 240, tuning.frequency, tuning.damping)
				if x > peak then
					peak, peakAt = x, i / 240
				end
				if settledAt == nil and i / 240 > peakAt and math.abs(x) < 0.08 and math.abs(v) < 2 and peak > 0.9 then
					settledAt = i / 240
				end
			end
			expect(peak).to.be.near(1, 0.02)
			expect(peakAt < 0.1).to.equal(true)
			expect(settledAt ~= nil and settledAt < 0.4).to.equal(true)
		end)
	end)

	describe("shimmy", function()
		it("is still off a pile and grows with the pile's progress, to its full amplitude", function()
			local tuning = Constants.shimmy
			local function biggest(progress, weight)
				local yaw, roll = 0, 0
				for i = 0, 200 do
					local y, r = VacuumMotionFormulas.shimmy(i / 100, 7, progress, weight)
					yaw, roll = math.max(yaw, math.abs(y)), math.max(roll, math.abs(r))
				end
				return yaw, roll
			end
			local offYaw = biggest(1, 0)
			expect(offYaw).to.equal(0)
			local startYaw = biggest(0, 1)
			local endYaw, endRoll = biggest(1, 1)
			expect(startYaw > 0 and endYaw > 3 * startYaw).to.equal(true)
			expect(endYaw <= tuning.yaw + 1e-6).to.equal(true)
			expect(endRoll <= tuning.roll + 1e-6).to.equal(true)
			expect(endYaw > 0.6 * tuning.yaw).to.equal(true)
		end)

		it("is smooth: no frame-to-frame jump bigger than its frequency allows", function()
			local tuning = Constants.shimmy
			local last = VacuumMotionFormulas.shimmy(0, 3, 1, 1)
			for i = 1, 300 do
				local yaw = VacuumMotionFormulas.shimmy(i / 60, 3, 1, 1)
				-- At most the amplitude's slope (2 pi f A, the fastest of its sines) over a frame, with slack.
				expect(math.abs(yaw - last) <= 2 * math.pi * tuning.frequency * 1.8 * tuning.yaw / 60).to.equal(true)
				last = yaw
			end
		end)

		it("shimmies two holders differently (seeded)", function()
			local a = VacuumMotionFormulas.shimmy(0.37, 1, 1, 1)
			local b = VacuumMotionFormulas.shimmy(0.37, 2, 1, 1)
			expect(math.abs(a - b) > 1e-4).to.equal(true)
		end)

		it("turns and rolls the wand for the shimmy", function()
			local shaken = VacuumMotionFormulas.offsetOf(layers({ shimmyYaw = 0.02, shimmyRoll = -0.01 }))
			expect(shaken.yaw).to.be.near(0.02, 1e-6)
			expect(shaken.roll).to.be.near(-0.01, 1e-6)
		end)
	end)

	describe("sway", function()
		it("trails a turn: turning left swings the floor head right, within its most", function()
			local tuning = Constants.sway
			local yaw = VacuumMotionFormulas.swayTargets(1, 0)
			expect(yaw).to.be.near(-tuning.yawPerRate, 1e-6)
			expect(VacuumMotionFormulas.swayTargets(-100, 0)).to.equal(tuning.maxYaw)
		end)

		it("slides the head on when she stops (braking raises it forward), within its most", function()
			local tuning = Constants.sway
			local _, braking = VacuumMotionFormulas.swayTargets(0, -10)
			expect(braking).to.be.near(10 * tuning.pitchPerAccel, 1e-6)
			local _, hard = VacuumMotionFormulas.swayTargets(0, -1000)
			expect(hard).to.equal(tuning.maxPitch)
		end)

		it("turns and tips the wand for the sway", function()
			local swung = VacuumMotionFormulas.offsetOf(layers({ swayYaw = 0.1, swayPitch = 0.05, shimmyYaw = 0.01 }))
			expect(swung.yaw).to.be.near(0.11, 1e-6)
			expect(swung.pitch).to.be.near(0.05, 1e-6)
		end)
	end)

	describe("pack", function()
		it("lags the torso's bounce: rising, the canister sags; it bobs further when full", function()
			local tuning = Constants.pack
			local empty = VacuumMotionFormulas.packTarget(10, 0)
			local full = VacuumMotionFormulas.packTarget(10, 1)
			expect(empty).to.be.near(-10 * tuning.gain, 1e-6)
			expect(full < empty).to.equal(true)
			expect(VacuumMotionFormulas.packTarget(-1e4, 1)).to.equal(tuning.max)
		end)

		it("is heavier and slower when full", function()
			local tuning = Constants.pack
			expect(VacuumMotionFormulas.packFrequency(0)).to.be.near(tuning.frequency, 1e-6)
			expect(VacuumMotionFormulas.packFrequency(1)).to.be.near(tuning.fullFrequency, 1e-6)
			expect(VacuumMotionFormulas.packFrequency(5)).to.be.near(tuning.fullFrequency, 1e-6)
		end)

		it("moves the pack up and down and sloshes it about its mount", function()
			local frame = VacuumMotionFormulas.packFrame(0.05)
			expect(frame.Position.Y).to.be.near(0.05, 1e-6)
			local tilt = math.atan2(-frame.LookVector.Y, -frame.LookVector.Z)
			expect(math.abs(tilt)).to.be.near(0.05 * Constants.pack.tilt, 1e-4)
			expect(VacuumMotionFormulas.packFrame(0)).to.equal(CFrame.identity)
		end)
	end)

	describe("brace", function()
		it("braces part-way the moment suction starts, fully as the pile nears done, and not at all off it", function()
			expect(VacuumMotionFormulas.braceTarget(false, 0.9)).to.equal(0)
			expect(VacuumMotionFormulas.braceTarget(true, 0)).to.be.near(Constants.brace.base, 1e-6)
			expect(VacuumMotionFormulas.braceTarget(true, 1)).to.be.near(1, 1e-6)
			expect(VacuumMotionFormulas.braceTarget(true, 5)).to.be.near(1, 1e-6)
		end)

		it("drops the hips and leans the torso by the brace's weight", function()
			local drop, lean = VacuumMotionFormulas.body(0.5)
			expect(drop).to.be.near(Constants.brace.drop / 2, 1e-6)
			expect(lean).to.be.near(Constants.brace.lean / 2, 1e-6)
		end)
	end)

	describe("legFold", function()
		it("folds hip, knee and ankle so the hips drop by `drop` with the foot still under the hip", function()
			local thigh, shin, drop = 0.55, 0.5, 0.12
			local hip, knee, ankle = VacuumMotionFormulas.legFold(thigh, shin, drop)
			-- The thigh swings forward by hip, the shin back by ankle (the foot stays flat: hip + knee + ankle = 0).
			expect(hip > 0 and ankle > 0 and knee < 0).to.equal(true)
			expect(hip + knee + ankle).to.be.near(0, 1e-6)
			expect(thigh * math.sin(hip)).to.be.near(shin * math.sin(ankle), 1e-4)
			expect(thigh * (1 - math.cos(hip)) + shin * (1 - math.cos(ankle))).to.be.near(drop, 1e-4)
		end)

		it("does not fold for no drop, and stops at a deep crouch", function()
			local hip, knee, ankle = VacuumMotionFormulas.legFold(0.5, 0.5, 0)
			expect(hip).to.equal(0)
			expect(knee).to.equal(0)
			expect(ankle).to.equal(0)
			local deep = VacuumMotionFormulas.legFold(0.5, 0.5, 5)
			expect(deep <= math.rad(80) + 1e-6).to.equal(true)
		end)
	end)
end
