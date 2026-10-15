local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Dressing = require(script.Parent.OfficeSearchedDressingSystem)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)

return function()
	local folder
	beforeEach(function()
		folder = Instance.new("Folder")
		folder.Parent = Workspace
	end)
	afterEach(function()
		folder:Destroy()
	end)
	local function proxy(name, size)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(0, size.Y / 2, 0)
		part.Anchored = true
		part.Parent = folder
		return part
	end
	local function dressingOf(part)
		return part:FindFirstChild("SearchedDressing")
	end
	local function checkClean(part)
		local model = dressingOf(part)
		expect(model ~= nil).to.equal(true)
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") then
				expect(child.CanCollide).to.equal(false)
				expect(child.CanQuery).to.equal(false)
				expect(child.CanTouch).to.equal(false)
			end
		end
		return model
	end
	it("pulls a desk drawer with a dark cavity on the sitter face", function()
		local desk = proxy("Desk", OfficeConstants.DESK_SIZE)
		local dressing = Dressing.new(0)
		dressing.apply(desk, "desk")
		local model = checkClean(desk)
		local drawer = model:FindFirstChild("UpperDrawerFront")
		local cavity = model:FindFirstChild("DrawerBottom")
		expect(drawer ~= nil).to.equal(true)
		expect(cavity ~= nil).to.equal(true)
		expect(cavity.Position.Y < drawer.Position.Y).to.equal(true)
		-- The drawer front clears the proxy face; the proxy itself is untouched.
		expect(drawer.Position.Z - drawer.Size.Z / 2 < -OfficeConstants.DESK_SIZE.Z / 2).to.equal(true)
		expect(desk.Transparency).to.equal(1)
		expect(desk.Size).to.equal(OfficeConstants.DESK_SIZE)
	end)
	it("swings a locker door ajar with a dark interior", function()
		local locker = proxy("Locker", OfficeConstants.LOCKER_SIZE)
		local dressing = Dressing.new(0)
		dressing.apply(locker, "locker")
		local model = checkClean(locker)
		local door = model:FindFirstChild("SearchDoor")
		local interior = model:FindFirstChild("LockerShelf")
		expect(door ~= nil).to.equal(true)
		expect(interior ~= nil).to.equal(true)
		expect(interior.CanCollide).to.equal(false)
		-- Fully open along the cabinet side rather than protruding across its approach.
		expect(door.CFrame.LookVector.Z > 0.99).to.equal(true)
		expect(door.Position.Z < -0.5).to.equal(true)
	end)
	it("replaces the previous overlay when applied twice", function()
		local desk = proxy("Desk", OfficeConstants.DESK_SIZE)
		local dressing = Dressing.new(0)
		dressing.apply(desk, "desk")
		dressing.apply(desk, "desk")
		local count = 0
		for _, child in desk:GetChildren() do
			if child.Name == "SearchedDressing" then
				count += 1
			end
		end
		expect(count).to.equal(1)
	end)
	it("moves an authored split drawer and restores it without overlaying the asset", function()
		local desk = proxy("Desk", OfficeConstants.DESK_SIZE)
		local art = Instance.new("Model")
		art.Name = "ArtVisual"
		art.Parent = desk
		local drawer = Instance.new("Part")
		drawer.Name = "SearchDrawer"
		drawer.Size = Vector3.new(1, 0.6, 2)
		drawer.CFrame = desk.CFrame * CFrame.new(1, 1, 0)
		drawer.Anchored = true
		drawer.Parent = art
		local closed = drawer.CFrame
		local dressing = Dressing.new(0)
		dressing.apply(desk, "desk")
		expect(drawer.Position.Z < closed.Position.Z).to.equal(true)
		expect(desk:FindFirstChild("SearchedDressing")).to.equal(nil)
		dressing.clear()
		expect(drawer.CFrame).to.equal(closed)
	end)
	it("clears every overlay", function()
		local desk = proxy("Desk", OfficeConstants.DESK_SIZE)
		local locker = proxy("Locker", OfficeConstants.LOCKER_SIZE)
		local dressing = Dressing.new(0)
		dressing.apply(desk, "desk")
		dressing.apply(locker, "locker")
		dressing.clear()
		expect(dressingOf(desk)).to.equal(nil)
		expect(dressingOf(locker)).to.equal(nil)
	end)
	it("opens toward the clear side when a wall touches its left side", function()
		local locker = proxy("Locker", OfficeConstants.LOCKER_SIZE)
		locker:SetAttribute("OfficeDoorHingeSide", 1)
		local dressing = Dressing.new(0)
		dressing.apply(locker, "locker")
		local door = checkClean(locker):FindFirstChild("SearchDoor")
		local position = locker.CFrame:PointToObjectSpace(door.Position)
		expect(position.X > locker.Size.X / 2).to.equal(true)
		expect(door.CFrame.LookVector.Z > 0.99).to.equal(true)
	end)
end
