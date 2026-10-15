local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animation = ReplicatedStorage.Shared.Features.Animation
local Contact = require(Animation.Utils.AnimationCarryContactUtils)
local Arm = require(Animation.Utils.AnimationCarryArmUtils)
local Rules = require(Animation.Rules.AnimationCarryPoseRules)
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
	-- Surfaces in the item's own space: a solid box, a ball, and nothing.
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
	local function ballProbe(radius)
		return function(from, along)
			local a = along:Dot(along)
			local b = 2 * from:Dot(along)
			local c = from:Dot(from) - radius * radius
			local disc = b * b - 4 * a * c
			if disc < 0 then
				return nil, nil
			end
			local t = (-b - math.sqrt(disc)) / (2 * a)
			if t < 0 or t > 1 then
				return nil, nil
			end
			local hit = from + along * t
			return hit, hit.Unit
		end
	end
	local function nothing()
		return nil, nil
	end

	describe("under: palms up on the item's real bottom", function()
		local size = Vector3.new(1.6, 0.8, 1)
		local item = { size = size, probe = boxProbe(size) }

		it("rests a box on both palms, under its bottom, in front of the torso, off the floor", function()
			local hold, report = Contact.plan(item, rig, { "under" })
			expect(hold).to.be.ok()
			expect(report.ok).to.equal(true)
			expect(hold.style).to.equal("under")
			expect(hold.mount).to.equal("torso")
			for _, contact in { hold.right, hold.left } do
				expect(contact.Position.Y).to.be.near(-size.Y / 2, 1e-3)
				expect(contact.UpVector.Y > 0.7).to.equal(true)
			end
			expect(hold.right.Position.X > 0 and hold.left.Position.X < 0).to.equal(true)
			local near = hold.offset:PointToWorldSpace(Vector3.new(0, 0, size.Z / 2)).Z
			expect(near <= rig.front + 1e-3).to.equal(true)
			for _, side in { { rig.right, hold.rightPose, hold.right }, { rig.left, hold.leftPose, hold.left } } do
				local palm = Arm.palm(side[1], side[2])
				expect((palm.Position - (hold.offset * side[3]).Position).Magnitude < 0.01).to.equal(true)
			end
		end)

		it("finds a round item's real bottom, not its box's: the palms touch the ball", function()
			local ball = { size = Vector3.one * 1.2, probe = ballProbe(0.6) }
			local hold, report = Contact.plan(ball, rig, { "under" })
			expect(hold).to.be.ok()
			expect(report.ok).to.equal(true)
			for _, contact in { hold.right, hold.left } do
				expect(contact.Position.Magnitude).to.be.near(0.6, 1e-3)
				expect(contact.Position.Y < 0).to.equal(true)
			end
		end)

		it("plans nothing on an item with no surface below", function()
			expect(Contact.plan({ size = size, probe = nothing }, rig, { "under" })).to.equal(nil)
		end)

		it("rests an authored body front against the torso (a pot under wider leaves)", function()
			local bodyZ = 0.2
			local hold = Contact.plan({ size = size, probe = boxProbe(size), bodyZ = bodyZ }, rig, { "under" })
			expect(hold).to.be.ok()
			local front = hold.offset:PointToWorldSpace(Vector3.new(0, 0, bodyZ)).Z
			expect(front <= rig.front + 1e-3).to.equal(true)
		end)
	end)

	describe("hand: hanging from the relaxed arm by its handle", function()
		it("hangs a light item from the fist, the arm down by the side, clear of the body and the floor", function()
			local size = Vector3.new(0.3, 0.4, 0.2)
			local handle = Vector3.new(0, 0.2, 0)
			local hold, report = Contact.plan({ size = size, probe = boxProbe(size), handle = handle }, rig, { "hand" })
			expect(hold).to.be.ok()
			expect(report.ok).to.equal(true)
			expect(hold.style).to.equal("hand")
			expect(hold.mount).to.equal("rightHand")
			expect(hold.left).to.equal(nil)
			expect((hold.right.Position - handle).Magnitude < 1e-3).to.equal(true)
			local fist = hold.rightPose.hand:PointToWorldSpace(rig.right.gripInHand.Position)
			expect((fist - hold.offset:PointToWorldSpace(handle)).Magnitude < 0.01).to.equal(true)
			expect(Rules.check(rig, hold, boxProbe(size), size).floorGap > 0.2).to.equal(true)
		end)

		it("is not offered when the item would not clear the floor from a relaxed arm", function()
			local size = Vector3.new(0.6, 3.5, 0.6)
			local hold = Contact.plan({ size = size, probe = boxProbe(size) }, rig, { "hand" })
			expect(hold).to.equal(nil)
		end)
	end)

	describe("push: on the floor in front, palms flat on its near face", function()
		local size = Vector3.new(1.8, 4, 1.8)
		local item = { size = size, probe = boxProbe(size) }

		it("stands it on the floor, its near face in reach, both palms on that face, fingers up and in", function()
			local hold, report = Contact.plan(item, rig, { "push" })
			expect(hold).to.be.ok()
			expect(report.ok).to.equal(true)
			expect(hold.style).to.equal("push")
			expect(hold.mount).to.equal("root")
			local bottom = hold.offset:PointToWorldSpace(Vector3.new(0, -size.Y / 2, 0)).Y
			expect(bottom - rig.floor).to.be.near(0.03, 1e-3)
			for _, contact in { hold.right, hold.left } do
				expect(contact.Position.Z).to.be.near(size.Z / 2, 1e-3)
				expect(contact.UpVector.Z < -0.7).to.equal(true)
				expect(contact.LookVector.Y > 0.5).to.equal(true)
			end
			-- A face taller than the head's bottom is kept clear of the head on its real surface.
			expect(report.headDepth <= Rules.TOLERANCE.itemHead).to.equal(true)
		end)
	end)

	it("takes the first style whose pose passes, in the order given", function()
		local small = Vector3.new(1.6, 0.8, 1)
		expect(Contact.plan({ size = small, probe = boxProbe(small) }, rig, { "under", "push" }).style).to.equal(
			"under"
		)
		-- A low box cannot be pushed by these arms (its face is out of reach below), so `under` follows.
		expect(Contact.plan({ size = small, probe = boxProbe(small) }, rig, { "push", "under" }).style).to.equal(
			"under"
		)
		local tall = Vector3.new(1.8, 4, 1.8)
		expect(Contact.plan({ size = tall, probe = boxProbe(tall) }, rig, { "push", "under" }).style).to.equal("push")
	end)

	it("rejects a malformed item: no size, or a handle or body front outside it", function()
		local size = Vector3.new(1, 1, 1)
		expect(Contact.plan({ size = Vector3.zero, probe = boxProbe(size) }, rig, { "under" })).to.equal(nil)
		expect(Contact.plan({ size = size, probe = boxProbe(size), handle = Vector3.new(0, 2, 0) }, rig, { "hand" })).to.equal(
			nil
		)
		expect(Contact.plan({ size = size, probe = boxProbe(size), bodyZ = 3 }, rig, { "under" })).to.equal(nil)
	end)

	it("knows a round body (shoulders inside the torso) from a stock one", function()
		expect(Contact.roundBody(rig)).to.equal(false)
		local round = table.clone(rig)
		round.torsoHalfWidth = 0.8
		expect(Contact.roundBody(round)).to.equal(true)
	end)

	describe("palmFrame", function()
		it("finds a T-posed hand's palm facing down, at its face (Pippa's rig)", function()
			local size = Vector3.new(0.67, 0.54, 0.97)
			local frame = Contact.palmFrame(Vector3.new(0.6, 0, -0.1), CFrame.identity, 1, size)
			expect((frame.LookVector - Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
			expect((frame.UpVector + Vector3.yAxis).Magnitude < 1e-3).to.equal(true)
			expect((frame.Position - Vector3.new(0, -0.27, 0)).Magnitude < 1e-3).to.equal(true)
		end)

		it("finds a hanging hand's palm facing the body (stock R15)", function()
			local size = Vector3.new(0.3, 0.3, 0.3)
			local right = Contact.palmFrame(Vector3.new(0, -0.3, 0), CFrame.identity, 1, size)
			expect((right.UpVector + Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
			local left = Contact.palmFrame(Vector3.new(0, -0.3, 0), CFrame.identity, -1, size)
			expect((left.UpVector - Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
		end)
	end)
end
