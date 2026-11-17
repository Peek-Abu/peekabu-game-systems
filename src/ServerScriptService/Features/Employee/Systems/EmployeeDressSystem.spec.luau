local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local EmployeeDressSystem = require(script.Parent.EmployeeDressSystem)

-- A user id no test account or live player has, so nothing is loaded for it.
local NOBODY = -987654

return function()
	describe("EmployeeDressSystem", function()
		it("starts a tally at zero with no one dressed", function()
			local tally = EmployeeDressSystem.newTally()
			expect(tally.skinned).to.equal(0)
			expect(tally.uniformed).to.equal(0)
			expect(next(tally.skinOf)).to.equal(nil)
			expect(next(tally.worn)).to.equal(nil)
		end)

		it("gives a player whose rank has not loaded the first rank level", function()
			expect(EmployeeDressSystem.rankLevelOf(NOBODY).level).to.equal(RankFormulas.progress(0).level.level)
		end)

		it("has no skin key before the loadout loads", function()
			expect(EmployeeDressSystem.skinKeyOf(NOBODY, "Pippa")).to.equal(nil)
		end)

		it("leaves the vacuum and idle marks alone before the loadout loads", function()
			local character = Instance.new("Model")
			EmployeeDressSystem.markVacuum(NOBODY, character)
			EmployeeDressSystem.markIdle(NOBODY, character, "Pippa")
			expect(character:GetAttribute(VacuumConstants.SKIN_ATTRIBUTE)).to.equal(nil)
			expect(character:GetAttribute(EmployeeConstants.IDLE_ATTRIBUTE)).to.equal(nil)
			character:Destroy()
		end)

		it("does not dress a character that is not an employee", function()
			local tally = EmployeeDressSystem.newTally()
			local character = Instance.new("Model")
			local player = { UserId = NOBODY, DisplayName = "Nobody" }
			EmployeeDressSystem.dress(tally, player, character)
			expect(tally.skinned).to.equal(0)
			expect(tally.uniformed).to.equal(0)
			expect(tally.worn[NOBODY]).to.equal(nil)
			expect(character:GetAttribute(EmployeeConstants.SKIN_ATTRIBUTE)).to.equal(nil)
			character:Destroy()
		end)

		it("keeps one spawn watch per player", function()
			local player = {}
			local existing = Instance.new("BindableEvent").Event:Connect(function() end)
			local watches = { [player] = existing }
			EmployeeDressSystem.watch(EmployeeDressSystem.newTally(), watches, player)
			expect(watches[player]).to.equal(existing)
			existing:Disconnect()
		end)
	end)
end
