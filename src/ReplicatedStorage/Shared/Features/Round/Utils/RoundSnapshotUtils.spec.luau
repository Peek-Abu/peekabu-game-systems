local RoundSnapshotUtils = require(script.Parent.RoundSnapshotUtils)

local function full()
	return {
		phase = "running",
		round = 3,
		endsAt = 120.5,
		participants = { 1, 2 },
		eliminated = { 2 },
		team = { scrap = 40 },
		targets = { scrap = 300 },
		scores = { ["1"] = { kills = 2 } },
		containers = {
			team = {
				{ itemType = "flare", quantity = 2 },
				{ itemType = "wrench", uid = "r3-1", attrs = { durability = 5 } },
			},
		},
	}
end

return function()
	it("decodes a full snapshot", function()
		local snapshot = RoundSnapshotUtils.decode(full())
		expect(snapshot).to.be.ok()
		expect(snapshot.phase).to.equal("running")
		expect(snapshot.round).to.equal(3)
		expect(snapshot.endsAt).to.equal(120.5)
		expect(#snapshot.participants).to.equal(2)
		expect(snapshot.eliminated[1]).to.equal(2)
		expect(snapshot.team.scrap).to.equal(40)
		expect(snapshot.targets.scrap).to.equal(300)
		expect(snapshot.scores["1"].kills).to.equal(2)
		expect(snapshot.containers.team[1].quantity).to.equal(2)
		expect(snapshot.containers.team[2].uid).to.equal("r3-1")
		expect(snapshot.containers.team[2].attrs.durability).to.equal(5)
	end)

	it("defaults the optional maps and lists when absent", function()
		local snapshot = RoundSnapshotUtils.decode({ phase = "lobby", round = 0 })
		expect(snapshot).to.be.ok()
		expect(snapshot.endsAt).to.equal(nil)
		expect(snapshot.outcome).to.equal(nil)
		expect(#snapshot.participants).to.equal(0)
		expect(next(snapshot.team)).to.equal(nil)
		expect(next(snapshot.containers)).to.equal(nil)
	end)

	it("keeps the outcome", function()
		local snapshot = RoundSnapshotUtils.decode({ phase = "results", round = 1, outcome = "quota" })
		expect(snapshot.outcome).to.equal("quota")
	end)

	it("rejects a non-table, an unknown phase or a missing round", function()
		expect(RoundSnapshotUtils.decode(nil)).to.equal(nil)
		expect(RoundSnapshotUtils.decode("running")).to.equal(nil)
		expect(RoundSnapshotUtils.decode({ phase = "intermission", round = 1 })).to.equal(nil)
		expect(RoundSnapshotUtils.decode({ phase = "lobby" })).to.equal(nil)
	end)

	it("rejects malformed fields instead of passing them through", function()
		local bad = full()
		bad.participants = { 1, "two" }
		expect(RoundSnapshotUtils.decode(bad)).to.equal(nil)

		bad = full()
		bad.team = { scrap = "lots" }
		expect(RoundSnapshotUtils.decode(bad)).to.equal(nil)

		bad = full()
		bad.containers = { team = { { itemType = "flare" } } }
		expect(RoundSnapshotUtils.decode(bad)).to.equal(nil)
	end)
end
