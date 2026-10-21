local RankFormulas = require(script.Parent.RankFormulas)

local function facts(overrides)
	local base = {
		worked = true,
		quotaMet = false,
		items = 0,
		overtimeSalvage = 0,
		extracted = false,
		caught = false,
		crewExtracted = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function line(userId, extra)
	local entry = { userId = userId, name = `P{userId}`, banked = 0, piles = 0, salvage = 0, caught = 0 }
	for key, value in extra or {} do
		entry[key] = value
	end
	return entry
end

local function results(lines, quotaMet)
	return {
		outcome = "clockout",
		quota = 100,
		cleared = 100,
		bonus = 0,
		salvage = 0,
		piles = 0,
		catches = 0,
		offered = 0,
		rating = "satisfactory",
		quotaMet = quotaMet,
		crew = lines,
		awards = {},
	}
end

local function amountOf(award, key)
	for _, entry in award.lines do
		if entry.key == key then
			return entry.xp
		end
	end
	return nil
end

return function()
	describe("levelFor", function()
		it("maps XP to the highest level reached", function()
			expect(RankFormulas.levelFor(0).level).to.equal(1)
			expect(RankFormulas.levelFor(39).level).to.equal(1)
			expect(RankFormulas.levelFor(40).level).to.equal(2)
			expect(RankFormulas.levelFor(119).level).to.equal(2)
			expect(RankFormulas.levelFor(120).level).to.equal(3)
		end)

		it("stays at the top level past its threshold", function()
			local top = RankFormulas.levelFor(10 ^ 6)
			expect(top.level >= 3).to.equal(true)
		end)
	end)

	describe("progress", function()
		it("measures progress inside the current level", function()
			local progress = RankFormulas.progress(60)
			expect(progress.level.level).to.equal(2)
			expect(progress.next.level).to.equal(3)
			expect(progress.into).to.equal(20)
			expect(progress.span).to.equal(80)
			expect(progress.fill).to.equal(0.25)
		end)

		it("is full with no next level at the top", function()
			local progress = RankFormulas.progress(10 ^ 6)
			expect(progress.next).never.to.be.ok()
			expect(progress.fill).to.equal(1)
		end)
	end)

	describe("award", function()
		it("gives +10 for a worked shift and nothing else by default", function()
			local award = RankFormulas.award(facts())
			expect(award.total).to.equal(10)
			expect(#award.lines).to.equal(1)
			expect(award.incident).to.equal(false)
		end)

		it("adds every bonus earned, capping cargo at 10 items", function()
			local award = RankFormulas.award(facts({
				quotaMet = true,
				items = 14,
				overtimeSalvage = 2,
				extracted = true,
				crewExtracted = true,
			}))
			expect(amountOf(award, "quotaMet")).to.equal(15)
			expect(amountOf(award, "items")).to.equal(10)
			expect(amountOf(award, "overtimeSalvage")).to.equal(5)
			expect(amountOf(award, "extracted")).to.equal(5)
			expect(amountOf(award, "crewExtracted")).to.equal(5)
			expect(award.total).to.equal(10 + 15 + 10 + 5 + 5 + 5)
		end)

		it("gives a caught player no extraction bonus and files an incident report", function()
			local award =
				RankFormulas.award(facts({ quotaMet = true, caught = true, extracted = true, crewExtracted = true }))
			expect(amountOf(award, "extracted")).never.to.be.ok()
			expect(amountOf(award, "crewExtracted")).never.to.be.ok()
			expect(award.incident).to.equal(true)
			expect(award.total).to.equal(25)
		end)

		it("gives nothing to someone who did not work the shift", function()
			local award = RankFormulas.award(facts({ worked = false, quotaMet = true }))
			expect(award.total).to.equal(0)
			expect(#award.lines).to.equal(0)
		end)
	end)

	describe("factsFor", function()
		it("reads a crew member's run from the review", function()
			local review = results({ line(1, { items = 4, overtimeSalvage = 1 }), line(2) }, true)
			local f = RankFormulas.factsFor(RankFormulas.entriesOf(review), review.quotaMet, { 1, 2 }, 1, "clockout")
			expect(f.worked).to.equal(true)
			expect(f.quotaMet).to.equal(true)
			expect(f.items).to.equal(4)
			expect(f.overtimeSalvage).to.equal(1)
			expect(f.extracted).to.equal(true)
			expect(f.crewExtracted).to.equal(true)
			expect(f.caught).to.equal(false)
		end)

		it("is nil for someone not on the review", function()
			expect(
				RankFormulas.factsFor(RankFormulas.entriesOf(results({ line(1) }, false)), false, { 1 }, 9, "clockout")
			).never.to.be.ok()
		end)

		it("treats a caught or departed crew member as not extracted, for them and the crew", function()
			local review = results({ line(1), line(2, { caught = 1 }), line(3) }, false)
			local caught =
				RankFormulas.factsFor(RankFormulas.entriesOf(review), review.quotaMet, { 1, 2 }, 2, "clockout")
			expect(caught.caught).to.equal(true)
			expect(caught.extracted).to.equal(false)
			local other =
				RankFormulas.factsFor(RankFormulas.entriesOf(review), review.quotaMet, { 1, 2 }, 1, "clockout")
			expect(other.extracted).to.equal(true)
			expect(other.crewExtracted).to.equal(false)
			-- Player 3 is on the review but left before the end.
			expect(
				RankFormulas.factsFor(RankFormulas.entriesOf(review), review.quotaMet, { 1, 2 }, 3, "clockout").extracted
			).to.equal(false)
		end)

		it("pays the clock-out line only when the shift ended through the clock-out", function()
			local review = results({ line(1), line(2) }, true)
			local entries = RankFormulas.entriesOf(review)
			-- Everyone punched, or the truck-leaves countdown ran out: the whole crew still in is paid, punched or not.
			local out = RankFormulas.factsFor(entries, true, { 1, 2 }, 2, "clockout")
			expect(out.extracted).to.equal(true)
			-- The shift timer ran out with no clock-out (or any other end): no clock-out line for anyone.
			for _, outcome in { "timeout", "abandoned", "wiped", "cancelled" } do
				local f = RankFormulas.factsFor(entries, true, { 1, 2 }, 1, outcome)
				expect(f.extracted).to.equal(false)
				expect(f.worked).to.equal(true)
				local award = RankFormulas.award(f)
				for _, awarded in award.lines do
					expect(awarded.key).never.to.equal("extracted")
				end
			end
		end)

		it("pays the whole-crew line only when the shift ended through the clock-out", function()
			local entries = RankFormulas.entriesOf(results({ line(1), line(2) }, true))
			expect(RankFormulas.factsFor(entries, true, { 1, 2 }, 1, "clockout").crewExtracted).to.equal(true)
			for _, outcome in { "timeout", "abandoned", "wiped", "cancelled" } do
				local f = RankFormulas.factsFor(entries, true, { 1, 2 }, 1, outcome)
				expect(f.crewExtracted).to.equal(false)
				expect(amountOf(RankFormulas.award(f), "crewExtracted")).never.to.be.ok()
			end
		end)

		it("reads absent cargo counts as zero", function()
			local f =
				RankFormulas.factsFor(RankFormulas.entriesOf(results({ line(1) }, false)), false, { 1 }, 1, "clockout")
			expect(f.items).to.equal(0)
			expect(f.overtimeSalvage).to.equal(0)
		end)
	end)
end
