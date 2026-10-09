--[=[
	Unit tests for TitleTypes — the shared type vocabulary of the titles registry. The module is
	entirely types (erased at runtime), so the observable surface is just that it requires cleanly
	and exports an empty table as its payload.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleTypes = require(ReplicatedStorage.Shared.Features.Title.Data.TitleTypes)

return function()
	describe("TitleTypes", function()
		it("requires cleanly and exposes a table payload", function()
			expect(type(TitleTypes)).to.equal("table")
		end)

		it("carries no runtime members — the vocabulary is types only", function()
			local count = 0
			for _ in TitleTypes do
				count += 1
			end
			expect(count).to.equal(0)
		end)
	end)
end
