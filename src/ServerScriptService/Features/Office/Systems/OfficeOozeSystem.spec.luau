local OfficeOozeSystem = require(script.Parent.OfficeOozeSystem)

local DOOR = CFrame.lookAt(Vector3.zero, -Vector3.zAxis)

local function partsOf(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function named(model, name)
	local list = {}
	for _, part in partsOf(model) do
		if part.Name == name then
			table.insert(list, part)
		end
	end
	return list
end

-- How far out of a door at the origin (looking down -Z) a puddle reaches.
local function reachOf(part)
	return -part.Position.Z + part.Size.Z / 2
end

return function()
	local folder
	beforeEach(function()
		folder = Instance.new("Folder")
	end)
	afterEach(function()
		folder:Destroy()
	end)

	it("builds nothing for none", function()
		expect(OfficeOozeSystem.build("none", DOOR, 14, folder)).to.equal(nil)
		expect(#folder:GetChildren()).to.equal(0)
	end)

	it("spills a lot on the yard side, inside the door's width, never colliding", function()
		local model = OfficeOozeSystem.build("lot", DOOR, 14, folder)
		expect(model).to.be.ok()
		expect(model.Parent).to.equal(folder)
		local all = partsOf(model)
		expect(#all > 3).to.equal(true)
		for _, part in all do
			expect(part.Position.Z <= 0).to.equal(true)
			expect(math.abs(part.Position.X) <= 8).to.equal(true)
			if part.Name == "Puddle" then
				expect(math.abs(part.Position.X) + part.Size.Y / 2 <= 7.01).to.equal(true)
			end
			expect(part.CanCollide).to.equal(false)
			expect(part.CanQuery).to.equal(false)
			expect(part.CastShadow).to.equal(false)
		end
	end)

	it("reaches 10 studs out for a lot, and no further", function()
		local model = OfficeOozeSystem.build("lot", DOOR, 14, folder)
		local reach = 0
		for _, puddle in named(model, "Puddle") do
			reach = math.max(reach, reachOf(puddle))
		end
		expect(reach > 9.9).to.equal(true)
		expect(reach <= 10.01).to.equal(true)
	end)

	it("makes 3 streaks on the door's lower edge for a lot", function()
		local model = OfficeOozeSystem.build("lot", DOOR, 14, folder)
		expect(#named(model, "Streak")).to.equal(3)
	end)

	it("makes at most 2 puddles within 4 studs of the door for a little", function()
		local model = OfficeOozeSystem.build("little", DOOR, 14, folder)
		local all = partsOf(model)
		expect(#all).to.equal(2)
		for _, part in all do
			expect(part.Position.Z <= 0).to.equal(true)
			expect(reachOf(part) <= 4.01).to.equal(true)
			expect(part.CanCollide).to.equal(false)
			expect(part.CanQuery).to.equal(false)
			expect(part.CastShadow).to.equal(false)
		end
	end)

	it("follows the door frame in the world", function()
		local frame = CFrame.new(100, 5, 200) * CFrame.Angles(0, math.pi / 2, 0)
		local model = OfficeOozeSystem.build("lot", frame, 14, folder)
		for _, part in partsOf(model) do
			expect(frame:PointToObjectSpace(part.Position).Z <= 0).to.equal(true)
		end
	end)

	describe("buildAtDock", function()
		local layout = {
			entrances = {
				{ id = "lobby", outside = { x = 1, z = 1, yaw = 0 } },
				{ id = "dock", outside = { x = 100, z = 200, yaw = 0 } },
			},
		}
		local origin = CFrame.new(0, 5, 0)

		it("builds at the dock's outside door, in the world", function()
			local model = OfficeOozeSystem.buildAtDock(layout, origin, 1300, folder)
			expect(model).to.be.ok()
			expect(model.Parent).to.equal(folder)
			for _, part in partsOf(model) do
				expect(part.Position.Z <= 200).to.equal(true)
				expect(math.abs(part.Position.X - 100) <= 8).to.equal(true)
			end
		end)

		it("builds nothing for a clean site", function()
			expect(OfficeOozeSystem.buildAtDock(layout, origin, 500, folder)).to.equal(nil)
		end)

		it("builds nothing without a dock entrance", function()
			local noDock = { entrances = { layout.entrances[1] } }
			expect(OfficeOozeSystem.buildAtDock(noDock, origin, 1300, folder)).to.equal(nil)
		end)
	end)
end
