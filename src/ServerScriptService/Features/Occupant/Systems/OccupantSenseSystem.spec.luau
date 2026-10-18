local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local Sense = require(script.Parent.OccupantSenseSystem)
return function()
	it("knows each hiding spot and seats a desk on its tagged art chair in its own office, facing the desk", function()
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
		chair:AddTag(OfficeDecorConstants.CHAIR_TAG)
		chair.Parent = office
		-- Chairs are found by their tag (OfficeDecorSystem), never by scanning the office; another office's chair for
		-- a desk of the same id is not this desk's.
		local elsewhere = Instance.new("Model")
		local stranger = Instance.new("Part")
		stranger.Position = Vector3.new(90, 1.75, 90)
		stranger:SetAttribute("OfficeArtKey", "officeChair")
		stranger:SetAttribute("OfficeDeskMarker", "d1")
		stranger:AddTag(OfficeDecorConstants.CHAIR_TAG)
		stranger.Parent = elsewhere
		elsewhere.Parent = Workspace
		local table_ = Instance.new("Part")
		table_.Size = Vector3.new(5, 3.1, 3)
		table_.CFrame = CFrame.new(40, 1.55, 10)
		table_.Parent = office
		local spots = {
			{ id = "a", kind = "under", noun = "desk", furniture = desk, frame = desk.CFrame },
			{ id = "b", kind = "under", noun = "table", furniture = table_, frame = table_.CFrame },
		}
		office.Parent = Workspace
		local desks, views = Sense.furniture(spots, 4.6, function()
			return true
		end)
		expect(#views).to.equal(2)
		expect(views[1].deskId).to.equal("d1")
		expect(views[2].deskId).to.equal(nil)
		expect(#desks).to.equal(1)
		expect(desks[1].id).to.equal("d1")
		expect(desks[1].spotId).to.equal("a")
		expect(desks[1].front).to.equal(true)
		expect(desks[1].frame).to.equal(desk.CFrame)
		expect(desks[1].size).to.equal(desk.Size)
		expect((desks[1].seat.Position - Vector3.new(10, 4.6, 6.95)).Magnitude < 1e-3).to.equal(true)
		expect(desks[1].seat.LookVector.Z > 0.99).to.equal(true)
		office:Destroy()
		elsewhere:Destroy()
	end)
	it("knows a supply cabinet as a secure spot, a desk or table as not", function()
		local cabinet = Instance.new("Part")
		cabinet.Size = Vector3.new(3.6, 7.6, 2.8)
		cabinet.CFrame = CFrame.new(0, 3.8, 0)
		local desk = Instance.new("Part")
		desk.Size = Vector3.new(5, 3, 3)
		desk.CFrame = CFrame.new(10, 1.5, 10)
		local _, views = Sense.furniture({
			{ id = "c", kind = "inside", noun = "cabinet", furniture = cabinet, frame = cabinet.CFrame },
			{ id = "d", kind = "under", noun = "table", furniture = desk, frame = desk.CFrame },
		}, 4.6)
		expect(views[1].secure).to.equal(true)
		expect(views[2].secure).to.equal(false)
		cabinet:Destroy()
		desk:Destroy()
	end)
	it("stands him to stare where a body fits: the other side, else straight out, never into furniture", function()
		local cabinet = Instance.new("Part")
		cabinet.Size = Vector3.new(4.3, 8, 3.45)
		cabinet.CFrame = CFrame.new(0, 4, 0)
		local spots = { { id = "c", kind = "inside", noun = "cabinet", furniture = cabinet, frame = cabinet.CFrame } }
		-- A table stands on the +X side: only the -X point fits.
		local _, views = Sense.furniture(spots, 4.6, function(point)
			return point.X < 0
		end)
		expect(views[1].stand.X < 0).to.equal(true)
		-- Both sides blocked: straight out in front.
		local _, straight = Sense.furniture(spots, 4.6, function(point)
			return math.abs(point.X) < 0.5
		end)
		expect(math.abs(straight[1].stand.X) < 1e-4).to.equal(true)
		expect(straight[1].stand.Z < -cabinet.Size.Z / 2).to.equal(true)
		cabinet:Destroy()
	end)
	it("casts his sight rays as far as his long sight", function()
		local C = require(game:GetService("ReplicatedStorage").Shared.Features.Occupant.Data.OccupantConstants)
		expect(Sense.rayRange(C.SIGHT_RANGE)).to.equal(C.LONG_SIGHT_RANGE)
		expect(Sense.rayRange(500)).to.equal(500)
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
