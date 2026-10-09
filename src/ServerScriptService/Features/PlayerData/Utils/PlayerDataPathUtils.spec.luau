local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataPathUtils = require(ServerScriptService.Features.PlayerData.Utils.PlayerDataPathUtils)

return function()
	describe("PlayerDataPathUtils", function()
		describe("forSlot / forAccount", function()
			it("builds a slot path", function()
				expect(PlayerDataPathUtils.forSlot("currency", 2)).to.equal("slots.2.currency")
			end)

			it("builds an account path", function()
				expect(PlayerDataPathUtils.forAccount("settings")).to.equal("account.settings")
			end)

			it("throws on a non-integer slotIndex", function()
				expect(function()
					PlayerDataPathUtils.forSlot("currency", 2.5)
				end).to.throw()
			end)

			it("throws on a zero or negative slotIndex", function()
				expect(function()
					PlayerDataPathUtils.forSlot("currency", 0)
				end).to.throw()
				expect(function()
					PlayerDataPathUtils.forSlot("currency", -1)
				end).to.throw()
			end)
		end)

		describe("pattern", function()
			it("normalises the slot index to a wildcard", function()
				expect(PlayerDataPathUtils.pattern("slots.2.currency")).to.equal("slots.*.currency")
			end)

			it("leaves an account path unchanged", function()
				expect(PlayerDataPathUtils.pattern("account.settings")).to.equal("account.settings")
			end)

			it("is what slotPattern produces, so registration and lookup agree", function()
				expect(PlayerDataPathUtils.pattern(PlayerDataPathUtils.forSlot("currency", 3))).to.equal(
					PlayerDataPathUtils.slotPattern("currency")
				)
			end)

			it("holds the invariant for a numerically-named slice (positional, not value-sniffed)", function()
				expect(PlayerDataPathUtils.pattern(PlayerDataPathUtils.forSlot("123", 2))).to.equal(
					PlayerDataPathUtils.slotPattern("123")
				)
			end)

			it("only wildcards the slot-index position, not other numeric-looking segments", function()
				expect(PlayerDataPathUtils.pattern("slots.2.123")).to.equal("slots.*.123")
			end)
		end)

		describe("sliceName", function()
			it("returns the last segment for a slot path", function()
				expect(PlayerDataPathUtils.sliceName("slots.2.currency")).to.equal("currency")
			end)

			it("returns the last segment for an account path", function()
				expect(PlayerDataPathUtils.sliceName("account.settings")).to.equal("settings")
			end)

			it("returns a bare root key unchanged", function()
				expect(PlayerDataPathUtils.sliceName("slotState")).to.equal("slotState")
			end)

			it("throws on an empty path instead of returning nil", function()
				expect(function()
					PlayerDataPathUtils.sliceName("")
				end).to.throw()
			end)
		end)

		describe("slotIndex", function()
			it("extracts the slot index", function()
				expect(PlayerDataPathUtils.slotIndex("slots.2.currency")).to.equal(2)
			end)

			it("is nil for an account path", function()
				expect(PlayerDataPathUtils.slotIndex("account.settings")).to.never.be.ok()
			end)

			it("is nil for a bare root key", function()
				expect(PlayerDataPathUtils.slotIndex("slotState")).to.never.be.ok()
			end)
		end)
	end)
end
