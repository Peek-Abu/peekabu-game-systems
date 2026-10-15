local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local Push = require(script.Parent.CarryPushSystem)
return function()
	local character, root, torso, item, motor, system, release
	-- A carrier whose torso rests 1 stud above its root, pushing an item 3 studs ahead of it.
	beforeEach(function()
		character = Instance.new("Model")
		root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CFrame = CFrame.new(0, 3, 0)
		root.Parent = character
		torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Anchored = true
		torso.CFrame = CFrame.new(0, 4, 0)
		torso.Parent = character
		item = Instance.new("Part")
		item.Parent = character
		motor = Instance.new("Motor6D")
		motor.Part0 = root
		motor.Part1 = item
		motor.C0 = CFrame.new(0, -2, -3)
		motor:SetAttribute(CarryConstants.TORSO_REST_ATTRIBUTE, Vector3.new(0, 1, 0))
		motor.Parent = item
		system = Push.new()
		release = system.track(motor)
	end)
	afterEach(function()
		release()
		character:Destroy()
	end)

	it("leaves the item where it was planned while the torso is at rest", function()
		system.step()
		expect(motor.Transform:FuzzyEq(CFrame.identity, 1e-6)).to.equal(true)
	end)

	it("slides the item level along the floor with the torso, never up, down or tilted", function()
		torso.CFrame = CFrame.new(0.2, 3.7, -1) * CFrame.Angles(math.rad(-30), 0, 0)
		system.step()
		local placed = root.CFrame * motor.C0 * motor.Transform
		expect(placed.Position:FuzzyEq(Vector3.new(0.2, 1, -4), 1e-4)).to.equal(true)
		expect(placed.UpVector:FuzzyEq(Vector3.yAxis, 1e-4)).to.equal(true)
	end)

	it("follows in the root's frame when the carrier has turned", function()
		root.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0)
		torso.CFrame = root.CFrame * CFrame.new(0, 1, -0.5)
		system.step()
		local placed = root.CFrame * motor.C0 * motor.Transform
		expect(placed.Position:FuzzyEq((root.CFrame * CFrame.new(0, -2, -3.5)).Position, 1e-4)).to.equal(true)
	end)

	it("skips a joint without a rest place, and puts the joint back at rest on release", function()
		motor:SetAttribute(CarryConstants.TORSO_REST_ATTRIBUTE, nil)
		torso.CFrame = CFrame.new(0, 4, -1)
		system.step()
		expect(motor.Transform:FuzzyEq(CFrame.identity, 1e-6)).to.equal(true)
		motor:SetAttribute(CarryConstants.TORSO_REST_ATTRIBUTE, Vector3.new(0, 1, 0))
		system.step()
		expect(motor.Transform:FuzzyEq(CFrame.identity, 1e-6)).to.equal(false)
		expect(system.getState().tracked).to.equal(1)
		release()
		expect(motor.Transform:FuzzyEq(CFrame.identity, 1e-6)).to.equal(true)
		expect(system.getState().tracked).to.equal(0)
	end)
end
