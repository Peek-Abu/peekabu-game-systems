local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VM = require(script.Parent.DepotRankChartViewModel)
local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)

return function()
	local levels = RankRegistry.all()

	describe("chart", function()
		it("lists every rank from the top down and marks where you are", function()
			local view = VM.chart(levels[2].xp + 1)
			expect(#view.rows).to.equal(#levels)
			expect(view.rows[1].name).to.equal(levels[#levels].name)
			expect(view.rows[#levels].name).to.equal(levels[1].name)
			local here = 0
			for _, row in view.rows do
				if row.here then
					here += 1
					expect(row.name).to.equal(levels[2].name)
				end
			end
			expect(here).to.equal(1)
		end)

		it("marks the ranks you have reached", function()
			local view = VM.chart(levels[3].xp)
			for _, row in view.rows do
				expect(row.reached).to.equal(row.level <= 3)
			end
		end)

		it("says how much XP the next rank needs", function()
			local view = VM.chart(levels[1].xp)
			expect(view.line).to.equal(`{levels[2].xp - levels[1].xp} more XP to {levels[2].name}!`)
		end)

		it("cheers the top rank", function()
			local top = levels[#levels]
			local view = VM.chart(top.xp + 500)
			expect(view.line).to.equal(`You are the {top.name}!`)
		end)

		it("reads no XP yet as the first rank", function()
			local view = VM.chart(nil)
			expect(view.rows[#levels].here).to.equal(true)
		end)
	end)

	describe("fit", function()
		it("scales the chart to the screen, never past full size", function()
			expect(VM.fit(Vector2.new(4000, 3000), false)).to.equal(1)
			expect(VM.fit(Vector2.new(800, 400), true) < 1).to.equal(true)
			expect(VM.fit(Vector2.new(800, 400), true) > 0).to.equal(true)
		end)
	end)
end
