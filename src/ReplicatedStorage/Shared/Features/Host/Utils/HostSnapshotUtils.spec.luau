local HostSnapshotUtils = require(script.Parent.HostSnapshotUtils)

return function()
	it("decodes trucks with their host and lock", function()
		local snapshot = HostSnapshotUtils.decode({ trucks = { pad1 = { host = 7, locked = true } } })
		expect(snapshot.trucks.pad1.host).to.equal(7)
		expect(snapshot.trucks.pad1.locked).to.equal(true)
	end)

	it("decodes an absent lock as off and absent trucks as none", function()
		expect(HostSnapshotUtils.decode({ trucks = { pad1 = { host = 7 } } }).trucks.pad1.locked).to.equal(false)
		expect(next(HostSnapshotUtils.decode({}).trucks)).to.equal(nil)
	end)

	it("rejects a malformed entry", function()
		expect(HostSnapshotUtils.decode(nil)).to.equal(nil)
		expect(HostSnapshotUtils.decode({ trucks = 5 })).to.equal(nil)
		expect(HostSnapshotUtils.decode({ trucks = { pad1 = { host = "7" } } })).to.equal(nil)
		expect(HostSnapshotUtils.decode({ trucks = { pad1 = { host = 7, locked = "no" } } })).to.equal(nil)
	end)

	it("finds a truck's host", function()
		local snapshot = HostSnapshotUtils.decode({ trucks = { pad1 = { host = 7 } } })
		expect(HostSnapshotUtils.hostOf(snapshot, "pad1")).to.equal(7)
		expect(HostSnapshotUtils.hostOf(snapshot, "pad2")).to.equal(nil)
		expect(HostSnapshotUtils.hostOf(nil, "pad1")).to.equal(nil)
	end)
end
