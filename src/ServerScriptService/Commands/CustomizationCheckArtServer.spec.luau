--!strict
--[=[
	Unit tests for the CheckArt Cmdr command implementation.
	Mock strategy: patch CustomizationArtCheckSystem.check inside beforeAll/afterAll (see AddCurrencyServer.spec
	for the rationale). What is worth covering is the console FORMATTING — a full report is unreadable
	in the Cmdr window, so the command truncates and points at the log.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationArtCheckSystem =
	require(ServerScriptService.Features.Customization.Systems.CustomizationArtCheckSystem)
local checkArtCommand = require(ServerScriptService.Commands.CustomizationCheckArtServer)

return function()
	describe("CustomizationCheckArtServer", function()
		local _origCheck
		local nextSummary

		beforeAll(function()
			_origCheck = CustomizationArtCheckSystem.check
			CustomizationArtCheckSystem.check = function()
				return nextSummary
			end
		end)

		afterAll(function()
			CustomizationArtCheckSystem.check = _origCheck
		end)

		local function summaryWith(count: number)
			local lines: { string } = {}
			for i = 1, count do
				table.insert(lines, `[hair] Hair{i}: no art named "Hair{i}" in "Hair"`)
			end
			return { ok = count == 0, total = count, lines = lines }
		end

		it("reports success when everything resolves", function()
			nextSummary = summaryWith(0)
			expect(checkArtCommand(nil):find("every catalogued cosmetic resolves", 1, true)).to.be.ok()
		end)

		it("lists issues when there are few enough to read", function()
			nextSummary = summaryWith(3)
			local message = checkArtCommand(nil)
			expect(message:find("3 issue", 1, true)).to.be.ok()
			expect(message:find("Hair3", 1, true)).to.be.ok()
			expect(message:find("more —", 1, true)).to.equal(nil)
		end)

		it("truncates a long report and points at the server log", function()
			nextSummary = summaryWith(50)
			local message = checkArtCommand(nil)
			expect(message:find("50 issue", 1, true)).to.be.ok()
			expect(message:find("more — see the server log", 1, true)).to.be.ok()
			-- The count line, the shown lines, and the "and N more" line.
			local newlines = select(2, message:gsub("\n", ""))
			expect(newlines).to.equal(9)
		end)
	end)
end
