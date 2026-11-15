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

	describe("badgeDistance (owner 2026-11-14: Boss and Big Boss were cut at the sides)", function()
		-- Every corner of a `size` box centred on the origin is inside a camera `distance` back along -Z looking +Z.
		local function inside(size, aspect, fov, distance)
			local tanV = math.tan(math.rad(fov) / 2)
			local tanH = tanV * aspect
			for _, x in { -size.X / 2, size.X / 2 } do
				for _, y in { -size.Y / 2, size.Y / 2 } do
					for _, z in { -size.Z / 2, size.Z / 2 } do
						local depth = distance + z
						if math.abs(x) > depth * tanH + 1e-6 or math.abs(y) > depth * tanV + 1e-6 then
							return false
						end
					end
				end
			end
			return true
		end

		it("fits a wide badge (Big Boss's bow) in a tall, narrow step frame", function()
			local size = Vector3.new(0.356, 0.640, 0.078)
			local distance = VM.badgeDistance(size, 70 / 150, 30)
			expect(inside(size, 70 / 150, 30, distance)).to.equal(true)
		end)

		it("fits every rank's badge in the step frame and the NEXT RANK card frame", function()
			local sizes = {
				Vector3.new(0.280, 0.635, 0.051),
				Vector3.new(0.299, 0.640, 0.050),
				Vector3.new(0.297, 0.640, 0.050),
				Vector3.new(0.305, 0.643, 0.050),
				Vector3.new(0.330, 0.642, 0.077),
				Vector3.new(0.364, 0.645, 0.076),
				Vector3.new(0.356, 0.640, 0.078),
			}
			for _, aspect in { 70 / 150, 26 / 56, 170 / 360, 66 / 140 } do
				for _, size in sizes do
					expect(inside(size, aspect, 30, VM.badgeDistance(size, aspect, 30))).to.equal(true)
				end
			end
		end)

		it("leaves a little room around the badge, but not much", function()
			local size = Vector3.new(0.3, 0.64, 0.05)
			local distance = VM.badgeDistance(size, 2, 30)
			local tight = (size.Y / 2) / math.tan(math.rad(15)) + size.Z / 2
			expect(distance > tight).to.equal(true)
			expect(distance < tight * 1.25).to.equal(true)
		end)
	end)

	describe("fit", function()
		it("scales the chart to the screen, never past full size", function()
			expect(VM.fit(Vector2.new(4000, 3000), false)).to.equal(1)
			expect(VM.fit(Vector2.new(500, 300), true) < 1).to.equal(true)
			expect(VM.fit(Vector2.new(500, 300), true) > 0).to.equal(true)
		end)
	end)

	describe("phone fit", function()
		local TextService = game:GetService("TextService")

		it("draws the phone chart at full size on a 667 x 375 phone, so no text drops under 12 px", function()
			expect(VM.fit(Vector2.new(667, 375), true)).to.equal(1)
			expect(VM.fit(Vector2.new(640, 360), true) >= 0.95).to.equal(true)
		end)

		it("fits every one-word rank name across its phone step (Sweeper read SWEEPE)", function()
			for _, level in levels do
				if string.find(level.name, " ", 1, true) == nil then
					local width = TextService:GetTextSize(
						level.name,
						VM.PHONE_STEP.nameSize,
						Enum.Font.LuckiestGuy,
						Vector2.new(1000, 100)
					).X
					expect(width <= VM.PHONE_STEP.width - 2).to.equal(true)
				end
			end
		end)
	end)
end
