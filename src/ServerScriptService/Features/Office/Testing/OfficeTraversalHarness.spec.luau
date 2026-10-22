-- Harlow, with every door shut, can path from the loading bay to every patrol point and room of five generated
-- layouts. Builds each office far from the live one (5000, 1, 5000) and destroys it again; it yields in ComputeAsync
-- (about 5 seeds x 70 paths plus a settle wait per seed: tens of seconds).
local ServerScriptService = game:GetService("ServerScriptService")
local Harness = require(ServerScriptService.Features.Office.Testing.OfficeTraversalHarness)
return function()
	it("Harlow can path to every room and patrol point with every door closed", function()
		local result = Harness.run({ 1, 2, 3, 4, 5 }, CFrame.new(5000, 1, 5000))
		expect(table.concat(result.failures, "; ")).to.equal("")
		expect(#result.failures).to.equal(0)
		expect(result.paths > 100).to.equal(true)
	end)
end
