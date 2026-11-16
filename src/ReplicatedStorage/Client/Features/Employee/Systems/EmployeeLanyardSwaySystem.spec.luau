local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeLanyardSwaySystem = require(script.Parent.EmployeeLanyardSwaySystem)
local EmployeeLanyardFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeLanyardFormulas)

return function()
	local function handle(weld)
		return {
			folder = Instance.new("Folder"),
			badgeWeld = weld,
			badgeTurn = CFrame.identity,
			scale = 1,
			destroy = function() end,
		}
	end

	describe("sway", function()
		it("returns a stop that does nothing for a character without a Humanoid or a badge weld", function()
			local fit = EmployeeLanyardFormulas.fit("Pippa")
			local character = Instance.new("Model")
			local stop = EmployeeLanyardSwaySystem.sway(character, fit, 1, handle(nil))
			expect(type(stop)).to.equal("function")
			stop()
			character:Destroy()
		end)

		it("leaves the badge weld at rest until the body moves, and stops cleanly", function()
			local fit = EmployeeLanyardFormulas.fit("Pippa")
			local character = Instance.new("Model")
			Instance.new("Humanoid").Parent = character
			local ut = Instance.new("Part")
			ut.Name = "UpperTorso"
			ut.Size = Vector3.new(fit.ut_size[1], fit.ut_size[2], fit.ut_size[3])
			ut.Parent = character
			local weld = Instance.new("Weld")
			local rest = CFrame.new(1, 2, 3)
			weld.C0 = rest
			local stop = EmployeeLanyardSwaySystem.sway(character, fit, 1, handle(weld))
			expect(weld.C0).to.equal(rest)
			stop()
			character:Destroy()
		end)
	end)
end
