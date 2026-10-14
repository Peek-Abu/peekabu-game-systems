local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local Formulas = require(ReplicatedStorage.Client.Features.Animation.Utils.AnimationCarryGrabFormulas)
local AnimationCarryGrabSystem = require(script.Parent.AnimationCarryGrabSystem)

return function()
	local HOLD = CFrame.new(0, 2.5, -1.5)
	local FLOOR = CFrame.new(0, 0.5, -3)

	local function addPart(parent, name, cframe)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = cframe
		p.Parent = parent
		return p
	end

	-- A carrier holding a box at HOLD, with the server's carry IK (right and left) on its Humanoid.
	local function makeScene()
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		local lowerTorso = addPart(character, "LowerTorso", CFrame.new(0, 1.5, 0))
		local cargo = Instance.new("Model")
		local root = addPart(cargo, "Root", HOLD)
		cargo.PrimaryPart = root
		local controls = {}
		for _, side in { "Right", "Left" } do
			local upper = addPart(character, side .. "UpperArm", CFrame.new(0, 2.5, 0))
			local hand = addPart(character, side .. "Hand", CFrame.new(0, 1.5, 0))
			local grip = Instance.new("Attachment")
			grip.Name = "CleanupCarryGrip" .. side
			grip.Parent = root
			local control = Instance.new("IKControl")
			control.Name = "CleanupCarryIK" .. side
			control.ChainRoot = upper
			control.EndEffector = hand
			control.Target = grip
			control.SmoothTime = 0.08
			control.Parent = humanoid
			controls[side] = { control = control, upper = upper, grip = grip }
		end
		-- The grab ends early when the carrier or the cargo leaves the world, so both live in one.
		local world = Instance.new("Folder")
		character.Parent = world
		cargo.Parent = world
		local stage = Instance.new("Folder")
		stage.Parent = world
		return character, cargo, root, controls, lowerTorso, stage
	end

	local function ghostOf(stage)
		return stage:FindFirstChildWhichIsA("Model")
	end

	describe("play", function()
		it("shows the cargo where it lay, hides the held one, and points the arms (with a waist bend) at it", function()
			local character, cargo, root, controls, lowerTorso, stage = makeScene()
			local grab = AnimationCarryGrabSystem.play(character, cargo, FLOOR, stage)
			expect(grab).to.be.ok()
			grab.step(0)
			local ghost = ghostOf(stage)
			expect(ghost).to.be.ok()
			expect((ghost:GetPivot().Position - FLOOR.Position).Magnitude < 1e-3).to.equal(true)
			expect(root.LocalTransparencyModifier).to.equal(1)
			for _, side in { "Right", "Left" } do
				local control = controls[side].control
				expect(control.Target).never.to.equal(controls[side].grip)
				expect(control.Target:IsDescendantOf(ghost)).to.equal(true)
				expect(control.ChainRoot).to.equal(lowerTorso)
			end
			for _, part in ghost:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).to.equal(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
				end
			end
			grab.cancel()
			character:Destroy()
			cargo:Destroy()
			stage:Destroy()
		end)

		it("lifts it into the hold and then hands everything back: real cargo shown, server IK restored", function()
			local character, cargo, root, controls, _, stage = makeScene()
			local grab = AnimationCarryGrabSystem.play(character, cargo, FLOOR, stage)
			expect(grab.step(Formulas.REACH_SECONDS + Formulas.LIFT_SECONDS / 2)).to.equal(false)
			expect(ghostOf(stage):GetPivot().Position.Y > FLOOR.Position.Y).to.equal(true)
			expect(grab.step(Formulas.LIFT_SECONDS)).to.equal(true)
			expect(ghostOf(stage)).never.to.be.ok()
			expect(root.LocalTransparencyModifier).to.equal(0)
			for _, side in { "Right", "Left" } do
				expect(controls[side].control.Target).to.equal(controls[side].grip)
				expect(controls[side].control.ChainRoot).to.equal(controls[side].upper)
				expect(controls[side].control.SmoothTime).to.be.near(0.08, 1e-6)
			end
			character:Destroy()
			cargo:Destroy()
			stage:Destroy()
		end)

		it("restores everything when cancelled midway", function()
			local character, cargo, root, controls, _, stage = makeScene()
			local grab = AnimationCarryGrabSystem.play(character, cargo, FLOOR, stage)
			grab.step(0.05)
			grab.cancel()
			expect(ghostOf(stage)).never.to.be.ok()
			expect(root.LocalTransparencyModifier).to.equal(0)
			expect(controls.Right.control.Target).to.equal(controls.Right.grip)
			character:Destroy()
			cargo:Destroy()
			stage:Destroy()
		end)

		it("still shows the scoop when the carry IK has not arrived (no arms to move)", function()
			local character, cargo, _, controls, _, stage = makeScene()
			controls.Right.control:Destroy()
			controls.Left.control:Destroy()
			local grab = AnimationCarryGrabSystem.play(character, cargo, FLOOR, stage)
			expect(grab).to.be.ok()
			grab.step(0)
			expect(ghostOf(stage)).to.be.ok()
			grab.cancel()
			character:Destroy()
			cargo:Destroy()
			stage:Destroy()
		end)

		it("ends early, handing everything back, when the cargo leaves the world", function()
			local character, cargo, root, controls, _, stage = makeScene()
			local grab = AnimationCarryGrabSystem.play(character, cargo, FLOOR, stage)
			grab.step(0)
			cargo.Parent = nil
			expect(grab.step(0.01)).to.equal(true)
			expect(ghostOf(stage)).never.to.be.ok()
			expect(root.LocalTransparencyModifier).to.equal(0)
			expect(controls.Right.control.Target).to.equal(controls.Right.grip)
			character:Destroy()
			cargo:Destroy()
			stage:Destroy()
		end)

		it("does not play for cargo that did not travel (or travelled implausibly far)", function()
			local character, cargo, _, _, _, stage = makeScene()
			expect(AnimationCarryGrabSystem.play(character, cargo, HOLD, stage)).never.to.be.ok()
			expect(AnimationCarryGrabSystem.play(character, cargo, CFrame.new(0, 0, -200), stage)).never.to.be.ok()
			character:Destroy()
			cargo:Destroy()
			stage:Destroy()
		end)
	end)

	describe("origin", function()
		it("reads the server's pickup origin from a carried object", function()
			local part = Instance.new("Part")
			expect(AnimationCarryGrabSystem.origin(part)).never.to.be.ok()
			part:SetAttribute(CarryConstants.CARRY_FROM_ATTRIBUTE, FLOOR)
			expect(AnimationCarryGrabSystem.origin(part)).to.equal(FLOOR)
			part:SetAttribute(CarryConstants.CARRY_FROM_ATTRIBUTE, "nope")
			expect(AnimationCarryGrabSystem.origin(part)).never.to.be.ok()
			part:Destroy()
		end)
	end)
end
