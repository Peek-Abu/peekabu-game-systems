-- RankServiceClient is a thin read facade over the public entries plus RankTagSystem's lifecycle; the reading is the
-- specced RankViewModel. The spec checks its surface and that an unknown player reads as nil.
local RankServiceClient = require(script.Parent.RankServiceClient)

return function()
	describe("RankServiceClient", function()
		it("depends on the state sync and exposes its lifecycle", function()
			expect(table.find(RankServiceClient.dependencies, "StateSyncServiceClient")).to.be.ok()
			expect(type(RankServiceClient.start)).to.equal("function")
			expect(type(RankServiceClient.stop)).to.equal("function")
		end)

		it("reads nil for a player with no published rank", function()
			expect(RankServiceClient:rankOf(-1)).to.equal(nil)
		end)
	end)
end
