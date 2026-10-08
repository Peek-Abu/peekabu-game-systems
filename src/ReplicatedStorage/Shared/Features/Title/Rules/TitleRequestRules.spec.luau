--[[
	Unit tests for TitleRequestRules — the pure build/parse contract for the equip packet. The client
	builds, the server parses at the trust boundary; both halves are asserted against each other so
	the contract cannot drift. Parsing validates SHAPE only: whether the title is registered and
	earned is the server service's job (assert + policy gate), not the boundary's.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleRequestRules = require(ReplicatedStorage.Shared.Features.Title.Rules.TitleRequestRules)

return function()
	describe("equip round-trip", function()
		it("parses what build produces", function()
			local payload = TitleRequestRules.buildEquip("veteran")
			local titleId, reason = TitleRequestRules.parseEquip(payload)
			expect(reason).to.equal(nil)
			expect(titleId).to.equal("veteran")
		end)

		it("rejects a non-table payload", function()
			expect(select(2, TitleRequestRules.parseEquip("veteran"))).to.be.ok()
			expect(select(2, TitleRequestRules.parseEquip(nil))).to.be.ok()
		end)

		it("rejects a missing, non-string, or empty titleId", function()
			expect(select(2, TitleRequestRules.parseEquip({}))).to.be.ok()
			expect(select(2, TitleRequestRules.parseEquip({ titleId = 42 }))).to.be.ok()
			expect(select(2, TitleRequestRules.parseEquip({ titleId = "" }))).to.be.ok()
		end)

		it("ignores extra fields rather than rejecting the packet", function()
			local titleId = TitleRequestRules.parseEquip({ titleId = "champion", cheatField = true })
			expect(titleId).to.equal("champion")
		end)
	end)
end
