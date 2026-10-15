local Placement = require(script.Parent.CargoSearchPlacementSystem)
return function()
	local scene
	beforeEach(function()
		scene = Instance.new("Model")
		scene.Name = "SearchPlacementSpec"
		scene.Parent = workspace
	end)
	afterEach(function()
		scene:Destroy()
	end)
	local function block(name, size, position)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = position
		p.Anchored = true
		p.Parent = scene
		return p
	end
	it("lands bulky loot on the floor away from a nonqueryable chair", function()
		block("Floor", Vector3.new(30, 1, 30), Vector3.new(30000, -0.5, 0))
		local desk = block("Desk", Vector3.new(5, 3, 3), Vector3.new(30000, 1.5, 0))
		local chair = block("Chair", Vector3.new(3, 4, 3), Vector3.new(30000, 2, -3))
		chair.CanCollide = false
		chair.CanQuery = false
		chair:SetAttribute("OfficeArtKey", "officeChair")
		local size = Vector3.new(3.5, 4, 3.5)
		local cf = Placement.findFloor(desk, size, scene)
		expect(cf ~= nil).to.equal(true)
		expect(cf.Position.Y).to.be.near(0, 0.01)
		expect(math.abs(cf.Position.X - chair.Position.X) >= 3.25 or math.abs(cf.Position.Z - chair.Position.Z) >= 3.25).to.equal(
			true
		)
		expect(math.abs(cf.Position.X - desk.Position.X) >= 4.25 or math.abs(cf.Position.Z - desk.Position.Z) >= 3.25).to.equal(
			true
		)
	end)
	it("never lands loot past a wall, even over the same building's floor", function()
		-- One slab runs under the wall (a foundation), so only the wall itself keeps the loot in.
		block("Floor", Vector3.new(40, 1, 40), Vector3.new(35000, -0.5, 0))
		local desk = block("Desk", Vector3.new(5, 3, 3), Vector3.new(35000, 1.5, 0))
		local wall = block("Wall", Vector3.new(0.4, 12, 40), Vector3.new(35002.8, 6, 0))
		local cf = Placement.findFloor(desk, Vector3.new(1, 1, 1), scene)
		expect(cf ~= nil).to.equal(true)
		expect(cf.Position.X < wall.Position.X - wall.Size.X / 2).to.equal(true)
	end)
	it("refuses a landing when every floor spot is past a wall", function()
		block("Floor", Vector3.new(40, 1, 40), Vector3.new(36000, -0.5, 0))
		local desk = block("Desk", Vector3.new(5, 3, 3), Vector3.new(36000, 1.5, 0))
		-- A closet just big enough for the desk: walls on every side, floor beyond them.
		block("WallE", Vector3.new(0.4, 12, 4), Vector3.new(36002.8, 6, 0))
		block("WallW", Vector3.new(0.4, 12, 4), Vector3.new(35997.2, 6, 0))
		block("WallN", Vector3.new(6, 12, 0.4), Vector3.new(36000, 6, -1.8))
		block("WallS", Vector3.new(6, 12, 0.4), Vector3.new(36000, 6, 1.8))
		expect(Placement.findFloor(desk, Vector3.new(1, 1, 1), scene)).to.equal(nil)
	end)
	it("refuses a landing when only a furniture top is available", function()
		local desk = block("Desk", Vector3.new(5, 3, 3), Vector3.new(31000, 1.5, 0))
		expect(Placement.findFloor(desk, Vector3.new(2, 2, 2), scene)).to.equal(nil)
	end)
	it("does not require a landing for an empty container", function()
		local desk = block("Desk", Vector3.new(5, 3, 3), Vector3.new(33000, 1.5, 0))
		local floor, reason = Placement.forSearch(desk, nil, scene)
		expect(floor).to.equal(nil)
		expect(reason).to.equal(nil)
	end)
	it("delivers searched cargo with its source and unchanged registry dimensions", function()
		local spawner = require(script.Parent.CargoSpawnSystem).new()
		local result = Placement.deliver("filingCabinet", scene, CFrame.new(34000, 0, 0), spawner)
		expect(string.find(result, "Found:", 1, true) ~= nil).to.equal(true)
		local item = scene:FindFirstChildWhichIsA("BasePart")
		expect(item:GetAttribute("CargoSource")).to.equal("desk")
		expect(item.Position.Y - item.Size.Y / 2).to.equal(0)
	end)
	it("delivers a desk valuable with its rolled appraisal", function()
		local spawner = require(script.Parent.CargoSpawnSystem).new()
		local appraisal = { base = 140, variant = "Solid brass", clean = 0, appraised = false }
		Placement.deliver("plaque", scene, CFrame.new(35000, 0, 0), spawner, appraisal)
		local item = scene:FindFirstChildWhichIsA("BasePart")
		expect(item:GetAttribute("CargoBaseValue")).to.equal(140)
		expect(item:GetAttribute("CargoVariant")).to.equal("Solid brass")
	end)
	it("handles rotated furniture without changing its transform or collision", function()
		block("Floor", Vector3.new(30, 1, 30), Vector3.new(32000, -0.5, 0))
		local desk = block("Desk", Vector3.new(5, 3, 3), Vector3.new(32000, 1.5, 0))
		desk.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
		local original = desk.CFrame
		expect(Placement.findFloor(desk, Vector3.new(1, 1, 1), scene) ~= nil).to.equal(true)
		expect(desk.CFrame).to.equal(original)
		expect(desk.CanCollide).to.equal(true)
	end)
end
