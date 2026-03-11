--!strict
--[=[
	Unit tests for SliceManifest — the one declaration site for replicated slices.
	NAMES must stay a faithful, deterministic derivation of DEFINITIONS: every downstream registry
	(SyncState.SLICES, ServerStore, ClientStore's boot assert) trusts it.
]=]

local SliceManifest = require(script.Parent.SliceManifest)

return function()
	describe("NAMES", function()
		it("contains exactly the DEFINITIONS keys, sorted", function()
			local expected: { string } = {}
			for name in SliceManifest.DEFINITIONS do
				table.insert(expected, name)
			end
			table.sort(expected)

			expect(#SliceManifest.NAMES).to.equal(#expected)
			for i, name in expected do
				expect(SliceManifest.NAMES[i]).to.equal(name)
			end
		end)
	end)

	describe("DEFINITIONS", function()
		it("each entry's read() extracts its own slice off a profile", function()
			local fakeProfile = {
				currency = { gold = 5 },
				inventory = { { itemType = "iron-sword", quantity = 1 } },
			} :: any

			for name, definition in SliceManifest.DEFINITIONS do
				local value = definition.read(fakeProfile)
				-- Every current slice reads its same-named profile field; a definition whose reader
				-- points at the wrong field would silently replicate the wrong data.
				expect(value).to.equal(fakeProfile[name])
			end
		end)
	end)
end
