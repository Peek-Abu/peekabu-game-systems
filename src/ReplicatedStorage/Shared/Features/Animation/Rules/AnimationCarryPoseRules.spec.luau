local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animation = ReplicatedStorage.Shared.Features.Animation
local Rules = require(Animation.Rules.AnimationCarryPoseRules)
local Arm = require(Animation.Utils.AnimationCarryArmUtils)
local Contact = require(Animation.Utils.AnimationCarryContactUtils)
return function()
	-- A T-posed carrier (root space): shoulders at (+-0.6, 1.15), 0.6-stud bones, a slim torso and a head above it.
	local function arm(side)
		local handSize = Vector3.new(0.4, 0.3, 0.3)
		local palm = Contact.palmFrame(Vector3.new(side * 0.2, 0, 0), CFrame.identity, side, handSize)
		return {
			side = side,
			shoulder = Vector3.new(side * 0.6, 1.15, 0),
			upperRest = CFrame.new(side * 0.9, 1.15, 0),
			lowerRest = CFrame.new(side * 1.5, 1.15, 0),
			handRest = CFrame.new(side * 2, 1.15, 0),
			shoulderInUpper = Vector3.new(-side * 0.3, 0, 0),
			elbowInUpper = Vector3.new(side * 0.3, 0, 0),
			elbowInLower = Vector3.new(-side * 0.3, 0, 0),
			wristInLower = Vector3.new(side * 0.3, 0, 0),
			wristInHand = Vector3.new(-side * 0.2, 0, 0),
			palmInHand = palm,
			gripInHand = palm.Rotation,
			handLength = 0.4,
		}
	end
	local rig = {
		right = arm(1),
		left = arm(-1),
		front = -0.4,
		headFront = -0.7,
		headBottom = 1.6,
		headTop = 3.2,
		floor = -2,
		torsoHalfWidth = 0.55,
		body = { { centre = Vector3.new(0, 0.6, 0), radii = Vector3.new(0.55, 0.9, 0.4) } },
		head = { { centre = Vector3.new(0, 2.4, 0), radii = Vector3.new(0.7, 0.8, 0.7) } },
	}
	-- A solid box's surface, in its own space.
	local function boxProbe(size)
		local half = size / 2
		return function(from, along)
			local tNear, tFar = -math.huge, math.huge
			local normal = Vector3.zero
			for _, axis in { "X", "Y", "Z" } do
				local o, d, h = from[axis], along[axis], half[axis]
				if math.abs(d) < 1e-9 then
					if o < -h or o > h then
						return nil, nil
					end
				else
					local t1, t2 = (-h - o) / d, (h - o) / d
					local n1 = Vector3.new(axis == "X" and -1 or 0, axis == "Y" and -1 or 0, axis == "Z" and -1 or 0)
					if t1 > t2 then
						t1, t2 = t2, t1
						n1 = -n1
					end
					if t1 > tNear then
						tNear, normal = t1, n1
					end
					tFar = math.min(tFar, t2)
				end
			end
			if tNear > tFar or tNear < 0 or tNear > 1 then
				return nil, nil
			end
			return from + along * tNear, normal
		end
	end
	local size = Vector3.new(1.6, 0.8, 1)
	local probe = boxProbe(size)
	local function planned()
		local hold, report = Contact.plan({ size = size, probe = probe }, rig, { "under" })
		return hold, report
	end
	local function moved(hold, by)
		local copy = table.clone(hold)
		copy.offset = by * hold.offset
		return copy
	end

	it("passes a hold planned on the item's surface: palms on it, joints inside their limits", function()
		local hold, report = planned()
		expect(hold).to.be.ok()
		expect(report.ok).to.equal(true)
		local checked = Rules.check(rig, hold, probe, size)
		expect(checked.ok).to.equal(true)
		expect(math.abs(checked.right.contact) <= Rules.TOLERANCE.contact).to.equal(true)
		expect(checked.floorGap > Rules.TOLERANCE.floorLift).to.equal(true)
	end)

	it("reports a palm that floats under the item or sinks into it", function()
		local hold = planned()
		local short = Rules.check(rig, moved(hold, CFrame.new(0, 0.2, 0)), probe, size)
		expect(short.ok).to.equal(false)
		expect(short.right.contact).to.be.near(0.2, 0.02)
		local sunk = Rules.check(rig, moved(hold, CFrame.new(0, -0.15, 0)), probe, size)
		expect(sunk.right.contact).to.be.near(-0.15, 0.02)
		expect(sunk.ok).to.equal(false)
	end)

	it("reports the item reaching into the torso or the head, and an arm through the item", function()
		local hold = planned()
		local intoTorso = Rules.check(rig, moved(hold, CFrame.new(0, 0, 0.5)), probe, size)
		expect(intoTorso.torsoDepth > Rules.TOLERANCE.itemTorso).to.equal(true)
		-- A big crate round the whole head: its surface is far from the head's.
		local crate = Vector3.new(3, 3, 3)
		local high = table.clone(hold)
		high.offset = CFrame.new(0, 2.4, 0)
		local intoHead = Rules.check(rig, high, boxProbe(crate), crate)
		expect(intoHead.headDepth > Rules.TOLERANCE.itemHead).to.equal(true)
		local through = table.clone(hold)
		through.offset = CFrame.new(0.9, 1.15, -0.2)
		expect(Rules.check(rig, through, probe, size).right.inItem).to.equal(true)
	end)

	it("keeps a lifted item off the floor and a pushed one on it", function()
		local hold = planned()
		local low = table.clone(hold)
		low.offset = CFrame.new(0, rig.floor + 0.05, -1)
		local lowReport = Rules.check(rig, low, probe, size)
		expect(lowReport.floorGap).to.be.near(-0.35, 1e-3)
		expect(lowReport.ok).to.equal(false)
		local pushed = table.clone(low)
		pushed.style = "push"
		pushed.offset = CFrame.new(0, rig.floor + size.Y / 2 + 0.02, -1)
		local onFloor = Rules.check(rig, pushed, probe, size)
		expect(onFloor.floorGap).to.be.near(0.02, 1e-3)
		local found = false
		for _, violation in onFloor.violations do
			found = found or violation:find("floor") ~= nil
		end
		expect(found).to.equal(false)
	end)

	it("reports a joint past its limit: a hyperextended elbow, a bent-back wrist", function()
		local hold = planned()
		local a = rig.right
		local pose = { upper = a.upperRest, lower = a.lowerRest, hand = a.handRest }
		-- The elbow bent 30 degrees backward (its hinge is up for a T-posed right arm: +flex swings the forearm forward).
		local elbowAt = pose.upper:PointToWorldSpace(a.elbowInUpper)
		local back = CFrame.new(elbowAt) * CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-30)) * CFrame.new(-elbowAt)
		local bad = table.clone(hold)
		bad.rightPose = { upper = pose.upper, lower = back * pose.lower, hand = back * pose.hand }
		local report = Rules.check(rig, bad, probe, size)
		expect(report.right.angles.flex).to.be.near(-30, 0.5)
		local named = false
		for _, violation in report.violations do
			named = named or violation:find("elbow flexed") ~= nil
		end
		expect(named).to.equal(true)
		-- The hand bent 80 degrees back from the forearm.
		local wristAt = pose.lower:PointToWorldSpace(a.wristInLower)
		local palm = pose.hand * a.palmInHand
		local bend = CFrame.new(wristAt) * CFrame.fromAxisAngle(palm.RightVector, math.rad(-80)) * CFrame.new(-wristAt)
		bad.rightPose = { upper = pose.upper, lower = pose.lower, hand = bend * pose.hand }
		local wrist = Rules.check(rig, bad, probe, size)
		expect(math.abs(wrist.right.angles.wristFlex)).to.be.near(80, 0.5)
	end)

	it("judges one hand by the fist at the handle", function()
		local handle = Vector3.new(0, size.Y / 2, 0)
		local hold, report = Contact.plan({ size = size, probe = probe, handle = handle }, rig, { "hand" })
		if hold ~= nil and report ~= nil then
			expect(hold.style).to.equal("hand")
			expect(report.right.contact < Rules.TOLERANCE.handle).to.equal(true)
			local off = moved(hold, CFrame.new(0, -0.2, 0))
			expect(Rules.check(rig, off, probe, size).right.contact).to.be.near(0.2, 0.02)
		end
	end)

	it("finds a point inside the item only within its real surface", function()
		expect(Rules.inItem(probe, size, CFrame.new(0, 0, -2), Vector3.new(0, 0, -2))).to.equal(true)
		expect(Rules.inItem(probe, size, CFrame.new(0, 0, -2), Vector3.new(0, 0.5, -2))).to.equal(false)
		expect(Arm.depthIn(Vector3.new(0, 0.6, 0), rig.body, 0)).to.be.near(1, 1e-6)
	end)
end
