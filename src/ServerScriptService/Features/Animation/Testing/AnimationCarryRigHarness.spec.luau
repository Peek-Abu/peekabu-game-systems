local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local RigHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
return function()
	afterAll(function()
		local folder = Workspace:FindFirstChild("CarryHarness")
		if folder ~= nil then
			folder:Destroy()
		end
	end)

	it("builds a stock R15 standing where asked, root anchored, joined by the avatar's joints", function()
		local rig = RigHarness.stockR15(Vector3.new(0, 3000, 900))
		expect(rig.HumanoidRootPart.Anchored).to.equal(true)
		expect(rig.HumanoidRootPart.Position:FuzzyEq(Vector3.new(0, 3000, 900), 1e-3)).to.equal(true)
		expect(rig.Humanoid.RigType).to.equal(Enum.HumanoidRigType.R15)
		local joined = rig.RightLowerArm:FindFirstChildOfClass("AnimationConstraint")
			or rig.RightLowerArm:FindFirstChildOfClass("Motor6D")
		expect(joined).to.be.ok()
		expect(RigHarness.animator(rig)).to.be.ok()
		rig:Destroy()
	end)

	it("builds the employee from its art template, or nothing in a place without the art", function()
		local employee = RigHarness.employee(Vector3.new(20, 3000, 900))
		if employee ~= nil then
			expect(employee:FindFirstChild("RightHand")).to.be.ok()
			expect(employee.HumanoidRootPart.Anchored).to.equal(true)
			employee:Destroy()
		end
	end)

	it("offers the carriers asked for, each with its own idle and walk", function()
		local carriers = RigHarness.carriers({ "StockR15" })
		expect(#carriers).to.equal(1)
		expect(carriers[1].name).to.equal("StockR15")
		expect(carriers[1].idle).to.be.ok()
		expect(carriers[1].walk).to.be.ok()
		carriers[1].model:Destroy()
	end)
end
