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

	describe("fit", function()
		it("draws the desktop review at full size on a 1920x1080 screen", function()
			expect(ShiftReviewViewModel.fit(Vector2.new(1920, 1080), false)).to.equal(1)
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
end
