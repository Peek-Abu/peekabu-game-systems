local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VM = require(script.Parent.DepotRankChartViewModel)
local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)

return function()
	local levels = RankRegistry.all()
	local top = levels[#levels]

	describe("chart: the steps", function()
		it("has one step per rank, lowest first, each with its level and the XP that reaches it", function()
			local view = VM.chart(0)
			expect(#view.steps).to.equal(#levels)
			for index, step in view.steps do
				expect(step.level).to.equal(levels[index].level)
				expect(step.name).to.equal(string.upper(levels[index].name))
				expect(step.levelText).to.equal(`LEVEL {levels[index].level}`)
				expect(step.colour).to.equal(levels[index].lanyard)
			end
			expect(view.steps[1].xpText).to.equal("0 XP")
			expect(view.steps[5].xpText).to.equal("1,800 XP")
		end)

		it("marks the ranks you have reached and the one you are on", function()
			local view = VM.chart(levels[3].xp + 10)
			local here = 0
			for _, step in view.steps do
				expect(step.reached).to.equal(step.level <= 3)
				if step.here then
					here += 1
					expect(step.level).to.equal(3)
				end
			end
			expect(here).to.equal(1)
		end)

		it("reads no XP yet as the first rank", function()
			local view = VM.chart(nil)
			expect(view.steps[1].here).to.equal(true)
			expect(view.here).to.equal(1)
		end)

		it("never counts shifts: ranks are reached at a level's XP (owner 2026-11-14)", function()
			for _, xp in { 0, 120, levels[4].xp, top.xp + 1 } do
				local view = VM.chart(xp)
				for _, text in { view.card.xpText, view.card.levelText, table.unpack(view.card.gets) } do
					expect(string.find(string.lower(text), "shift", 1, true)).to.equal(nil)
				end
			end
		end)
	end)

	describe("chart: the NEXT RANK card", function()
		it("names the next rank, its level and the XP bar toward it", function()
			local view = VM.chart(560)
			expect(view.top).to.equal(false)
			expect(view.card.title).to.equal("NEXT RANK")
			expect(view.card.rank).to.equal("SUPER CLEANER")
			expect(view.card.badge).to.equal(4)
			expect(view.card.levelText).to.equal("Level 4")
			expect(view.card.xpText).to.equal("560 / 800 XP")
			-- The bar fills across the band from Cleaner (300) to Super Cleaner (800).
			expect(view.card.fraction).to.be.near((560 - 300) / (800 - 300), 1e-6)
		end)

		it("lists what the next rank gives, in short words", function()
			local view = VM.chart(560)
			expect(view.card.gets[1]).to.equal("A purple lanyard")
			expect(view.card.gets[2]).to.equal("A new badge to wear")
			expect(view.card.gets[3]).to.equal("A Roblox badge")
			expect(view.card.gets[4]).to.equal("A new pose")
			for _, line in view.card.gets do
				expect(#line <= 24).to.equal(true)
			end
		end)

		it("starts the bar empty on a new rank", function()
			expect(VM.chart(levels[2].xp).card.fraction).to.equal(0)
		end)
	end)

	describe("chart: the Big Boss view", function()
		it("lights every step and turns the card into TOP RANK with the XP total", function()
			local view = VM.chart(5640)
			expect(view.top).to.equal(true)
			expect(view.here).to.equal(#levels)
			for _, step in view.steps do
				expect(step.reached).to.equal(true)
			end
			expect(view.card.title).to.equal("TOP RANK!")
			expect(view.card.rank).to.equal("BIG BOSS")
			expect(view.card.badge).to.equal(top.level)
			expect(view.card.levelText).to.equal(`Level {top.level}`)
			expect(view.card.xpText).to.equal("5,640 XP")
			expect(view.card.fraction).to.equal(1)
			expect(view.card.gets[1]).to.equal("You have every lanyard!")
		end)

		it("cheers you in the header instead of pointing at the next level", function()
			expect(VM.chart(top.xp).subtitle).to.equal("You made it to the top!\nEveryone can see your gold lanyard.")
			expect(VM.chart(0).subtitle).to.equal("Earn XP on every shift.\nReach the next level to rank up!")
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
