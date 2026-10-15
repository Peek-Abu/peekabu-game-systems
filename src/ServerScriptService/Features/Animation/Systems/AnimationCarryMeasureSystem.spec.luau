local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Measure = require(ServerScriptService.Features.Animation.Systems.AnimationCarryMeasureSystem)
local Harness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
return function()
	local ORIGIN = Vector3.new(0, 3000, 600)
	local function settle()
		for _ = 1, 4 do
			RunService.Heartbeat:Wait()
		end
	end
	local rig
	beforeEach(function()
		rig = Harness.stockR15(ORIGIN)
	end)
	afterEach(function()
		rig:Destroy()
	end)

	describe("measure", function()
		it("reads both arms bone by bone at rest, through the avatar's AnimationConstraint joints", function()
			local measured = Measure.measure(rig)
			expect(measured).to.be.ok()
			-- The stock R15's shoulder joint (root space): the UpperTorso's RightShoulderRigAttachment.
			expect(measured.right.shoulder:FuzzyEq(Vector3.new(0.9716, 0.8465, 0), 1e-3)).to.equal(true)
			expect(measured.left.shoulder:FuzzyEq(Vector3.new(-0.9716, 0.8465, 0), 1e-3)).to.equal(true)
			-- The hand hangs at rest below the lower arm, its palm facing the body.
			expect(measured.right.palmInHand.UpVector:FuzzyEq(-Vector3.xAxis, 1e-3)).to.equal(true)
			expect(measured.floor).to.be.near(-1 - 2.1924, 1e-3)
		end)

		it("slices the torso and head from their real surface", function()
			local measured = Measure.measure(rig)
			expect(#measured.body >= 8).to.equal(true)
			-- A block torso: every slice is as wide as the part.
			for _, slice in measured.body do
				expect(slice.radii.X > 0.9).to.equal(true)
			end
			expect(measured.front).to.be.near(-0.502, 0.01)
			expect(measured.torsoHalfWidth).to.be.near(1, 0.01)
			expect(#measured.head >= 1).to.equal(true)
		end)

		it("measures the torso and head at rest, not at whatever frame an animation is on", function()
			local rest = Measure.measure(rig)
			local waist = rig.UpperTorso:FindFirstChildOfClass("AnimationConstraint")
			waist.Transform = CFrame.Angles(math.rad(-20), 0, 0)
			settle()
			local leaning = Measure.measure(rig)
			expect(leaning.right.shoulder:FuzzyEq(rest.right.shoulder, 1e-3)).to.equal(true)
			expect(leaning.headFront).to.be.near(rest.headFront, 1e-3)
		end)

		it("refuses a rig without native arms", function()
			rig.RightHand:Destroy()
			expect(Measure.measure(rig)).to.equal(nil)
		end)
	end)

	it("finds each palm from the rig: facing the body on a hanging hand, fingers down the arm", function()
		local palm = Measure.palmOf(rig, "Right")
		expect(palm.UpVector:FuzzyEq(-Vector3.xAxis, 1e-3)).to.equal(true)
		expect(palm.LookVector:FuzzyEq(-Vector3.yAxis, 1e-3)).to.equal(true)
		local arm = Measure.armOf(rig, "Left")
		expect(arm.side).to.equal(-1)
		expect(arm.gripInHand.Position:FuzzyEq(rig.LeftHand.LeftGripAttachment.Position, 1e-4)).to.equal(true)
	end)

	it("reads a part's rest frame through its joints, whatever the animation", function()
		local rest = Measure.restFrame(rig.RightHand, rig.HumanoidRootPart)
		rig.RightLowerArm:FindFirstChildOfClass("AnimationConstraint").Transform = CFrame.Angles(math.rad(60), 0, 0)
		settle()
		expect(Measure.restFrame(rig.RightHand, rig.HumanoidRootPart):FuzzyEq(rest, 1e-4)).to.equal(true)
	end)
end
