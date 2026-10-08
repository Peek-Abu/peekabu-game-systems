--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatusDisplay = require(ReplicatedStorage.Client.UI.React.StatusDisplay)

return function()
	describe("label", function()
		it("names the status when there is one", function()
			expect(StatusDisplay.label("rotbound")).to.equal("ITEM IS ROTBOUND")
		end)

		it("falls back to bind-on-equip, which is what an ordinary item shows", function()
			-- The old game has no bind-on-equip flag: it is simply the absence of rotbound.
			expect(StatusDisplay.label(nil)).to.equal("ITEM IS BIND ON EQUIP")
		end)
	end)

	describe("style", function()
		it("has no style for an ordinary item, so the card renders untouched", function()
			expect(StatusDisplay.style(nil)).never.to.be.ok()
		end)

		it("marks rotbound as hiding the item's detail", function()
			expect(StatusDisplay.style("rotbound").obscuresDetail).to.equal(true)
		end)
	end)

	describe("obscure", function()
		local SAMPLE = "A blade forged in blood"

		it("is deterministic, so the text cannot shimmer between renders", function()
			expect(StatusDisplay.obscure(SAMPLE)).to.equal(StatusDisplay.obscure(SAMPLE))
		end)

		it("leaves nothing of the original readable", function()
			local obscured = StatusDisplay.obscure(SAMPLE)
			-- Every letter of a distinctive word is gone.
			expect(string.find(obscured, "blade", 1, true)).never.to.be.ok()
			expect(string.find(obscured, "blood", 1, true)).never.to.be.ok()
		end)

		it("keeps spaces where they were, so the layout stays honest", function()
			local obscured = StatusDisplay.obscure("ab cd ef")
			local _, spaces = string.gsub(obscured, " ", "")
			expect(spaces).to.equal(2)
		end)

		it("keeps newlines, so a wrapped label does not collapse to one line", function()
			local _, newlines = string.gsub(StatusDisplay.obscure("a\nb\nc"), "\n", "")
			expect(newlines).to.equal(2)
		end)

		it("produces one visible glyph per source character", function()
			-- The glyph is a hyphen carrying combining marks, so count the hyphens rather than bytes.
			local _, glyphs = string.gsub(StatusDisplay.obscure("abcd"), "%-", "")
			expect(glyphs).to.equal(4)
		end)

		it("produces one glyph per CHARACTER, not per byte, for multi-byte text", function()
			-- The regression: iterating `#text` counted BYTES, so "Café" (5 bytes, 4 characters) produced
			-- five glyph stacks and the obscured string outgrew its source — the exact opposite of the
			-- length-preservation the function promises.
			local _, glyphs = string.gsub(StatusDisplay.obscure("Caf\u{00E9}"), "%-", "")
			expect(glyphs).to.equal(4)
		end)

		it("obscures a multi-byte character rather than leaking it through", function()
			local obscured = StatusDisplay.obscure("Caf\u{00E9}")
			expect(string.find(obscured, "\u{00E9}", 1, true)).never.to.be.ok()
		end)

		it("leaves pure-ASCII output exactly as it was", function()
			-- Character position and byte index coincide for ASCII, so the mark selection — and therefore
			-- every previously-rendered label — is unchanged by the switch to codepoint iteration.
			expect(StatusDisplay.obscure("abcd")).to.equal(StatusDisplay.obscure("abcd"))
			local _, glyphs = string.gsub(StatusDisplay.obscure("ab cd"), "%-", "")
			expect(glyphs).to.equal(4)
		end)

		it("returns empty for empty, rather than a stray glyph", function()
			expect(StatusDisplay.obscure("")).to.equal("")
		end)
	end)
end
