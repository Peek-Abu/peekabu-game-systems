local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Arm = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryArmUtils)
local Contact = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
return function()
	local LIMITS = Arm.LIMITS
	local POLE = Vector3.new(0.4, -2, 1)

	-- A T-posed arm (Pippa's rig, root space): the shoulder joint at (0.45, 1.15, 0), upper and lower arm 0.5 each out
	-- along X, a hand past the wrist whose palm faces down.
	local function tposed(side)
		local handSize = Vector3.new(0.4, 0.3, 0.3)
		local palm = Contact.palmFrame(Vector3.new(side * 0.2, 0, 0), CFrame.identity, side, handSize)
		return {
			side = side,
			shoulder = Vector3.new(side * 0.45, 1.15, 0),
			upperRest = CFrame.new(side * 0.7, 1.15, 0),
			lowerRest = CFrame.new(side * 1.2, 1.15, 0),
			handRest = CFrame.new(side * 1.65, 1.15, 0),
			shoulderInUpper = Vector3.new(-side * 0.25, 0, 0),
			elbowInUpper = Vector3.new(side * 0.25, 0, 0),
			elbowInLower = Vector3.new(-side * 0.25, 0, 0),
			wristInLower = Vector3.new(side * 0.25, 0, 0),
			wristInHand = Vector3.new(-side * 0.2, 0, 0),
			palmInHand = palm,
			gripInHand = palm.Rotation,
			handLength = 0.4,
		}
	end
	-- A hanging arm with a stock R15's joints: the shoulder joint at its upper arm's top inner corner, so the bone runs
	-- 33 degrees off the part's axis; the palm faces the body.
	local function hanging(side)
		local handSize = Vector3.new(1, 0.3, 1)
		local palm = Contact.palmFrame(Vector3.new(0, -0.29, 0), CFrame.identity, side, handSize)
		return {
			side = side,
			shoulder = Vector3.new(side * 0.97, 0.85, 0),
			upperRest = CFrame.new(side * 1.47, 0.43, 0),
			lowerRest = CFrame.new(side * 1.47, -0.2, 0),
			handRest = CFrame.new(side * 1.47, -0.87, 0),
			shoulderInUpper = Vector3.new(-side * 0.5, 0.42, 0),
			elbowInUpper = Vector3.new(0, -0.355, 0),
			elbowInLower = Vector3.new(0, 0.275, 0),
			wristInLower = Vector3.new(0, -0.53, 0),
			wristInHand = Vector3.new(0, 0.13, 0),
			palmInHand = palm,
			gripInHand = CFrame.new(0, -0.16, 0) * palm.Rotation,
			handLength = 0.3,
		}
	end
	-- A palm frame at `at` facing `up`, fingers forward.
	local function palmAt(at, up)
		local look = (-Vector3.zAxis - up * up:Dot(-Vector3.zAxis)).Unit
		return CFrame.fromMatrix(at, up:Cross(-look), up, -look)
	end
	local function angleBetween(a, b)
		return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
	end
	local function inside(angles)
		local roll = angles.roll
		return angles.flex >= LIMITS.flexMin
			and angles.flex <= LIMITS.flexMax
			and math.abs(angles.sideBend) <= LIMITS.sideBend
			and (roll == nil or (roll >= -LIMITS.pronate and roll <= LIMITS.supinate))
			and math.abs(angles.wristFlex) <= LIMITS.wristFlex
			and math.abs(angles.wristDeviation) <= LIMITS.wristDeviation
			and math.abs(angles.wristTwist) <= LIMITS.wristTwist
	end

	describe("solve", function()
		it("puts the palm exactly on a reachable contact, facing it, on a T-posed and a hanging rig", function()
			for _, make in { tposed, hanging } do
				for _, side in { 1, -1 } do
					local arm = make(side)
					local length = (arm.elbowInUpper - arm.shoulderInUpper).Magnitude
						+ (arm.wristInLower - arm.elbowInLower).Magnitude
					local contact = palmAt(arm.shoulder + Vector3.new(0, -0.55, -0.45) * length, Vector3.yAxis)
					local pose = Arm.solve(arm, contact, POLE, {}, 0)
					local palm = Arm.palm(arm, pose)
					expect((palm.Position - contact.Position).Magnitude < 1e-3).to.equal(true)
					expect(angleBetween(palm.UpVector, contact.UpVector) < 30).to.equal(true)
				end
			end
		end)

		it("bends the elbow only in its own hinge, even when the shoulder joint is off the arm's axis", function()
			for _, make in { tposed, hanging } do
				local arm = make(1)
				local contact = palmAt(arm.shoulder + Vector3.new(0.1, -0.4, -0.5), Vector3.new(0, 1, 0))
				local angles = Arm.angles(arm, Arm.solve(arm, contact, POLE, {}, 0))
				expect(math.abs(angles.sideBend) < 0.5).to.equal(true)
				expect(angles.flex > 10 and angles.flex <= LIMITS.flexMax).to.equal(true)
			end
		end)

		it("keeps the forearm's roll and the wrist inside their limits when the contact asks for more", function()
			-- Palms facing out and back, which no forearm can turn to: the joints stop at their limits.
			for _, make in { tposed, hanging } do
				for _, side in { 1, -1 } do
					local arm = make(side)
					local contact =
						palmAt(arm.shoulder + Vector3.new(side * 0.2, -0.5, -0.4), Vector3.new(side, 0, 1).Unit)
					local angles = Arm.angles(arm, Arm.solve(arm, contact, POLE, {}, 0))
					expect(inside(angles)).to.equal(true)
				end
			end
		end)

		it("leaves the palm short, along the arm, of a contact out of reach", function()
			local arm = tposed(1)
			local contact = palmAt(arm.shoulder + Vector3.new(0, 0, -4), Vector3.yAxis)
			local palm = Arm.palm(arm, Arm.solve(arm, contact, POLE, {}, 0))
			expect((palm.Position - arm.shoulder).Magnitude <= Arm.reach(arm) + 1e-3).to.equal(true)
			expect((palm.Position - contact.Position).Magnitude > 2).to.equal(true)
		end)

		it("lands the grip instead of the palm for a handle held in the fist", function()
			local arm = hanging(1)
			local contact = CFrame.new(arm.shoulder + Vector3.new(0.3, -1.6, -0.2)) * arm.gripInHand.Rotation
			local pose = Arm.solve(arm, contact, Vector3.new(0.3, 0, 1), {}, 0, arm.gripInHand)
			local fist = pose.hand:PointToWorldSpace(arm.gripInHand.Position)
			expect((fist - contact.Position).Magnitude < 1e-3).to.equal(true)
		end)
	end)

	describe("angles", function()
		it("reads an arm at rest as unbent, whether T-posed or hanging", function()
			local t = Arm.angles(
				tposed(1),
				{ upper = tposed(1).upperRest, lower = tposed(1).lowerRest, hand = tposed(1).handRest }
			)
			expect(t.flex).to.be.near(0, 1e-3)
			expect(t.sideBend).to.be.near(0, 1e-3)
			expect(t.wristFlex).to.be.near(0, 1e-3)
			expect(t.elevation).to.be.near(0, 1e-3)
			local arm = hanging(1)
			local h = Arm.angles(arm, { upper = arm.upperRest, lower = arm.lowerRest, hand = arm.handRest })
			expect(h.flex).to.be.near(0, 1e-3)
			expect(h.sideBend).to.be.near(0, 1e-3)
			expect(h.elevation < -45).to.equal(true)
		end)

		it("reads the shoulder against a turned torso", function()
			local arm = tposed(1)
			local rest = { upper = arm.upperRest, lower = arm.lowerRest, hand = arm.handRest }
			local leaning = Arm.angles(arm, rest, CFrame.Angles(0, 0, math.rad(30)))
			expect(leaning.elevation).to.be.near(-30, 1e-2)
		end)
	end)

	describe("palmSphere and reach", function()
		it("bounds where a palm held a given way can go: just inside the sphere, the solve lands it", function()
			local arm = hanging(1)
			local rotation = palmAt(Vector3.zero, Vector3.yAxis).Rotation
			local centre, radius = Arm.palmSphere(arm, rotation)
			local direction = Vector3.new(0.2, -0.6, -0.8).Unit
			local contact = CFrame.new(centre + direction * radius * 0.97) * rotation
			local palm = Arm.palm(arm, Arm.solve(arm, contact, POLE, {}, 0))
			expect((palm.Position - contact.Position).Magnitude < 0.05).to.equal(true)
		end)

		it("measures the straight arm's reach to the palm", function()
			local arm = tposed(1)
			expect(Arm.reach(arm)).to.be.near(1 + (arm.palmInHand.Position - arm.wristInHand).Magnitude, 1e-4)
		end)
	end)

	describe("elbow", function()
		local function along(a, b, from, to)
			local points = {}
			for k = 0, 8 do
				table.insert(points, a:Lerp(b, from + (to - from) * k / 8))
			end
			return points
		end
		local function insideBody(point, body, pad)
			for _, shape in body do
				if ((point - shape.centre) / (shape.radii + Vector3.one * pad)).Magnitude < 1 then
					return true
				end
			end
			return false
		end

		it("keeps the two bones' lengths and reaches the wrist", function()
			local shoulder, wrist = Vector3.new(0.45, 1.1, 0), Vector3.new(0.2, 0.4, -0.7)
			local elbow = Arm.elbow(shoulder, wrist, 0.6, 0.6, 1, POLE, {}, 0.08)
			expect((elbow - shoulder).Magnitude).to.be.near(0.6, 1e-3)
			expect((wrist - elbow).Magnitude).to.be.near(0.6, 1e-3)
		end)

		it("bends toward the pole when that already clears the body", function()
			local body = { { centre = Vector3.new(0, 0.6, 0), radii = Vector3.new(0.7, 0.8, 0.5) } }
			local shoulder, wrist = Vector3.new(1, 1.2, 0), Vector3.new(0.6, 0.1, -1)
			local elbow = Arm.elbow(shoulder, wrist, 0.9, 0.9, 1, POLE, body, 0.08)
			local free = Arm.elbow(shoulder, wrist, 0.9, 0.9, 1, POLE, {}, 0.08)
			expect((elbow - free).Magnitude).to.be.near(0, 1e-3)
		end)

		it("swings the elbows out of a round body", function()
			local body = {
				{ centre = Vector3.new(0, 0.825, -0.1), radii = Vector3.new(0.597, 1.225, 0.629) },
				{ centre = Vector3.new(0, 0, 0.214), radii = Vector3.new(0.6, 0.475, 0.76) },
			}
			for _, side in { 1, -1 } do
				local shoulder = Vector3.new(side * 0.47, 1.1, 0)
				local wrist = Vector3.new(side * 0.41, 0.65, -0.72)
				local default = Arm.elbow(shoulder, wrist, 0.525, 0.475, side, POLE, {}, 0.08)
				local elbow = Arm.elbow(shoulder, wrist, 0.525, 0.475, side, POLE, body, 0.08)
				expect(insideBody(default, body, 0.08)).to.equal(true)
				expect(insideBody(elbow, body, 0.08)).to.equal(false)
				expect(elbow.X * side > shoulder.X * side + 0.15).to.equal(true)
				local through = 0
				for _, point in along(elbow, wrist, 0, 0.7) do
					if insideBody(point, body, 0.08) then
						through += 1
					end
				end
				expect(through).to.equal(0)
			end
		end)

		it("stretches straight at a wrist out of reach", function()
			local elbow = Arm.elbow(Vector3.zero, Vector3.new(0, 0, -3), 0.6, 0.6, 1, POLE, {}, 0.2)
			expect((elbow - Vector3.new(0, 0, -0.6)).Magnitude < 0.05).to.equal(true)
		end)
	end)

	it("measures how deep a point is inside the body", function()
		local body = { { centre = Vector3.zero, radii = Vector3.one } }
		expect(Arm.depthIn(Vector3.zero, body, 0)).to.be.near(1, 1e-6)
		expect(Arm.depthIn(Vector3.new(0.5, 0, 0), body, 0)).to.be.near(0.5, 1e-6)
		expect(Arm.depthIn(Vector3.new(2, 0, 0), body, 0)).to.equal(0)
	end)
end
