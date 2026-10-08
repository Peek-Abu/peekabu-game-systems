--[[
	Unit tests for TitleSliceRules — the per-slice data-layer invariants. Encodes the spec's
	lenient-vs-hard asymmetry table exactly: structure is HARD, retired ids are LENIENT, and
	cross-slice membership is deliberately absent (service policy — see the class header).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleSliceRules = require(ReplicatedStorage.Shared.Features.Title.Rules.TitleSliceRules)

return function()
	describe("validateTitles", function()
		it("accepts an empty earned set", function()
			local ok, reason = TitleSliceRules.validateTitles({ earned = {} })
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
		end)

		it("accepts well-formed earned entries", function()
			local ok = TitleSliceRules.validateTitles({ earned = { veteran = true } })
			expect(ok).to.equal(true)
		end)

		it("LENIENTLY accepts an id no longer in the registry (retired-title rule)", function()
			local ok = TitleSliceRules.validateTitles({ earned = { ["deleted-long-ago"] = true } })
			expect(ok).to.equal(true)
		end)

		it("hard-fails a non-table slice and a missing/malformed earned map", function()
			expect(select(2, TitleSliceRules.validateTitles(nil :: any))).to.be.ok()
			expect(select(2, TitleSliceRules.validateTitles({} :: any))).to.be.ok()
			expect(select(2, TitleSliceRules.validateTitles({ earned = "veteran" } :: any))).to.be.ok()
		end)

		it("hard-fails non-string or empty ids and non-true values", function()
			expect(select(2, TitleSliceRules.validateTitles({ earned = { [1] = true } :: any }))).to.be.ok()
			expect(select(2, TitleSliceRules.validateTitles({ earned = { [""] = true } }))).to.be.ok()
			expect(select(2, TitleSliceRules.validateTitles({ earned = { veteran = false } }))).to.be.ok()
			expect(select(2, TitleSliceRules.validateTitles({ earned = { veteran = "yes" } :: any }))).to.be.ok()
		end)
	end)

	describe("validateEquippedTitle", function()
		it("accepts an empty wrapper (wearing nothing)", function()
			local ok, reason = TitleSliceRules.validateEquippedTitle({})
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
		end)

		it("accepts a non-empty string equipped title", function()
			local ok = TitleSliceRules.validateEquippedTitle({ equipped = "veteran" })
			expect(ok).to.equal(true)
		end)

		it("hard-fails a non-table wrapper", function()
			expect(select(2, TitleSliceRules.validateEquippedTitle(nil :: any))).to.be.ok()
			expect(select(2, TitleSliceRules.validateEquippedTitle("veteran" :: any))).to.be.ok()
		end)

		it("hard-fails a non-string or empty equipped value", function()
			expect(select(2, TitleSliceRules.validateEquippedTitle({ equipped = 7 } :: any))).to.be.ok()
			expect(select(2, TitleSliceRules.validateEquippedTitle({ equipped = "" }))).to.be.ok()
		end)
	end)
end
