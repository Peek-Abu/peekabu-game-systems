local ShiftCrewStatusUtils = require(script.Parent.ShiftCrewStatusUtils)

local function status(extra)
	local value = { inTruck = false, vacuuming = false, room = "Archive", roomDepth = 2, cam = 7 }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function count(map)
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

return function()
	it("publishes only true flags and the room", function()
		local fields = ShiftCrewStatusUtils.fields(status())
		expect(fields.inTruck).to.equal(nil)
		expect(fields.vacuuming).to.equal(nil)
		expect(fields.room).to.equal("Archive")
		expect(fields.roomDepth).to.equal(2)
		expect(fields.cam).to.equal(7)
	end)

	it("sets everything on the first publish", function()
		local change = ShiftCrewStatusUtils.changes(nil, status({ vacuuming = true }))
		expect(change.set.vacuuming).to.equal(true)
		expect(change.set.room).to.equal("Archive")
		expect(#change.clear).to.equal(0)
	end)

	it("sends nothing when nothing changed", function()
		local change = ShiftCrewStatusUtils.changes(status(), status())
		expect(count(change.set)).to.equal(0)
		expect(#change.clear).to.equal(0)
	end)

	it("clears a flag that went false and sets only what moved", function()
		local change = ShiftCrewStatusUtils.changes(status({ vacuuming = true }), status({ inTruck = true }))
		expect(change.set.inTruck).to.equal(true)
		expect(change.set.room).to.equal(nil)
		expect(change.clear[1]).to.equal("vacuuming")
	end)

	it("clears the room when the player is outside every room", function()
		local change = ShiftCrewStatusUtils.changes(status(), status({ room = nil, roomDepth = nil, cam = nil }))
		table.sort(change.clear)
		expect(#change.clear).to.equal(3)
		expect(change.clear[1]).to.equal("cam")
	end)

	it("clears every field once the status is gone (dead, shift over)", function()
		local change = ShiftCrewStatusUtils.changes(status({ inTruck = true }), nil)
		expect(count(change.set)).to.equal(0)
		expect(#change.clear).to.equal(4)
	end)
end
