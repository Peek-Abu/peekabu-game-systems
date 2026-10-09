--!strict
--[=[
	Unit tests for StateSyncConstants — the shared charm-sync key/name/slice contract.
	Key stability is load-bearing: the server and client build these independently and must line up.
]=]

local StateSyncConstants = require(script.Parent.StateSyncConstants)

return function()
	describe("key", function()
		it("is stable and player-scoped", function()
			expect(StateSyncConstants.key("currency", 123)).to.equal("currency:123")
			expect(StateSyncConstants.key("inventory", 456)).to.equal("inventory:456")
		end)

		it("never collides across slices for the same user", function()
			expect(StateSyncConstants.key("currency", 1)).never.to.equal(StateSyncConstants.key("inventory", 1))
		end)

		it("differs per user for the same slice", function()
			expect(StateSyncConstants.key("currency", 1)).never.to.equal(StateSyncConstants.key("currency", 2))
		end)
	end)

	describe("SLICES", function()
		it("lists the replicated slices", function()
			expect(table.find(StateSyncConstants.SLICES, "currency")).to.be.ok()
			expect(table.find(StateSyncConstants.SLICES, "inventory")).to.be.ok()
		end)
	end)

	describe("REMOTE_NAME", function()
		it("is the shared transport name", function()
			expect(StateSyncConstants.REMOTE_NAME).to.equal("CharmSyncRemote")
		end)
	end)

	describe("public slice keys", function()
		it("builds the per-viewer charm-sync key from the public slice name", function()
			expect(StateSyncConstants.PUBLIC_SLICE).to.equal("publicPlayers")
			expect(StateSyncConstants.publicKey(123)).to.equal("publicPlayers:123")
		end)

		it("never collides with a profile slice", function()
			expect(table.find(StateSyncConstants.SLICES, StateSyncConstants.PUBLIC_SLICE)).to.equal(nil)
		end)

		it("keys map entries by the userId as a string", function()
			expect(StateSyncConstants.publicEntryKey(456)).to.equal("456")
		end)
	end)

	describe("world slice keys", function()
		it("builds the per-viewer charm-sync key from the world slice name", function()
			expect(StateSyncConstants.WORLD_SLICE).to.equal("world")
			expect(StateSyncConstants.worldKey(123)).to.equal("world:123")
		end)

		it("never collides with a profile slice or the public slice", function()
			expect(table.find(StateSyncConstants.SLICES, StateSyncConstants.WORLD_SLICE)).to.equal(nil)
			expect(StateSyncConstants.WORLD_SLICE).never.to.equal(StateSyncConstants.PUBLIC_SLICE)
		end)
	end)
end
