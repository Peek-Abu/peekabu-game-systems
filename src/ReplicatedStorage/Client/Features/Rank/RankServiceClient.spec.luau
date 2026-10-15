-- RankServiceClient is a thin read facade over the public entries; the reading is the specced RankViewModel. The
-- spec checks its surface (no lifecycle: it draws no overhead tag) and that an unknown player reads as nil.
local RankServiceClient = require(script.Parent.RankServiceClient)

return function()
	describe("RankServiceClient", function()
		it("depends on the state sync and draws nothing of its own", function()
			expect(table.find(RankServiceClient.dependencies, "StateSyncServiceClient")).to.be.ok()
			expect(RankServiceClient.start).to.equal(nil)
		end)

		it("reads nil for a player with no published rank", function()
			expect(RankServiceClient:rankOf(-1)).to.equal(nil)
		end)
	end)
end
