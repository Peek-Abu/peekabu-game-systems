--!strict
--[=[
	Unit tests for SyncState — the shared charm-sync key/name/slice contract.
	Key stability is load-bearing: the server and client build these independently and must line up.
]=]

local SyncState = require(script.Parent.SyncState)

return function()
	describe("key", function()
		it("is stable and player-scoped", function()
			expect(SyncState.key("currency", 123)).to.equal("currency:123")
			expect(SyncState.key("inventory", 456)).to.equal("inventory:456")
		end)

		it("never collides across slices for the same user", function()
			expect(SyncState.key("currency", 1)).never.to.equal(SyncState.key("inventory", 1))
		end)

		it("differs per user for the same slice", function()
			expect(SyncState.key("currency", 1)).never.to.equal(SyncState.key("currency", 2))
		end)
	end)

	describe("SLICES", function()
		it("lists the replicated slices", function()
			expect(table.find(SyncState.SLICES, "currency")).to.be.ok()
			expect(table.find(SyncState.SLICES, "inventory")).to.be.ok()
		end)
	end)

	describe("REMOTE_NAME", function()
		it("is the shared transport name", function()
			expect(SyncState.REMOTE_NAME).to.equal("CharmSyncRemote")
		end)
	end)
end
