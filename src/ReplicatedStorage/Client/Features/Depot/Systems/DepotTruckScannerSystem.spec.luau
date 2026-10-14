local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Scanner = require(script.Parent.DepotTruckScannerSystem)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local IDLE = Color3.fromRGB(64, 170, 110)

local function light(position)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(12, 1, 1)
	part.CFrame = CFrame.new(position)
	part.Color = IDLE
	part:SetAttribute(DepotConstants.SCANNER_IDLE_ATTRIBUTE, IDLE)
	part:SetAttribute(DepotConstants.SCANNER_WIDTH_ATTRIBUTE, 11.8)
	for name, offset in
		{
			[DepotConstants.SCANNER_SWEEP_TOP] = Vector3.new(0, 1.5, 0),
			[DepotConstants.SCANNER_SWEEP_BOTTOM] = Vector3.new(0, -4, 0),
		}
	do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = offset
		attachment.Parent = part
	end
	local glow = Instance.new("PointLight")
	glow.Name = "ScanGlow"
	glow.Brightness = 0
	glow.Parent = part
	return part
end

return function()
	describe("nearest", function()
		it("picks the scanner closest to the banked point", function()
			local a = light(Vector3.new(0, 5, 0))
			local b = light(Vector3.new(30, 5, 0))
			expect(Scanner.nearest({ a, b }, Vector3.new(26, 2, 4), 40)).to.equal(b)
			expect(Scanner.nearest({ a, b }, Vector3.new(2, 2, 4), 40)).to.equal(a)
			a:Destroy()
			b:Destroy()
		end)

		it("ignores scanners farther than the range, and an empty list", function()
			local a = light(Vector3.new(0, 5, 0))
			expect(Scanner.nearest({ a }, Vector3.new(100, 0, 0), 25)).to.equal(nil)
			expect(Scanner.nearest({}, Vector3.zero, 25)).to.equal(nil)
			a:Destroy()
		end)
	end)

	describe("flash", function()
		local folder
		beforeEach(function()
			folder = Instance.new("Folder")
			folder.Parent = Workspace
		end)
		afterEach(function()
			folder:Destroy()
		end)

		it("lights the arch and its glow, and runs a sweep down the doorway", function()
			local part = light(Vector3.new(0, 5, 0))
			part.Parent = folder
			local sweep = Scanner.flash(part, folder)
			expect(part.Color).to.equal(Scanner.LIT)
			expect(part:FindFirstChild("ScanGlow").Brightness > 0).to.equal(true)
			expect(sweep).to.be.ok()
			expect(sweep.Parent).to.equal(folder)
			expect(sweep.Size.X).to.be.near(11.8, 1e-3)
			expect(sweep.Position.Y).to.be.near(6.5, 1e-3)
			expect(sweep.CanCollide or sweep.CanQuery or sweep.CanTouch).to.equal(false)
		end)

		it("restarts cleanly when a second bank lands mid-flash", function()
			local part = light(Vector3.new(0, 5, 0))
			part.Parent = folder
			local first = Scanner.flash(part, folder)
			local second = Scanner.flash(part, folder)
			expect(first.Parent).to.equal(nil)
			expect(second.Parent).to.equal(folder)
			expect(part.Color).to.equal(Scanner.LIT)
		end)

		it("does nothing without the sweep path", function()
			local part = Instance.new("Part")
			expect(Scanner.flash(part, folder)).to.equal(nil)
			part:Destroy()
		end)
	end)

	describe("tagged", function()
		it("lists only tagged parts in the Workspace", function()
			local folder = Instance.new("Folder")
			folder.Parent = Workspace
			local part = light(Vector3.new(0, 5, 0))
			part.Parent = folder
			CollectionService:AddTag(part, DepotConstants.SCANNER_TAG)
			local stray = light(Vector3.new(0, 5, 0))
			CollectionService:AddTag(stray, DepotConstants.SCANNER_TAG)
			local found = Scanner.tagged()
			expect(table.find(found, part)).to.be.ok()
			expect(table.find(found, stray)).to.equal(nil)
			folder:Destroy()
			stray:Destroy()
		end)
	end)
end
