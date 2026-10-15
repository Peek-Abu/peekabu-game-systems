local Server = game:GetService("ServerScriptService").Features.Office
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(script.Parent.OfficeBuildSystem)
local Layout = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Interaction = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local Shift = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
return function()
	local built
	afterEach(function()
		if built then
			built.model:Destroy()
			built = nil
		end
	end)
	describe("physical enclosure", function()
		it("builds collidable visible ceiling geometry", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0))
			local ceiling = built.model:FindFirstChild("Ceiling", true)
			expect(ceiling ~= nil).to.equal(true)
			expect(ceiling.CanCollide).to.equal(true)
			expect(ceiling.Transparency).to.equal(0)
		end)
	end)
	describe("truck paperwork", function()
		local Truck = require(game:GetService("ServerScriptService").Features.Depot.Data.DepotTruckVisualConstants)

		local function deckPoint(bed, point)
			return (bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)):PointToObjectSpace(point)
		end

		it("hangs the time clock's invisible hit box inside the truck box, on its front wall", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0))
			local clock = built.clock
			expect(clock:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Shift.CLOCK_OUT_KIND)
			expect(CollectionService:HasTag(clock, Interaction.TAG)).to.equal(true)
			expect(clock.Transparency).to.equal(1)
			expect(clock.CanCollide).to.equal(false)
			expect(clock.CanQuery).to.equal(true)
			expect((deckPoint(built.bed, clock.Position) - Truck.PAPERWORK.clock.centre).Magnitude < 1e-3).to.equal(
				true
			)
		end)

		it("hangs the overtime sheet beside it, its Start overtime prompt off until Shift opens it", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0))
			local sheet = built.overtime
			expect(sheet.Parent).to.equal(built.clock.Parent)
			expect(sheet:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Shift.OVERTIME_KIND)
			expect(sheet:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(false)
			expect(CollectionService:HasTag(sheet, Interaction.TAG)).to.equal(true)
			expect(sheet.CanCollide).to.equal(false)
			expect((deckPoint(built.bed, sheet.Position) - Truck.PAPERWORK.sheet.centre).Magnitude < 1e-3).to.equal(
				true
			)
		end)
	end)
end
