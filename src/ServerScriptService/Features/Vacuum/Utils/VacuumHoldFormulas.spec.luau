local VacuumHoldFormulas = require(script.Parent.VacuumHoldFormulas)

return function()
	-- A Pippa-like holder at 1.25x, root space: right shoulder 1.15 up and 0.45 right, arm 0.525 + 1.1 to the
	-- grip, floor 1.375 below the root.
	local RIGHT = { shoulder = Vector3.new(0.45, 1.15, 0), upper = 0.525, lower = 1.1 }
	local LEFT = { shoulder = Vector3.new(-0.45, 1.15, 0), upper = 0.525, lower = 1.1 }
	local FLOOR = -1.375
	local WAND = { gripHalf = 0.25, inlet = 0.1125, swivel = 0.075, head = 0.106 }
	local TUNING = {
		down = 0.2,
		forward = 0.75,
		out = -0.2,
		angle = math.rad(35),
		clearance = 0.06,
		minTube = 0.3,
		leftUp = 0.15,
	}

	describe("elbow", function()
		it("puts the elbow one upper arm from the shoulder and one forearm from the target", function()
			local shoulder, target = Vector3.new(0, 0, 0), Vector3.new(0, -0.8, -0.8)
			local elbow = VacuumHoldFormulas.elbow(shoulder, target, 0.6, 0.7, Vector3.new(1, -0.5, 0.5))
			expect((elbow - shoulder).Magnitude).to.be.near(0.6, 1e-4)
			expect((target - elbow).Magnitude).to.be.near(0.7, 1e-4)
		end)

		it("bends toward the pole", function()
			local elbow = VacuumHoldFormulas.elbow(Vector3.zero, Vector3.new(0, -1, 0), 0.6, 0.6, Vector3.new(1, 0, 0))
			expect(elbow.X > 0.2).to.equal(true)
		end)

		it("straightens the arm toward a target out of reach", function()
			local elbow = VacuumHoldFormulas.elbow(Vector3.zero, Vector3.new(0, -5, 0), 0.6, 0.6, Vector3.xAxis)
			expect(elbow.Y).to.be.near(-0.6, 1e-4)
			expect(math.abs(elbow.X) < 1e-4).to.equal(true)
		end)
	end)

	describe("tube", function()
		it("is long enough that the floor head rests on the floor", function()
			local tube = VacuumHoldFormulas.tube(1.5, WAND, TUNING.angle, TUNING.clearance, TUNING.minTube)
			-- Grip 1.5 above the floor: grip half + tube + half the swivel along the wand, then the swivel and head.
			local drop = (WAND.gripHalf + tube + WAND.swivel) * math.cos(TUNING.angle) + WAND.swivel + WAND.head
			expect(drop).to.be.near(1.5 - TUNING.clearance, 1e-4)
		end)

		it("never goes below its shortest", function()
			expect(VacuumHoldFormulas.tube(0.4, WAND, TUNING.angle, TUNING.clearance, TUNING.minTube)).to.equal(0.3)
		end)
	end)

	describe("hold", function()
		local hold = VacuumHoldFormulas.hold(RIGHT, LEFT, FLOOR, WAND, TUNING)

		it("holds the grip in front of and below the shoulder, inside the arm's reach so the elbow bends", function()
			local grip = hold.grip.Position
			local reach = RIGHT.upper + RIGHT.lower
			expect(grip.Z < -0.5).to.equal(true)
			expect(grip.Y < RIGHT.shoulder.Y).to.equal(true)
			local distance = (grip - RIGHT.shoulder).Magnitude
			expect(distance < 0.85 * reach).to.equal(true)
			expect(distance > 0.6 * reach).to.equal(true)
		end)

		it("turns the hand so the forearm runs down into it (no wrist-only bend)", function()
			local elbow = VacuumHoldFormulas.elbow(
				RIGHT.shoulder,
				hold.grip.Position,
				RIGHT.upper,
				RIGHT.lower,
				hold.rightPole - RIGHT.shoulder
			)
			local forearm = (hold.grip.Position - elbow).Unit
			-- The grip attachment is the stock hand turned -90 degrees about X; the stock hand's -Y runs down the arm.
			local hand = hold.grip * CFrame.Angles(math.pi / 2, 0, 0)
			expect((-hand.UpVector):Dot(forearm)).to.be.near(1, 1e-3)
		end)

		it("gives a Tool.Grip that keeps the handle square to the root at the grip", function()
			-- handle = gripAttachment * Grip:Inverse()
			local handle = hold.grip * hold.toolGrip:Inverse()
			expect((handle.Position - hold.grip.Position).Magnitude < 1e-4).to.equal(true)
			expect(handle.LookVector:Dot(Vector3.new(0, 0, -1))).to.be.near(1, 1e-4)
			expect(handle.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-4)
		end)

		it("sizes the tube from the grip's height so the head rests on the floor", function()
			local height = hold.grip.Position.Y - FLOOR
			expect(hold.tube).to.be.near(
				VacuumHoldFormulas.tube(height, WAND, TUNING.angle, TUNING.clearance, TUNING.minTube),
				1e-6
			)
			expect(hold.height).to.be.near(height, 1e-6)
		end)

		it("puts the left hand on the wand above the right one when it reaches", function()
			expect(hold.left).to.be.ok()
			local left = hold.left.Position
			expect(left.Y > hold.grip.Position.Y).to.equal(true)
			expect((left - LEFT.shoulder).Magnitude <= 0.95 * (LEFT.upper + LEFT.lower) + 1e-6).to.equal(true)
			-- Turned along its forearm too (a Transform target).
			local elbow =
				VacuumHoldFormulas.elbow(LEFT.shoulder, left, LEFT.upper, LEFT.lower, hold.leftPole - LEFT.shoulder)
			local hand = hold.left * CFrame.Angles(math.pi / 2, 0, 0)
			expect((-hand.UpVector):Dot((left - elbow).Unit)).to.be.near(1, 1e-3)
		end)

		it("leaves the left hand alone when it cannot reach, or there is no left arm", function()
			local short = { shoulder = Vector3.new(-0.45, 1.15, 0), upper = 0.2, lower = 0.2 }
			expect(VacuumHoldFormulas.hold(RIGHT, short, FLOOR, WAND, TUNING).left).to.equal(nil)
			expect(VacuumHoldFormulas.hold(RIGHT, nil, FLOOR, WAND, TUNING).left).to.equal(nil)
		end)

		it("points the right elbow outward and down, the left one outward and forward", function()
			expect(hold.rightPole.X > RIGHT.shoulder.X).to.equal(true)
			expect(hold.rightPole.Y < RIGHT.shoulder.Y).to.equal(true)
			expect(hold.leftPole.X < LEFT.shoulder.X).to.equal(true)
			expect(hold.leftPole.Z < LEFT.shoulder.Z).to.equal(true)
		end)

		it("keeps both arms out of a chibi's round belly (the left one crosses in front of it)", function()
			-- Pippa's torso + hi-vis vest at 1.25x as an ellipsoid (root space), and the arms' half thickness.
			local centre, half, thickness = Vector3.new(0, 0.6, -0.03), Vector3.new(0.58, 1, 0.56), 0.08
			local function clear(point: Vector3): boolean
				local d = (point - centre) / (half + Vector3.one * thickness)
				return d.Magnitude > 1
			end
			for _, arm in { { RIGHT, hold.grip.Position, hold.rightPole }, { LEFT, hold.left.Position, hold.leftPole } } do
				local side, target, pole = arm[1], arm[2], arm[3]
				local elbow =
					VacuumHoldFormulas.elbow(side.shoulder, target, side.upper, side.lower, pole - side.shoulder)
				-- The upper arm from where it leaves the shoulder (the shoulder joint itself is inside the body).
				for i = 7, 10 do
					expect(clear(side.shoulder:Lerp(elbow, i / 10))).to.equal(true)
				end
				for i = 0, 10 do
					expect(clear(elbow:Lerp(target, i / 10))).to.equal(true)
				end
			end
		end)
	end)

	describe("wand", function()
		it("lays the grip, tube and swivel along the wand and the floor head flat at its end", function()
			local frames = VacuumHoldFormulas.wand(WAND, 1.2, math.rad(35))
			local along = Vector3.new(0, -math.cos(math.rad(35)), -math.sin(math.rad(35)))
			expect(frames.grip.Position.Magnitude < 1e-6).to.equal(true)
			expect((-frames.grip.UpVector):Dot(along)).to.be.near(1, 1e-4)
			expect(frames.tube.Position:Dot(along)).to.be.near(WAND.gripHalf + 0.6, 1e-4)
			expect(frames.swivel.Position:Dot(along)).to.be.near(WAND.gripHalf + 1.2 + WAND.swivel, 1e-4)
			expect(frames.head.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-6)
			expect(frames.head.Position.Y).to.be.near(frames.swivel.Position.Y - WAND.swivel - WAND.head / 2, 1e-4)
			-- The hose comes off the top of the grip.
			expect(frames.inlet.Position:Dot(along) < 0).to.equal(true)
		end)

		it("stands upright at no angle (stowed on the pack)", function()
			local frames = VacuumHoldFormulas.wand(WAND, 0.4, 0)
			expect(frames.tube.Position.X).to.be.near(0, 1e-6)
			expect(frames.tube.Position.Z).to.be.near(0, 1e-6)
			expect(frames.head.Position.Y < frames.tube.Position.Y).to.equal(true)
		end)
	end)

	describe("generic backpack fit", function()
		it("mounts on the back face of a box torso, a little above its middle", function()
			local fit =
				VacuumHoldFormulas.genericFit(Vector3.new(2, 1.6, 1), Vector3.new(0.955, 1.96, 1.006), 0.84, 1.25)
			expect(fit.mount.Position.Z).to.be.near(0.5, 1e-6)
			expect(fit.mount.Position.Y > 0).to.equal(true)
			expect(fit.size).to.equal(1.25)
			-- Loops around a deeper torso than Pippa's are deeper, never inside it.
			expect(fit.strapStretch.Z * 0.84 > 1).to.equal(true)
			expect(fit.strapStretch.X).to.be.near(2 / 0.955, 1e-6)
		end)
	end)
end
