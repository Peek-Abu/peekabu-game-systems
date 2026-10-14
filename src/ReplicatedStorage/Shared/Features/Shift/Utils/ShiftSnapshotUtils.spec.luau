local ShiftSnapshotUtils = require(script.Parent.ShiftSnapshotUtils)

local function state(extra)
	local value = {
		phase = "running",
		sub = "normal",
		shift = 2,
		endsAt = 900,
		quota = 350,
		quotaMet = false,
		variant = "B",
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local RESULTS = {
	outcome = "clockout",
	quota = 350,
	cleared = 380,
	bonus = 95,
	salvage = 3,
	piles = 12,
	quotaMet = true,
	crew = { { name = "Ava", banked = 200, piles = 6, salvage = 2 } },
	awards = { { title = "Top Hauler", name = "Ava" } },
}

return function()
	it("round-trips a running shift", function()
		local snapshot = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state(), 120, 40, 0, 0, nil))
		expect(snapshot).to.be.ok()
		expect(snapshot.phase).to.equal("running")
		expect(snapshot.sub).to.equal("normal")
		expect(snapshot.shift).to.equal(2)
		expect(snapshot.endsAt).to.equal(900)
		expect(snapshot.cleared).to.equal(120)
		expect(snapshot.bonus).to.equal(40)
		expect(snapshot.quota).to.equal(350)
		expect(snapshot.variant).to.equal("B")
		expect(snapshot.results).to.equal(nil)
	end)

	it("round-trips a clock-out countdown", function()
		local snapshot = ShiftSnapshotUtils.decode(
			ShiftSnapshotUtils.build(state({ sub = "clockout", clockOutAt = 500 }), 0, 0, 0, 0, nil)
		)
		expect(snapshot.sub).to.equal("clockout")
		expect(snapshot.clockOutAt).to.equal(500)
	end)

	it("round-trips results and votes", function()
		local value = ShiftSnapshotUtils.build(
			state({ phase = "results", voteEndsAt = 1000, quotaMet = true }),
			380,
			95,
			2,
			1,
			RESULTS
		)
		local snapshot = ShiftSnapshotUtils.decode(value)
		expect(snapshot.phase).to.equal("results")
		expect(snapshot.voteEndsAt).to.equal(1000)
		expect(snapshot.votesAnother).to.equal(2)
		expect(snapshot.votesDepot).to.equal(1)
		expect(snapshot.results.cleared).to.equal(380)
		expect(snapshot.results.crew[1].name).to.equal("Ava")
		expect(snapshot.results.awards[1].title).to.equal("Top Hauler")
	end)

	-- Every ShiftSub in ShiftTypes must survive build/decode: add the new value here when M2 extends the type.
	it("round-trips every shift sub-state", function()
		for _, sub in { "normal", "clockout" } do
			local snapshot = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state({ sub = sub }), 0, 0, 0, 0, nil))
			expect(snapshot).to.be.ok()
			expect(snapshot.sub).to.equal(sub)
		end
	end)

	it("defaults absent vote counts to zero", function()
		local snapshot = ShiftSnapshotUtils.decode({
			phase = "lobby",
			sub = "normal",
			shift = 0,
			quota = 350,
			cleared = 0,
			bonus = 0,
			quotaMet = false,
			variant = "B",
		})
		expect(snapshot.votesAnother).to.equal(0)
		expect(snapshot.votesDepot).to.equal(0)
	end)

	it("rejects malformed values", function()
		local good = ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil)
		local function with(key, value)
			local copy = table.clone(good)
			copy[key] = value
			return copy
		end
		expect(ShiftSnapshotUtils.decode(nil)).to.equal(nil)
		expect(ShiftSnapshotUtils.decode("running")).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("phase", "overtime"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("sub", "nap"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("variant", "C"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("quota", nil))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("endsAt", "soon"))).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(with("results", { outcome = "clockout" }))).to.equal(nil)
	end)

	it("round-trips the pacing stage, its deadline and the tier", function()
		local snapshot = ShiftSnapshotUtils.decode(
			ShiftSnapshotUtils.build(state({ stage = "warning", stageEndsAt = 640, tier = 2 }), 0, 0, 0, 0, nil)
		)
		expect(snapshot.stage).to.equal("warning")
		expect(snapshot.stageEndsAt).to.equal(640)
		expect(snapshot.tier).to.equal(2)
	end)

	it("reads an absent stage as normal and an absent tier as 0", function()
		local snapshot = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil))
		expect(snapshot.stage).to.equal("normal")
		expect(snapshot.stageEndsAt).to.equal(nil)
		expect(snapshot.tier).to.equal(0)
	end)

	it("rejects an unknown stage or a malformed stage deadline", function()
		local good = ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil)
		local badStage = table.clone(good)
		badStage.stage = "nap"
		local badDeadline = table.clone(good)
		badDeadline.stageEndsAt = "soon"
		expect(ShiftSnapshotUtils.decode(badStage)).to.equal(nil)
		expect(ShiftSnapshotUtils.decode(badDeadline)).to.equal(nil)
	end)

	it("round-trips Harlow's catch count in the results, absent reading 0", function()
		local review = table.clone(RESULTS)
		review.catches = 2
		local value = ShiftSnapshotUtils.build(state({ phase = "results", voteEndsAt = 1000 }), 380, 95, 0, 0, review)
		expect(ShiftSnapshotUtils.decode(value).results.catches).to.equal(2)
		local plain = ShiftSnapshotUtils.build(state({ phase = "results", voteEndsAt = 1000 }), 380, 95, 0, 0, RESULTS)
		expect(ShiftSnapshotUtils.decode(plain).results.catches).to.equal(0)
	end)

	describe("M3 UI fields", function()
		local FULL = {
			outcome = "clockout",
			quota = 350,
			cleared = 380,
			bonus = 95,
			salvage = 6,
			piles = 12,
			catches = 3,
			quotaMet = true,
			offered = 9,
			rating = "exceeds",
			crew = { { userId = 7, name = "Ava", banked = 200, piles = 6, salvage = 2, caught = 1 } },
			awards = { { title = "MOST REHIRED", name = "Ava", userId = 7, detail = "caught once" } },
		}

		it("carries the crew, the truck, the rating and the award details through build and decode", function()
			local snapshot = ShiftSnapshotUtils.build(state({ phase = "results" }), 380, 95, 1, 0, FULL, { 7, 9 }, 2)
			local decoded = ShiftSnapshotUtils.decode(snapshot)
			expect(decoded.truck).to.equal(2)
			expect(#decoded.crew).to.equal(2)
			expect(decoded.results.offered).to.equal(9)
			expect(decoded.results.rating).to.equal("exceeds")
			expect(decoded.results.crew[1].userId).to.equal(7)
			expect(decoded.results.crew[1].caught).to.equal(1)
			expect(decoded.results.awards[1].userId).to.equal(7)
			expect(decoded.results.awards[1].detail).to.equal("caught once")
		end)

		it("carries each crew member's cargo items and overtime salvage, absent reading 0", function()
			local withCargo = table.clone(FULL)
			withCargo.crew = {
				{
					userId = 7,
					name = "Ava",
					banked = 200,
					piles = 6,
					salvage = 2,
					caught = 0,
					items = 4,
					overtimeSalvage = 1,
				},
			}
			local decoded = ShiftSnapshotUtils.decode(
				ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, withCargo, { 7 })
			)
			expect(decoded.results.crew[1].items).to.equal(4)
			expect(decoded.results.crew[1].overtimeSalvage).to.equal(1)
			local plain =
				ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, FULL))
			expect(plain.results.crew[1].items).to.equal(0)
			expect(plain.results.crew[1].overtimeSalvage).to.equal(0)
			local bad = table.clone(FULL)
			bad.crew = { { userId = 7, name = "Ava", banked = 0, piles = 0, salvage = 0, items = "4" } }
			expect(ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, bad))).to.equal(
				nil
			)
		end)

		it("reads absent M3 fields as empty, zero or derived", function()
			local decoded = ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil))
			expect(#decoded.crew).to.equal(0)
			expect(decoded.truck).to.equal(nil)
			local old =
				ShiftSnapshotUtils.decode(ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, RESULTS))
			expect(old.results.offered).to.equal(0)
			expect(old.results.rating).to.equal("satisfactory")
			expect(old.results.crew[1].userId).to.equal(0)
			expect(old.results.awards[1].detail).to.equal("")
		end)

		it("rejects an unknown rating, a crew list that is not numbers and a text truck", function()
			local bad = table.clone(FULL)
			bad.rating = "superb"
			local results = ShiftSnapshotUtils.build(state({ phase = "results" }), 0, 0, 0, 0, bad)
			expect(ShiftSnapshotUtils.decode(results)).to.equal(nil)
			local snapshot = ShiftSnapshotUtils.build(state(), 0, 0, 0, 0, nil)
			snapshot.crew = { "Ava" }
			expect(ShiftSnapshotUtils.decode(snapshot)).to.equal(nil)
			snapshot.crew = {}
			snapshot.truck = "2"
			expect(ShiftSnapshotUtils.decode(snapshot)).to.equal(nil)
		end)
	end)
end
