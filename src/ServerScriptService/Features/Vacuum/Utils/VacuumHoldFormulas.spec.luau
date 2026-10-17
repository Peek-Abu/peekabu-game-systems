local VacuumHoldFormulas = require(script.Parent.VacuumHoldFormulas)

return function()
	-- A Pippa-like holder at 1.25x, root space: right shoulder 1.15 up and 0.45 right, arm 0.525 + 1.1 to the
	-- grip, floor 1.375 below the root.
	local RIGHT = { shoulder = Vector3.new(0.45, 1.15, 0), upper = 0.525, lower = 1.1 }
	local LEFT = { shoulder = Vector3.new(-0.45, 1.15, 0), upper = 0.525, lower = 1.1 }
	local FLOOR = -1.375
	-- GripUpper 0.125 up the grip from its centre, GripLower 0.4375 down the tube from its top.
	local WAND = { gripHalf = 0.25, inlet = 0.1125, swivel = 0.075, head = 0.106, upper = 0.125, lower = 0.4375 }
	local TUNING = {
		down = 0.05,
		forward = 0.6,
		out = 0.05,
		angle = math.rad(50),
		yaw = math.rad(65),
		clearance = 0.06,
		minTube = 0.3,
	}
	local ALONG = Vector3.new(
		-math.sin(TUNING.angle) * math.sin(TUNING.yaw),
		-math.cos(TUNING.angle),
		-math.sin(TUNING.angle) * math.cos(TUNING.yaw)
	)

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

	describe("stowTube", function()
		it("telescopes the stowed wand so its floor head's bottom hangs at the hip, at its lean", function()
			local lean = math.rad(22)
			-- The grip's centre 1.5 above the hip joint.
			local tube = VacuumHoldFormulas.stowTube(1.5, WAND, lean, 0.3, 3)
			local drop = (WAND.gripHalf + tube + WAND.swivel) * math.cos(lean) + WAND.swivel + WAND.head
			expect(drop).to.be.near(1.5, 1e-4)
		end)

		it("is never longer than the held tube nor shorter than the shortest", function()
			expect(VacuumHoldFormulas.stowTube(5, WAND, 0, 0.3, 1.2)).to.equal(1.2)
			expect(VacuumHoldFormulas.stowTube(0.2, WAND, 0, 0.3, 1.2)).to.equal(0.3)
		end)
	end)

	describe("hold", function()
		local hold = VacuumHoldFormulas.hold(RIGHT, LEFT, FLOOR, WAND, TUNING)

		it(
			"holds the right hand in front of and below the shoulder, inside the arm's reach so the elbow bends",
			function()
				local grip = hold.grip.Position
				local reach = RIGHT.upper + RIGHT.lower
				expect(grip.Z < -0.5).to.equal(true)
				expect(grip.Y < RIGHT.shoulder.Y).to.equal(true)
				-- On the right of the body, not in the middle.
				expect(grip.X > 0.15).to.equal(true)
				local distance = (grip - RIGHT.shoulder).Magnitude
				expect(distance < 0.85 * reach).to.equal(true)
				expect(distance > 0.4 * reach).to.equal(true)
			end
		)

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

		it("gives a Tool.Grip that puts GripUpper in the hand, the handle square to the root below it", function()
			-- handle = gripAttachment * Grip:Inverse()
			local handle = hold.grip * hold.toolGrip:Inverse()
			-- The grip's centre is `upper` down the wand from the hand.
			expect((handle.Position - (hold.grip.Position + ALONG * WAND.upper)).Magnitude < 1e-4).to.equal(true)
			expect(handle.LookVector:Dot(Vector3.new(0, 0, -1))).to.be.near(1, 1e-4)
			expect(handle.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-4)
		end)

		it("sizes the tube from the grip's height so the head rests on the floor", function()
			local height = (hold.grip.Position + ALONG * WAND.upper).Y - FLOOR
			expect(hold.tube).to.be.near(
				VacuumHoldFormulas.tube(height, WAND, TUNING.angle, TUNING.clearance, TUNING.minTube),
				1e-6
			)
			expect(hold.height).to.be.near(height, 1e-6)
		end)

		it("puts the left hand lower down the wand, on GripLower, when it reaches (not beside the right)", function()
			expect(hold.left).to.be.ok()
			local left = hold.left.Position
			-- On the wand's axis, upper + grip half + lower below the right hand.
			local expected = hold.grip.Position + ALONG * (WAND.upper + WAND.gripHalf + WAND.lower)
			expect((left - expected).Magnitude < 1e-4).to.equal(true)
			-- A clear hand-span apart (Pippa's big round hands touched, a "clap", 0.5 apart).
			expect((left - hold.grip.Position).Magnitude > 0.8).to.equal(true)
			expect(hold.grip.Position.Y - left.Y > 0.5).to.equal(true)
			-- In front of the middle of the body, further out than the right hand.
			expect(math.abs(left.X) < 0.25).to.equal(true)
			expect(left.Z < hold.grip.Position.Z).to.equal(true)
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

		it(
			"puts each paw's wrap point, not its grip attachment's tip, on its grip (the paw closes round the wand)",
			function()
				-- Pippa's grip attachments sit at the very tip of her paw; the wrap point is inside the paw.
				local wrapRight =
					{ shoulder = RIGHT.shoulder, upper = RIGHT.upper, lower = 0.9, wrap = Vector3.new(0, 0, 0.2) }
				local wrapLeft =
					{ shoulder = LEFT.shoulder, upper = LEFT.upper, lower = 0.9, wrap = Vector3.new(0, 0, 0.2) }
				local wrapped = VacuumHoldFormulas.hold(wrapRight, wrapLeft, FLOOR, WAND, TUNING)
				-- The wrap point lands where GripUpper is; the attachment itself sits `wrap` past it.
				expect((wrapped.grip:PointToWorldSpace(wrapRight.wrap) - wrapped.rightAt).Magnitude < 1e-4).to.equal(
					true
				)
				expect((wrapped.grip.Position - wrapped.rightAt).Magnitude).to.be.near(0.2, 1e-4)
				-- The handle still hangs `upper` down the wand from GripUpper, square to the root.
				local handle = wrapped.grip * wrapped.toolGrip:Inverse()
				expect((handle.Position - (wrapped.rightAt + ALONG * WAND.upper)).Magnitude < 1e-4).to.equal(true)
				expect(handle.LookVector:Dot(Vector3.new(0, 0, -1))).to.be.near(1, 1e-4)
				-- The left paw's wrap point on GripLower.
				expect(wrapped.left).to.be.ok()
				local lowerAt = wrapped.rightAt + ALONG * (WAND.upper + WAND.gripHalf + WAND.lower)
				expect((wrapped.leftAt - lowerAt).Magnitude < 1e-4).to.equal(true)
				expect((wrapped.left:PointToWorldSpace(wrapLeft.wrap) - lowerAt).Magnitude < 1e-4).to.equal(true)
				-- The left arm's shoulder and reach go with it (the motion layers keep GripLower inside it).
				expect(wrapped.leftShoulder).to.equal(wrapLeft.shoulder)
				expect(wrapped.leftReach).to.be.near(wrapLeft.upper + wrapLeft.lower, 1e-6)
			end
		)

		it("has the wrap points on the grips themselves when the arms give none", function()
			expect((hold.rightAt - hold.grip.Position).Magnitude < 1e-6).to.equal(true)
			expect((hold.leftAt - hold.left.Position).Magnitude < 1e-6).to.equal(true)
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

	describe("axis", function()
		it("leans forward by the angle and turns its lower end toward the left by the yaw", function()
			local axis = VacuumHoldFormulas.axis(math.rad(35), math.rad(40))
			expect(axis.Magnitude).to.be.near(1, 1e-6)
			expect(axis.Y).to.be.near(-math.cos(math.rad(35)), 1e-6)
			expect(axis.X < 0 and axis.Z < 0).to.equal(true)
			expect(VacuumHoldFormulas.axis(math.rad(35), 0).X).to.be.near(0, 1e-6)
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

		it(
			"turns along its yaw, the floor head staying square to the handle and every piece's +Y up the wand",
			function()
				local yaw = math.rad(40)
				local frames = VacuumHoldFormulas.wand(WAND, 1.2, math.rad(35), nil, yaw)
				local along = VacuumHoldFormulas.axis(math.rad(35), yaw)
				expect(frames.tube.Position.Unit:Dot(along)).to.be.near(1, 1e-4)
				expect(frames.grip.UpVector:Dot(-along)).to.be.near(1, 1e-4)
				expect(frames.tube.UpVector:Dot(-along)).to.be.near(1, 1e-4)
				expect(frames.head.RightVector:Dot(Vector3.xAxis)).to.be.near(1, 1e-6)
				-- The hose frame stays orthonormal (its X into the wand).
				expect(frames.hose.RightVector:Dot(along)).to.be.near(1, 1e-4)
			end
		)

		it("stands upright at no angle (stowed on the pack)", function()
			local frames = VacuumHoldFormulas.wand(WAND, 0.4, 0)
			expect(frames.tube.Position.X).to.be.near(0, 1e-6)
			expect(frames.tube.Position.Z).to.be.near(0, 1e-6)
			expect(frames.head.Position.Y < frames.tube.Position.Y).to.equal(true)
		end)

		it("leans out and back along the pack when stowed, its floor head square to the lean and flat", function()
			-- A yaw past a half turn swings the lower end to +X (out on the right) and +Z (behind).
			local lean, turn = math.rad(22), math.rad(-130)
			local frames = VacuumHoldFormulas.wand(WAND, 1, lean, turn, turn)
			local along = VacuumHoldFormulas.axis(lean, turn)
			expect(along.X > 0 and along.Z > 0 and along.Y < 0).to.equal(true)
			expect(frames.swivel.Position.Unit:Dot(along)).to.be.near(1, 1e-4)
			-- Square to the lean: the head's long side runs across it, level.
			local flat = Vector3.new(along.X, 0, along.Z).Unit
			expect(math.abs(frames.head.RightVector:Dot(flat)) < 1e-4).to.equal(true)
			expect(frames.head.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-6)
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
