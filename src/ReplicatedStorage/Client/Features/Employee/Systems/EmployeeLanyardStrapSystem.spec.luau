local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeLanyardStrapSystem = require(script.Parent.EmployeeLanyardStrapSystem)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeLanyardConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeLanyardConstants)
local EmployeeLanyardFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeLanyardFormulas)

return function()
	describe("fallbackRibbonParts", function()
		it("builds the strap from quiet Parts welded to the UpperTorso, one per straight run at most", function()
			local fit = EmployeeLanyardFormulas.fit("Pippa")
			local ut = Instance.new("Part")
			ut.Name = "UpperTorso"
			ut.Size = Vector3.new(fit.ut_size[1], fit.ut_size[2], fit.ut_size[3])
			local folder = Instance.new("Folder")
			local tolerance = EmployeeLanyardConstants.PART_RIBBON_TOLERANCE
			EmployeeLanyardStrapSystem.fallbackRibbonParts(fit, 1, 1, ut, folder, tolerance)
			local runs = EmployeeLanyardFormulas.ribbonRuns(fit, EmployeeLanyardFormulas.width(fit, 1), tolerance)
			local parts = folder:GetChildren()
			expect(#parts > 0).to.equal(true)
			expect(#parts <= #runs).to.equal(true)
			for _, seg in parts do
				expect(seg:IsA("Part")).to.equal(true)
				expect(seg.Name).to.equal(EmployeeConstants.LANYARD_STRAP)
				expect(seg.CanCollide).to.equal(false)
				expect(seg.Anchored).to.equal(false)
				local weld = seg:FindFirstChildOfClass("WeldConstraint")
				expect(weld).to.be.ok()
				expect(weld.Part0).to.equal(ut)
				expect(weld.Part1).to.equal(seg)
			end
			folder:Destroy()
			ut:Destroy()
		end)
	end)
end
