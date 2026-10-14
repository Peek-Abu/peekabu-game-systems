local RankRegistry = require(script.Parent.RankRegistry)

return function()
	describe("RankRegistry", function()
		it("starts the ladder at level 1 with 0 XP", function()
			local first = RankRegistry.get(1)
			expect(first).to.be.ok()
			expect(first.xp).to.equal(0)
			expect(first.name).to.equal("Intern (Unpaid)")
		end)

		it("lists the MVP ladder in order with rising thresholds", function()
			local all = RankRegistry.all()
			expect(#all >= 3).to.equal(true)
			expect(all[2].name).to.equal("Probationary Associate")
			expect(all[2].xp).to.equal(40)
			expect(all[3].name).to.equal("Clearance Associate")
			expect(all[3].xp).to.equal(120)
			for index, level in all do
				expect(level.level).to.equal(index)
				if index > 1 then
					expect(level.xp > all[index - 1].xp).to.equal(true)
				end
				expect(typeof(level.lanyard)).to.equal("Color3")
				expect(type(level.lanyardName)).to.equal("string")
			end
		end)

		it("returns nil past the top and names the top level", function()
			local all = RankRegistry.all()
			expect(RankRegistry.get(#all + 1)).never.to.be.ok()
			expect(RankRegistry.get(0)).never.to.be.ok()
			expect(RankRegistry.top().level).to.equal(#all)
		end)

		it("hands out copies of the list", function()
			local list = RankRegistry.all()
			table.remove(list, 1)
			expect(RankRegistry.get(1)).to.be.ok()
			expect(#RankRegistry.all()).to.equal(#list + 1)
		end)

		it("rejects a malformed ladder", function()
			expect(RankRegistry.check({})).to.equal(false)
			expect(RankRegistry.check({
				{ level = 1, name = "A", xp = 5, lanyard = Color3.new(), lanyardName = "grey" },
			})).to.equal(false)
			expect(RankRegistry.check({
				{ level = 1, name = "A", xp = 0, lanyard = Color3.new(), lanyardName = "grey" },
				{ level = 2, name = "B", xp = 0, lanyard = Color3.new(), lanyardName = "grey" },
			})).to.equal(false)
			expect(RankRegistry.check({
				{ level = 1, name = "A", xp = 0, lanyard = Color3.new(), lanyardName = "grey" },
				{ level = 3, name = "B", xp = 10, lanyard = Color3.new(), lanyardName = "grey" },
			})).to.equal(false)
			expect(RankRegistry.check(RankRegistry.all())).to.equal(true)
		end)
	end)
end
