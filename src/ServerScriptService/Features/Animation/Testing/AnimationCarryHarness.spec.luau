-- The carry validator: every carry template held by Pippa and by a stock R15, planned and live (idle and two walk
-- frames), judged by AnimationCarryPoseRules. Prints the full report to the output. Needs the place's art
-- (ReplicatedStorage.Assets): without it only the harness itself is checked.
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Harness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryHarness)
local System = require(ServerScriptService.Features.Animation.Systems.AnimationCarrySystem)
local RigHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
return function()
	local result
	beforeAll(function()
		result = Harness.run({})
		print(Harness.format(result))
	end)
	afterAll(function()
		local folder = Workspace:FindFirstChild("CarryHarness")
		if folder ~= nil then
			folder:Destroy()
		end
	end)

	it("builds a stock R15 whose arms the carry can measure and drive", function()
		local rig = RigHarness.stockR15(Vector3.new(0, 3000, -600))
		local measured = System.measure(rig)
		expect(measured).to.be.ok()
		expect(measured.right.shoulder.X > 0.9).to.equal(true)
		rig:Destroy()
	end)

	it("validates every carry template in the place on Pippa and a stock R15", function()
		if #Harness.kinds() == 0 then
			expect(#result.skipped > 0).to.equal(true)
			return
		end
		local rigs = {}
		for _, entry in result.entries do
			rigs[entry.rig] = true
		end
		expect(rigs.StockR15).to.equal(true)
		expect(rigs.Pippa).to.equal(true)
		expect(#result.entries).to.equal(#Harness.kinds() * 2)
	end)

	it("gives every visible template mesh precise collision (its surface is where the palms go)", function()
		local failures = {}
		for _, entry in result.entries do
			for _, problem in entry.contract do
				table.insert(failures, `{entry.rig} {entry.kind}: {problem}`)
			end
		end
		expect(table.concat(failures, "\n")).to.equal("")
	end)

	it("holds every template inside the carry rules, planned and live, idle and walking", function()
		local failures = {}
		for _, entry in result.entries do
			if not entry.ok then
				local reasons = table.clone(entry.contract)
				if entry.planned ~= nil then
					for _, violation in entry.planned.violations do
						table.insert(reasons, `plan {violation}`)
					end
				end
				for frame, report in entry.live do
					for _, violation in report.violations do
						table.insert(reasons, `{frame} {violation}`)
					end
				end
				table.insert(failures, `{entry.rig} {entry.kind} ({entry.style or "-"}): {table.concat(reasons, "; ")}`)
			end
		end
		expect(table.concat(failures, "\n")).to.equal("")
	end)

	it("prints a report naming every hold", function()
		local text = Harness.format(result)
		for _, entry in result.entries do
			expect(text:find(entry.kind, 1, true) ~= nil).to.equal(true)
		end
	end)
end
