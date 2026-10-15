local Sense = require(script.Parent.OccupantSenseSystem)
return function()
	it("measures R15 and R6 feet without accessories affecting catch reach", function()
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Position = Vector3.new(0, 10, 0)
		root.Parent = model
		local h = Instance.new("Humanoid")
		h.HipHeight = 2
		h.RigType = Enum.HumanoidRigType.R15
		h.Parent = model
		expect(Sense.feetY(root, h)).to.equal(7)
		h.RigType = Enum.HumanoidRigType.R6
		h.HipHeight = 0
		local leg = Instance.new("Part")
		leg.Name = "Left Leg"
		leg.Size = Vector3.new(1, 2, 1)
		leg.Parent = model
		expect(Sense.feetY(root, h)).to.equal(7)
		model:Destroy()
	end)
end
