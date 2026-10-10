local QueueSnapshotUtils = require(script.Parent.QueueSnapshotUtils)

local function pad(overrides)
	local value = { members = { 7, 8 }, capacity = 4, destination = "away", endsAt = 120, departing = false }
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

return function()
	it("decodes pads", function()
		local snapshot = QueueSnapshotUtils.decode({ pads = { pad1 = pad() } })
		local decoded = snapshot.pads.pad1
		expect(decoded.members[2]).to.equal(8)
		expect(decoded.capacity).to.equal(4)
		expect(decoded.destination).to.equal("away")
		expect(decoded.endsAt).to.equal(120)
		expect(decoded.departing).to.equal(false)
	end)

	it("decodes absent pads, absent members and an absent countdown", function()
		expect(next(QueueSnapshotUtils.decode({}).pads)).to.equal(nil)
		local snapshot = QueueSnapshotUtils.decode({
			pads = { pad1 = { capacity = 4, destination = "away", departing = true } },
		})
		expect(#snapshot.pads.pad1.members).to.equal(0)
		expect(snapshot.pads.pad1.endsAt).to.equal(nil)
	end)

	it("rejects a malformed entry", function()
		expect(QueueSnapshotUtils.decode(nil)).to.equal(nil)
		expect(QueueSnapshotUtils.decode("x")).to.equal(nil)
		expect(QueueSnapshotUtils.decode({ pads = 5 })).to.equal(nil)
		for _, bad in
			{
				{ capacity = "4" },
				{ members = { "7" } },
				{ departing = "no" },
				{ endsAt = "soon" },
				{ destination = 3 },
			}
		do
			expect(QueueSnapshotUtils.decode({ pads = { pad1 = pad(bad) } })).to.equal(nil)
		end
	end)

	it("finds the pad a player is aboard", function()
		local snapshot = QueueSnapshotUtils.decode({ pads = { pad1 = pad() } })
		local padId, found = QueueSnapshotUtils.padOf(snapshot, 8)
		expect(padId).to.equal("pad1")
		expect(found.capacity).to.equal(4)
		expect(QueueSnapshotUtils.padOf(snapshot, 9)).to.equal(nil)
		expect(QueueSnapshotUtils.padOf(nil, 8)).to.equal(nil)
	end)
end
