local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueuePadTracker = require(script.Parent.QueuePadTracker)
local QueueSnapshotUtils = require(ReplicatedStorage.Shared.Features.Queue.Utils.QueueSnapshotUtils)

local CONFIG = { capacity = 2, countdown = 15, destination = "away" }

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

return function()
	local tracker

	beforeEach(function()
		tracker = QueuePadTracker.new()
		tracker:add("pad1", CONFIG)
		tracker:add("pad2", CONFIG)
	end)

	it("refuses to track one pad twice", function()
		expect(function()
			tracker:add("pad1", CONFIG)
		end).to.throw()
	end)

	it("boards players and starts the countdown", function()
		expect(tracker:sync("pad1", { 7 }, 100)).to.equal(true)
		expect(same(tracker:members("pad1"), { 7 })).to.equal(true)
		expect(tracker:padOf(7)).to.equal("pad1")
		expect(#tracker:due(114)).to.equal(0)
		expect(tracker:due(115)[1]).to.equal("pad1")
	end)

	it("reports no change when nothing moved", function()
		tracker:sync("pad1", { 7 }, 100)
		expect(tracker:sync("pad1", { 7 }, 101)).to.equal(false)
	end)

	it("resets the countdown when someone joins and keeps it when someone leaves", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:sync("pad1", { 7, 8 }, 105) -- ends at 120
		tracker:sync("pad1", { 8 }, 110) -- still 120
		expect(#tracker:due(119)).to.equal(0)
		expect(tracker:due(120)[1]).to.equal("pad1")
	end)

	it("stops the countdown when the pad empties", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:sync("pad1", {}, 101)
		expect(#tracker:due(1000)).to.equal(0)
		expect(tracker:padOf(7)).to.equal(nil)
	end)

	it("fills to capacity in join order", function()
		tracker:sync("pad1", { 7, 8, 9 }, 100)
		expect(same(tracker:members("pad1"), { 7, 8 })).to.equal(true)
		expect(tracker:padOf(9)).to.equal(nil)
	end)

	it("keeps a player on the first pad that claimed them", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:sync("pad2", { 7, 8 }, 100)
		expect(same(tracker:members("pad2"), { 8 })).to.equal(true)
		expect(tracker:padOf(7)).to.equal("pad1")
	end)

	it("lets a member depart now, but nobody else", function()
		tracker:sync("pad1", { 7 }, 100)
		expect(tracker:departNow(9, 101)).to.equal(nil)
		expect(tracker:departNow(7, 101)).to.equal("pad1")
		expect(tracker:due(101)[1]).to.equal("pad1")
	end)

	it("freezes a departing party and reopens the pad empty", function()
		tracker:sync("pad1", { 7, 8 }, 100)
		expect(same(tracker:lock("pad1"), { 7, 8 })).to.equal(true)
		expect(tracker:sync("pad1", { 9 }, 101)).to.equal(false)
		expect(tracker:departNow(7, 101)).to.equal(nil)
		expect(#tracker:due(1000)).to.equal(0)
		tracker:unlock("pad1")
		expect(#tracker:members("pad1")).to.equal(0)
		tracker:sync("pad1", { 7 }, 200)
		expect(tracker:due(215)[1]).to.equal("pad1")
	end)

	it("keeps a departed party off every pad until they step off the one they left", function()
		tracker:sync("pad1", { 7, 8 }, 100)
		tracker:lock("pad1")
		tracker:unlock("pad1", { 7, 8 })
		-- Still standing on the bed (a local move leaves them where they stand): not re-boarded, no countdown.
		expect(tracker:sync("pad1", { 7, 8 }, 101)).to.equal(false)
		expect(#tracker:members("pad1")).to.equal(0)
		expect(#tracker:due(1000)).to.equal(0)
		expect(tracker:departNow(7, 101)).to.equal(nil)
		-- Nor on a neighbouring pad while they have not stepped off theirs.
		tracker:sync("pad2", { 7 }, 101)
		expect(tracker:padOf(7)).to.equal(nil)
		-- Someone who did not depart boards as usual.
		tracker:sync("pad1", { 7, 8, 9 }, 102)
		expect(same(tracker:members("pad1"), { 9 })).to.equal(true)
		-- 7 steps off and back on: boards again; 8 never stepped off and stays held.
		tracker:sync("pad1", { 8, 9 }, 103)
		tracker:sync("pad1", { 7, 8, 9 }, 104)
		expect(same(tracker:members("pad1"), { 9, 7 })).to.equal(true)
		expect(tracker:padOf(8)).to.equal(nil)
	end)

	it("puts a party whose departure failed straight back on its pad", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:lock("pad1")
		tracker:unlock("pad1")
		tracker:sync("pad1", { 7 }, 101)
		expect(tracker:padOf(7)).to.equal("pad1")
	end)

	it("releases a held player who left the server", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:lock("pad1")
		tracker:unlock("pad1", { 7 })
		tracker:forget(7)
		tracker:sync("pad1", { 7 }, 101)
		expect(tracker:padOf(7)).to.equal("pad1")
	end)

	it("forgets a player who left the server", function()
		tracker:sync("pad1", { 7, 8 }, 100)
		expect(tracker:forget(7)).to.equal(true)
		expect(same(tracker:members("pad1"), { 8 })).to.equal(true)
		expect(tracker:forget(7)).to.equal(false)
		expect(tracker:due(115)[1]).to.equal("pad1") -- the rest keep their countdown
		tracker:forget(8)
		expect(#tracker:due(1000)).to.equal(0)
	end)

	it("publishes a snapshot clients can decode", function()
		tracker:sync("pad1", { 7 }, 100)
		tracker:lock("pad2")
		local snapshot = QueueSnapshotUtils.decode(tracker:snapshot())
		expect(snapshot.pads.pad1.members[1]).to.equal(7)
		expect(snapshot.pads.pad1.endsAt).to.equal(115)
		expect(snapshot.pads.pad1.capacity).to.equal(2)
		expect(snapshot.pads.pad1.destination).to.equal("away")
		expect(snapshot.pads.pad1.departing).to.equal(false)
		expect(snapshot.pads.pad2.departing).to.equal(true)
		expect(snapshot.pads.pad2.endsAt).to.equal(nil)
	end)

	it("drops a removed pad", function()
		tracker:sync("pad1", { 7 }, 100)
		expect(same(tracker:remove("pad1"), { 7 })).to.equal(true)
		expect(tracker:has("pad1")).to.equal(false)
		expect(tracker:padOf(7)).to.equal(nil)
		expect(tracker:config("pad1")).to.equal(nil)
	end)
end
