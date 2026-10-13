local Server = game:GetService("ServerScriptService").Features.Office
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(script.Parent.OfficeBuildSystem)
local Layout = require(Server.Data.OfficeLayoutConstants).LAYOUT
local Constants = require(Server.Data.OfficeConstants)
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
	describe("overtime sheet", function()
		it("stands beside the time clock, its Start overtime prompt off until Shift opens it", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0))
			local sheet = built.overtime
			expect(sheet.Parent).to.equal(built.clock.Parent)
			expect(sheet:GetAttribute(Interaction.KIND_ATTRIBUTE)).to.equal(Shift.OVERTIME_KIND)
			expect(sheet:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(false)
			expect(CollectionService:HasTag(sheet, Interaction.TAG)).to.equal(true)
			local offset = Constants.OVERTIME_OFFSET
			expect((sheet.Position - built.clock.Position).X).to.be.near(offset.X, 0.001)
			expect((sheet.Position - built.clock.Position).Z).to.be.near(offset.Z, 0.001)
			expect(sheet.Position.Y).to.be.near(Constants.OVERTIME_SIZE.Y / 2, 0.001)
		end)
	end)
end
