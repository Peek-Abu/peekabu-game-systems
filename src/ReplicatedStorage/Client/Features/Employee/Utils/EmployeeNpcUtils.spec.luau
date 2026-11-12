local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeNpcUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeNpcUtils)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

return function()
	local function hasArt(name)
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local crew = assets and assets:FindFirstChild("CleanupCrew")
		local characters = crew and crew:FindFirstChild("Characters")
		return characters ~= nil and characters:FindFirstChild(name) ~= nil
	end

	describe("clone", function()
		it("is the employee at the size players spawn at (owner 11-11: hub NPCs looked small)", function()
			if not hasArt("Pippa") then
				return
			end
			local model = EmployeeNpcUtils.clone("Pippa")
			expect(model).never.to.equal(nil)
			local source = ReplicatedStorage.Assets.CleanupCrew.Characters.Pippa
			local def = EmployeeRegistry.get("Pippa")
			expect(model:GetScale()).to.be.near(source:GetScale() * def.scale, 1e-4)
			expect(model.Parent).to.equal(nil)
			model:Destroy()
		end)

		it("is nothing for an employee without art", function()
			expect(EmployeeNpcUtils.clone("NoSuchEmployee")).to.equal(nil)
		end)
	end)
end
