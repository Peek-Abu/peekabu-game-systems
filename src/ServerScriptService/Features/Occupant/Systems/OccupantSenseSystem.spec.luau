local Sense = require(script.Parent.OccupantSenseSystem)
return function()
	it("knows each hiding spot and seats a desk on its art chair, facing the desk", function()
		local office = Instance.new("Model")
		local desk = Instance.new("Part")
		desk.Size = Vector3.new(5, 3, 3)
		desk.CFrame = CFrame.new(10, 1.5, 10)
		desk:SetAttribute("OfficeMarkerId", "d1")
		desk.Parent = office
		local chair = Instance.new("Part")
		chair.Size = Vector3.new(2, 3.5, 2)
		chair.Position = Vector3.new(10, 1.75, 6.95)
		chair:SetAttribute("OfficeArtKey", "officeChair")
		chair:SetAttribute("OfficeDeskMarker", "d1")
		chair.Parent = office
		local table_ = Instance.new("Part")
		table_.Size = Vector3.new(5, 3.1, 3)
		table_.CFrame = CFrame.new(40, 1.55, 10)
		table_.Parent = office
		local spots = {
			{ id = "a", kind = "under", noun = "desk", furniture = desk, frame = desk.CFrame },
			{ id = "b", kind = "under", noun = "table", furniture = table_, frame = table_.CFrame },
		}
		local desks, views = Sense.furniture(spots, 4.6)
		expect(#views).to.equal(2)
		expect(views[1].deskId).to.equal("d1")
		expect(views[2].deskId).to.equal(nil)
		expect(#desks).to.equal(1)
		expect(desks[1].id).to.equal("d1")
		expect(desks[1].spotId).to.equal("a")
		expect(desks[1].front).to.equal(true)
		expect((desks[1].seat.Position - Vector3.new(10, 4.6, 6.95)).Magnitude < 1e-3).to.equal(true)
		expect(desks[1].seat.LookVector.Z > 0.99).to.equal(true)
		office:Destroy()
	end)
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
