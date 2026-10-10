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
end
