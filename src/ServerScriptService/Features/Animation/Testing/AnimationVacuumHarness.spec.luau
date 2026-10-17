-- The vacuum hold validator: the hand wand held by Pippa (every player spawns as an employee) in every vacuum skin,
-- planned while she is falling (as a shift's start places the crew in the truck), then judged live at idle, walking,
-- sprinting and vacuuming, under every motion layer at its extremes (aim, brace). Prints the full report to the output. Needs the place's art for Pippa and the skins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Harness = require(ServerScriptService.Features.Animation.Testing.AnimationVacuumHarness)
local VacuumSkinRegistry = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumSkinRegistry)
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

	it("holds the wand in every skin on the employee, when the place has her art", function()
		local seen = {}
		for _, entry in result.entries do
			seen[`{entry.rig}/{entry.skin}`] = true
		end
		if not Harness.hasEmployee() then
			expect(#result.entries).to.equal(0)
			return
		end
		for name in VacuumSkinRegistry.SKINS do
			expect(seen[`Pippa/{name}`]).to.equal(true)
		end
	end)

	it("samples idle, walk, sprint and vacuuming frames", function()
		for _, entry in result.entries do
			local names = {}
			for _, frame in entry.frames do
				names[frame.state] = true
			end
			expect(names.idle).to.equal(true)
			expect(names.walk).to.equal(true)
			expect(names.sprint).to.equal(true)
			expect(names.vacuum).to.equal(true)
		end
	end)

	it("lays every motion layer on every frame: rest, both aim extremes and the brace", function()
		for _, entry in result.entries do
			local seen = {}
			for _, frame in entry.frames do
				seen[`{frame.name}/{frame.layer}`] = true
			end
			for _, frame in entry.frames do
				for _, layer in { "rest", "aim up", "aim down", "brace", "brace+down", "brace+up" } do
					expect(seen[`{frame.name}/{layer}`]).to.equal(true)
				end
			end
		end
	end)

	it(
		"keeps both paws closed on the wand's grips and the floor head over the floor in every frame and layer",
		function()
			local failures = {}
			for _, entry in result.entries do
				if not entry.ok then
					table.insert(failures, `{entry.rig} {entry.skin}: {table.concat(entry.problems, "; ")}`)
				end
			end
			expect(table.concat(failures, "\n")).to.equal("")
		end
	)

	it("prints a report naming every carrier and skin", function()
		local text = Harness.format(result)
		for _, entry in result.entries do
			expect(text:find(`{entry.rig} {entry.skin}`, 1, true) ~= nil).to.equal(true)
		end
	end)
end
