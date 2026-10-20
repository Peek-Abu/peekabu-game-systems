local ShiftReviewViewModel = require(script.Parent.ShiftReviewViewModel)

local function review(extra)
	local value = {
		outcome = "clockout",
		quota = 350,
		cleared = 362,
		dust = 280,
		bonus = 215,
		salvage = 6,
		piles = 12,
		catches = 3,
		offered = 9,
		rating = "satisfactory",
		quotaMet = true,
		crew = {},
		awards = {
			{ title = "EMPLOYEE OF THE NIGHT", name = "Sam", userId = 1, detail = "hauled 140" },
			{ title = "MOST REHIRED", name = "Alex", userId = 2, detail = "caught twice" },
			{ title = "BUTTERFINGERS", name = "Jo", userId = 3, detail = "dropped the fish tank" },
			{ title = "QUIETEST FEET", name = "Me", userId = 4, detail = "never heard once" },
		},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function snapshot(extra, results)
	local value = {
		phase = "results",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		quota = 350,
		cleared = 362,
		bonus = 215,
		quotaMet = true,
		variant = "B",
		votesAnother = 2,
		votesDepot = 1,
		voteEndsAt = 120,
		crew = { 1, 2, 3 },
		truck = 2,
		results = results or review(),
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("award art by actual title", function()
		it("does not invent art for unknown awards", function()
			expect(#ShiftReviewViewModel.shapesForAward("UNKNOWN")).to.equal(0)
			expect(#ShiftReviewViewModel.shapesForAward("EMPLOYEE OF THE NIGHT") > 0).to.equal(true)
		end)
	end)
	describe("award symbols", function()
		it("maps each real award to its own silhouette", function()
			local expected = {
				["EMPLOYEE OF THE NIGHT"] = "medal",
				["MOST REHIRED"] = "punchCard",
				["BUTTERFINGERS"] = "droppedMug",
				["QUIETEST FEET"] = "quietShoe",
				["LOUDEST VACUUM"] = "noisyVacuum",
			}
			for title, symbol in expected do
				expect(ShiftReviewViewModel.awardSymbol(title)).to.equal(symbol)
			end
		end)
		it("keeps every badge part inside its 64 px canvas", function()
			for _, symbol in { "medal", "punchCard", "droppedMug", "quietShoe", "noisyVacuum" } do
				local shapes = ShiftReviewViewModel.awardShapes(symbol)
				expect(#shapes > 3).to.equal(true)
				for _, shape in shapes do
					expect(shape.x >= 0 and shape.y >= 0).to.equal(true)
					expect(shape.x + shape.w <= 64 and shape.y + shape.h <= 64).to.equal(true)
				end
			end
		end)
		it("does not invent a symbol for an unknown award", function()
			expect(ShiftReviewViewModel.awardSymbol("future award")).to.equal(nil)
		end)
	end)
	describe("review", function()
		it("shows nothing outside results or without a review", function()
			expect(ShiftReviewViewModel.review(snapshot({ phase = "running" }), nil, 4, 100, false)).to.equal(nil)
			expect(ShiftReviewViewModel.review(nil, nil, 4, 100, false)).to.equal(nil)
			local bare = snapshot()
			bare.results = nil
			expect(ShiftReviewViewModel.review(bare, nil, 4, 100, false)).to.equal(nil)
		end)

		it("stamps CONTRACT MET and lists the four rows", function()
			local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
			expect(view.headline).to.equal("CONTRACT MET")
			expect(view.met).to.equal(true)
			expect(view.tab).to.equal("PERFORMANCE REVIEW — NIGHT SHIFT")
			expect(view.subtitle).to.equal("Crew of Truck 2 · Harlow & Finch Ltd. · 4th floor offices")
			expect(view.rows[1].label).to.equal("GLOOM REMOVED")
			expect(view.rows[1].value).to.equal("362 / 350")
			expect(view.rows[2].label).to.equal("EARNED")
			-- 362 Gloom at 1 Gleam each, plus 215 Gleam of valuables.
			expect(view.rows[2].value).to.equal("577 Gleam")
			expect(view.rows[3].label).to.equal("TIMES CAUGHT")
			expect(view.rows[3].value).to.equal("3")
			expect(view.rows[4].label).to.equal("ASSETS RECOVERED")
			expect(view.rows[4].value).to.equal("6 of 9")
			expect(view.ratingLabel).to.equal("Overall rating:")
			expect(view.rating).to.equal("SATISFACTORY")
			expect(view.quote).to.equal('"Those were COMPANY ASSETS."')
			expect(view.quoteBy).to.equal("— The Manager, Site Supervisor Proxy")
			expect(view.voteTitle).to.equal("WHAT NEXT? (crew vote)")
		end)

		it("breaks the Gloom removed and the Gleam earned down into dust, item cleaning and valuables", function()
			local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
			expect(view.rows[1].detail).to.equal("Dust 280 · Item cleaning 82")
			expect(view.rows[2].detail).to.equal("Dust 280 · Cleaning 82 · Valuables 215")
			expect(view.rows[3].detail).to.equal(nil)
		end)

		it("stamps CONTRACT MISSED, still pays what was done, and HR's line", function()
			local view = ShiftReviewViewModel.review(
				snapshot({}, review({ quotaMet = false, rating = "needsImprovement" })),
				nil,
				4,
				100,
				false
			)
			expect(view.headline).to.equal("CONTRACT MISSED")
			expect(view.met).to.equal(false)
			expect(view.rows[2].label).to.equal("EARNED")
			expect(view.rows[2].value).to.equal("577 Gleam")
			expect(view.rating).to.equal("NEEDS IMPROVEMENT")
			expect(view.quote).to.equal('"We will discuss this on Monday."')
			expect(view.quoteBy).to.equal("— Morrow & Morrow, Human Resources")
		end)

		it("never rates a missed quota above NEEDS IMPROVEMENT", function()
			local view = ShiftReviewViewModel.review(
				snapshot({}, review({ quotaMet = false, rating = "exceeds" })),
				nil,
				4,
				100,
				false
			)
			expect(view.rating).to.equal("NEEDS IMPROVEMENT")
		end)

		it("stamps EXCEEDS EXPECTATIONS when the server rated it so", function()
			local view = ShiftReviewViewModel.review(snapshot({}, review({ rating = "exceeds" })), nil, 4, 100, false)
			expect(view.rating).to.equal("EXCEEDS EXPECTATIONS")
		end)

		it("calls an award yours by userId, not by name", function()
			local results = review()
			results.awards[1].name = "Me" -- a teammate with your display name
			local view = ShiftReviewViewModel.review(snapshot({}, results), nil, 4, 100, false)
			expect(#view.awards).to.equal(4)
			expect(view.awards[1].title).to.equal("EMPLOYEE OF THE NIGHT")
			expect(view.awards[1].userId).to.equal(1)
			expect(view.awards[1].line).to.equal("Me — hauled 140")
			expect(view.awards[4].line).to.equal("you — never heard once")
			expect(view.moreAwards).to.equal(nil)
		end)

		it("never calls an award yours without a userId", function()
			local results = review()
			results.awards[1].userId = 0
			local view = ShiftReviewViewModel.review(snapshot({}, results), nil, 0, 100, false)
			expect(view.awards[1].line).to.equal("Sam — hauled 140")
			expect(view.awards[1].userId).to.equal(nil)
		end)

		it("keeps a Studio test player's negative userId so the award shows their portrait", function()
			local results = review()
			results.awards[1].userId = -1
			results.awards[2].userId = -2
			local view = ShiftReviewViewModel.review(snapshot({}, results), nil, -2, 100, false)
			expect(view.awards[1].userId).to.equal(-1)
			expect(view.awards[2].userId).to.equal(-2)
			expect(view.awards[2].line).to.equal("you — caught twice")
		end)

		it("drops the dash when an award has no detail", function()
			local results = review()
			results.awards[2].detail = ""
			local view = ShiftReviewViewModel.review(snapshot({}, results), nil, 4, 100, false)
			expect(view.awards[2].line).to.equal("Alex")
		end)

		it("counts the votes against the crew and marks yours", function()
			local view = ShiftReviewViewModel.review(snapshot(), "another", 4, 100, false)
			expect(view.another.label).to.equal("ANOTHER SHIFT")
			expect(view.another.count).to.equal(2)
			expect(view.another.total).to.equal(3)
			expect(view.another.mine).to.equal(true)
			expect(view.another.mark).to.equal("your vote")
			expect(view.depot.label).to.equal("BACK TO DEPOT")
			expect(view.depot.count).to.equal(1)
			expect(view.depot.mine).to.equal(false)
			expect(view.depot.mark).to.equal(nil)
			expect(view.footer).to.equal("Majority decides · auto-picks in 0:20 · a tie means Another shift")
		end)

		it("keeps the vote open until it closes at 0:00", function()
			expect(ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false).voteOpen).to.equal(true)
			expect(ShiftReviewViewModel.review(snapshot(), nil, 4, 120, false).voteOpen).to.equal(false)
			expect(ShiftReviewViewModel.review(snapshot(), nil, 4, 130, false).voteOpen).to.equal(false)
			local value = snapshot()
			value.voteEndsAt = nil
			expect(ShiftReviewViewModel.review(value, nil, 4, 100, false).voteOpen).to.equal(true)
		end)

		it("marks nothing before you vote", function()
			local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
			expect(view.another.mine).to.equal(false)
			expect(view.depot.mine).to.equal(false)
		end)

		it("never counts fewer voters than votes cast", function()
			local view = ShiftReviewViewModel.review(snapshot({ crew = { 1 } }), "depot", 4, 100, false)
			expect(view.another.total).to.equal(3)
			expect(view.depot.mine).to.equal(true)
		end)

		it("writes the phone's vote lines and folds the extra awards", function()
			local view = ShiftReviewViewModel.review(snapshot(), "another", 4, 100, true)
			expect(view.another.text).to.equal("ANOTHER SHIFT  2/3")
			expect(view.another.mark).to.equal("your vote")
			expect(view.depot.text).to.equal("BACK TO DEPOT  1/3")
			expect(#view.awards).to.equal(2)
			expect(view.awards[1].line).to.equal("Sam")
			expect(view.moreAwards).to.equal("+2 MORE AWARDS")
			expect(#view.extraAwards).to.equal(2)
			expect(view.extraAwards[2].title).to.equal("QUIETEST FEET")
			expect(view.extraAwards[2].line).to.equal("you")
			expect(view.lessAwards).to.equal("FIRST 2 AWARDS")
			expect(view.tab).to.equal("PERFORMANCE REVIEW")
			expect(view.ratingLabel).to.equal("Rating:")
			expect(view.voteTitle).to.equal("WHAT NEXT?")
			expect(view.footer).to.equal("Majority decides · auto-picks in 0:20\nA tie means Another shift")
		end)

		it("offers no more awards on the phone when there are two or fewer", function()
			local results = review()
			results.awards = { results.awards[1] }
			local view = ShiftReviewViewModel.review(snapshot({}, results), nil, 4, 100, true)
			expect(#view.awards).to.equal(1)
			expect(view.moreAwards).to.equal(nil)
			expect(#view.extraAwards).to.equal(0)
		end)

		it("never counts the vote timer below 0:00 and drops the truck when unknown", function()
			local value = snapshot({ voteEndsAt = 90 })
			value.truck = nil -- (a nil in the extras table would be skipped by the loop)
			local view = ShiftReviewViewModel.review(value, nil, 4, 100, false)
			expect(view.footer).to.equal("Majority decides · auto-picks in 0:00 · a tie means Another shift")
			expect(view.subtitle).to.equal("Crew · Harlow & Finch Ltd. · 4th floor offices")
		end)
	end)

	describe("reopen tab", function()
		it("offers the tab while the vote runs and the review was closed", function()
			expect(ShiftReviewViewModel.reopen(snapshot(), {})).to.equal("PERFORMANCE REVIEW · OPEN")
			expect(ShiftReviewViewModel.reopen(snapshot(), { "depot.Board" })).to.equal("PERFORMANCE REVIEW · OPEN")
		end)

		it("hides the tab while the review is open", function()
			expect(ShiftReviewViewModel.reopen(snapshot(), { "shift.Review" })).to.equal(nil)
		end)

		it("hides the tab outside results and before the review arrives", function()
			expect(ShiftReviewViewModel.reopen(snapshot({ phase = "running" }), {})).to.equal(nil)
			expect(ShiftReviewViewModel.reopen(nil, {})).to.equal(nil)
			local bare = snapshot()
			bare.results = nil
			expect(ShiftReviewViewModel.reopen(bare, {})).to.equal(nil)
		end)
	end)

	describe("badge", function()
		it("keeps the design width and centres under the medallion when the label fits", function()
			local badge = ShiftReviewViewModel.badge(240, false)
			expect(badge.medalX).to.equal(1680 - 150)
			expect(badge.width).to.equal(260)
			expect(badge.x).to.equal(1530)
			expect(ShiftReviewViewModel.badge(105, true).width).to.equal(110)
		end)

		it("pulls even the design-width phone badge 11 px in: centred at 710 it ran 5 px off the 760 canvas", function()
			local badge = ShiftReviewViewModel.badge(105, true)
			expect(badge.medalX).to.equal(710)
			-- 760 - 6 - 110 / 2 = 699: it spans 644..754, still under the 84 px medallion (668..752).
			expect(badge.x).to.equal(699)
			expect(math.abs(badge.x - badge.medalX) < 84 / 2).to.equal(true)
		end)

		it("widens to the measured label when it needs more than the design width, and stays on the canvas", function()
			local badge = ShiftReviewViewModel.badge(158, true)
			expect(badge.width).to.equal(158)
			-- Centred at 710 it would end at 789, past the 760 canvas: pulled left to end 6 px inside it.
			expect(badge.x).to.equal(760 - 6 - 79)
			expect(badge.x + badge.width / 2 <= 760 - ShiftReviewViewModel.BADGE_MARGIN).to.equal(true)
		end)

		it("pulls a badge that only just overflows left by exactly the overflow", function()
			expect(ShiftReviewViewModel.badge(120, true).x).to.equal(694)
		end)
	end)

	describe("fit", function()
		it("draws the desktop review at full size on a 1920x1080 screen", function()
			expect(ShiftReviewViewModel.fit(Vector2.new(1920, 1080), false)).to.equal(1)
		end)

		it("grows the review with the UI on a 4K monitor (the one UI scale)", function()
			expect(ShiftReviewViewModel.fit(Vector2.new(3840, 2160), false)).to.equal(2)
		end)

		it("shrinks the desktop review on a 1366x768 screen", function()
			local scale = ShiftReviewViewModel.fit(Vector2.new(1366, 768), false)
			expect(scale < 1).to.equal(true)
			expect(1600 * scale <= 1366 - 120).to.equal(true)
			expect(946 * scale <= 768 - 98).to.equal(true)
		end)

		it("fills the phone safe area at 844x390", function()
			expect(ShiftReviewViewModel.fit(Vector2.new(844, 390), true)).to.equal(1)
		end)

		it("never shrinks below the minimum scale", function()
			expect(ShiftReviewViewModel.fit(Vector2.new(10, 10), false)).to.equal(ShiftReviewViewModel.MIN_SCALE)
		end)
	end)
	describe("V1 results", function()
		it("shouts the outcome and grades the rating", function()
			local met = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
			expect(met.title).to.equal("CONTRACT MET!")
			expect(met.grade).to.equal("B")
			local missed = ShiftReviewViewModel.review(
				snapshot({}, review({ quotaMet = false, rating = "exceeds" })),
				nil,
				4,
				100,
				false
			)
			expect(missed.title).to.equal("CONTRACT MISSED")
			expect(missed.grade).to.equal("C")
			local great = ShiftReviewViewModel.review(snapshot({}, review({ rating = "exceeds" })), nil, 4, 100, false)
			expect(great.grade).to.equal("A")
		end)

		it("gives each stat card its render, its number and its meaning", function()
			local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
			local cards = view.cards
			expect(#cards).to.equal(4)
			expect(cards[1].icon).to.equal("gloom")
			expect(cards[1].value).to.equal("362/350")
			expect(cards[1].meaning).to.equal("grape")
			expect(cards[2].icon).to.equal("gleamPile")
			expect(cards[2].value).to.equal("+577")
			expect(cards[2].meaning).to.equal("gold")
			expect(cards[2].gold).to.equal(true)
			expect(cards[3].icon).to.equal("managerHunt")
			expect(cards[3].value).to.equal("3")
			expect(cards[3].meaning).to.equal("coral")
			expect(cards[4].icon).to.equal("fishtank")
			expect(cards[4].value).to.equal("6 OF 9")
			expect(cards[4].meaning).to.equal("mint")
		end)

		it("draws each award with a render", function()
			local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 100, false)
			expect(view.awards[1].icon).to.equal("trophy")
			expect(view.awards[2].icon).to.equal("managerCalm")
			expect(view.awards[3].icon).to.equal("grab")
			expect(view.awards[4].icon).to.equal("stamina")
			expect(ShiftReviewViewModel.awardIcon("noisyVacuum")).to.equal("vacuum")
		end)

		it("shows the vote's time left on its own", function()
			local view = ShiftReviewViewModel.review(snapshot(), nil, 4, 96, false)
			expect(view.voteClock).to.equal("0:24")
		end)
	end)

	describe("vote row", function()
		it("sits clear of the desktop awards' ink: 768 is the last card's bottom, its ink reaches 780", function()
			local row = ShiftReviewViewModel.voteRow(768, false)
			expect(row.headerTop).to.equal(794)
			expect(row.buttonsTop).to.equal(846)
			expect(row.headerTop - (768 + ShiftReviewViewModel.AWARD_INK)).to.equal(ShiftReviewViewModel.VOTE_GAP)
		end)

		it("follows the awards' bottom on desktop", function()
			expect(ShiftReviewViewModel.voteRow(700, false).headerTop).to.equal(726)
		end)

		it("keeps the phone's fixed row whatever the awards", function()
			local row = ShiftReviewViewModel.voteRow(500, true)
			expect(row.headerTop).to.equal(262)
			expect(row.buttonsTop).to.equal(314)
		end)

		it("keeps the phone's vote clock 6 px under the awards' ink and clear of the buttons' lifted ring", function()
			local row = ShiftReviewViewModel.voteRow(500, true)
			local clock = ShiftReviewViewModel.PHONE_CLOCK
			-- The phone's last award card ends at 258 (featured 124..196, then 204..258); its drop and outline reach ~267.
			expect(row.headerTop + clock.top - 267 >= 6).to.equal(true)
			-- The chosen button's ring reaches 20 px over the buttons.
			expect(row.headerTop + clock.top + clock.height <= row.buttonsTop - 20).to.equal(true)
		end)
	end)
end
