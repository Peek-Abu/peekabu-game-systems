local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotHubSystem = require(script.Parent.DepotHubSystem)
local HUB = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants).HUB

local function marker(parent, tag, cframe, size, attributes)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size or Vector3.new(2, 1, 2)
	part.CFrame = cframe
	for key, value in attributes or {} do
		part:SetAttribute(key, value)
	end
	CollectionService:AddTag(part, tag)
	part.Parent = parent
	return part
end

return function()
	local container
	beforeEach(function()
		container = Instance.new("Folder")
		container.Name = "DepotHubSpec"
		container.Parent = workspace
	end)
	afterEach(function()
		container:Destroy()
	end)

	local function hub()
		local model = Instance.new("Model")
		CollectionService:AddTag(model, HUB.MODEL_TAG)
		model.Parent = container
		return model
	end

	it("finds the tagged hub model inside the container, and nothing when there is none", function()
		expect(DepotHubSystem.find(container)).to.equal(nil)
		local model = hub()
		expect(DepotHubSystem.find(container)).to.equal(model)
	end)

	it("reads each tagged marker as standing on the floor under it, with its attributes", function()
		local model = hub()
		local turned = CFrame.new(10, 1.5, 20) * CFrame.Angles(0, math.rad(90), 0)
		marker(model, HUB.TRUCK_TAG, turned, Vector3.new(16, 3, 24), {
			[HUB.TRUCK_ATTRIBUTE] = 2,
			[HUB.CAPACITY_ATTRIBUTE] = 4,
		})
		marker(model, HUB.SPAWN_TAG, CFrame.new(0, 0.5, 0))
		marker(model, HUB.BOARD_TAG, CFrame.new(5, 0.5, 5), nil, { [HUB.BOARD_ATTRIBUTE] = "result" })
		-- Outside the hub: ignored.
		marker(container, HUB.SPAWN_TAG, CFrame.new(99, 0, 99))
		local found = DepotHubSystem.markers(model)
		expect(#found).to.equal(3)
		local truck, spawn, board
		for _, entry in found do
			if entry.kind == "truck" then
				truck = entry
			elseif entry.kind == "spawn" then
				spawn = entry
			else
				board = entry
			end
		end
		expect(truck.truck).to.equal(2)
		expect(truck.capacity).to.equal(4)
		expect(truck.countdown).to.equal(nil)
		expect((truck.cframe.Position - Vector3.new(10, 0, 20)).Magnitude < 1e-3).to.equal(true)
		expect(truck.cframe.LookVector:Dot(turned.LookVector) > 0.999).to.equal(true)
		expect(spawn.cframe.Position.Y).to.be.near(0)
		expect(board.board).to.equal("result")
	end)

	it("hides the markers so players never see or bump them", function()
		local model = hub()
		local part = marker(model, HUB.SPAWN_TAG, CFrame.new(0, 0.5, 0))
		DepotHubSystem.hide(model)
		expect(part.Transparency).to.equal(1)
		expect(part.CanCollide).to.equal(false)
		expect(part.CanQuery).to.equal(false)
		expect(part.CanTouch).to.equal(false)
	end)

	it("bounds the whole hub", function()
		local model = hub()
		marker(model, HUB.SPAWN_TAG, CFrame.new(0, 0.5, 0))
		marker(model, HUB.SPAWN_TAG, CFrame.new(40, 0.5, 0))
		local bounds = DepotHubSystem.bounds(model)
		expect(bounds.size.X).to.be.near(42)
	end)
end
