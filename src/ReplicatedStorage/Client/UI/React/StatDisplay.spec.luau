--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatDisplay = require(ReplicatedStorage.Client.UI.React.StatDisplay)
local StatConstants = require(ReplicatedStorage.Shared.Features.Stat.Data.StatConstants)

return function()
	describe("label", function()
		it("labels a registered stat in upper case", function()
			expect(StatDisplay.label("strength")).to.equal("STRENGTH")
			expect(StatDisplay.label("rotEndurance")).to.equal("ROT ENDURANCE")
		end)

		it("splits camelCase for an unlabelled id rather than rendering it raw", function()
			expect(StatDisplay.label("someNewStat")).to.equal("SOME NEW STAT")
		end)

		it("never returns an empty label", function()
			expect(#StatDisplay.label("x") > 0).to.equal(true)
			expect(#StatDisplay.label("") == 0).to.equal(true) -- the one honest exception: an empty id
		end)

		it("covers every registered stat id, so no live stat falls back", function()
			for _, id in StatConstants.STAT_IDS do
				-- `rawLabel`, not `label`: `label` cannot fail this, because it derives a fallback for any
				-- id at all. Same shape as the description test below, which works for the same reason.
				expect(StatDisplay.rawLabel(id)).to.be.ok()
			end
		end)
	end)

	describe("description", function()
		it("uses the game's own copy where the old UI had some", function()
			expect(StatDisplay.description("strength")).to.equal("Increases overall damage scaling across all types.")
		end)

		it("has copy for every registered stat, so no live stat is tooltip-less", function()
			for _, id in StatConstants.STAT_IDS do
				expect(StatDisplay.description(id)).to.be.ok()
			end
		end)

		it("returns nil for an unknown stat rather than an empty string", function()
			expect(StatDisplay.description("someNewStat")).never.to.be.ok()
		end)
	end)
end
