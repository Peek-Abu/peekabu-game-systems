local RankConstants = require(script.Parent.RankConstants)

return function()
	describe("RankConstants", function()
		it("names a season and a persistence switch", function()
			expect(type(RankConstants.RANK_SEASON)).to.equal("string")
			expect(#RankConstants.RANK_SEASON > 0).to.equal(true)
			expect(#RankConstants.RANK_SEASON <= RankConstants.MAX_SEASON_LENGTH).to.equal(true)
			expect(type(RankConstants.RANK_PERSIST)).to.equal("boolean")
		end)

		it("awards the approved XP per shift", function()
			local xp = RankConstants.XP
			expect(xp.shiftWorked).to.equal(10)
			expect(xp.quotaMet).to.equal(15)
			expect(xp.perItem).to.equal(1)
			expect(xp.itemCap).to.equal(10)
			expect(xp.overtimeSalvage).to.equal(5)
			expect(xp.extracted).to.equal(5)
			expect(xp.crewExtracted).to.equal(5)
		end)

		it("has no overhead name tag (the lanyard's ID card shows the rank)", function()
			expect(RankConstants.TAG_PX).to.equal(nil)
		end)

		it("labels every award line", function()
			for key in RankConstants.XP do
				if key ~= "perItem" and key ~= "itemCap" then
					expect(type(RankConstants.LABELS[key])).to.equal("string")
				end
			end
			expect(type(RankConstants.LABELS.items)).to.equal("string")
		end)
	end)
end
