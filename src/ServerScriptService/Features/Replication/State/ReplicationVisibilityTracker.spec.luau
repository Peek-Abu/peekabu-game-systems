local ServerScriptService = game:GetService("ServerScriptService")
local ReplicationVisibilityTracker =
	require(ServerScriptService.Features.Replication.State.ReplicationVisibilityTracker)

local VIEWER = Vector3.new(-1228, 10, -363)

local function at(distance)
	return VIEWER + Vector3.new(distance, 0, 0)
end

return function()
	it("enters within 600 studs", function()
		local set = ReplicationVisibilityTracker.new()
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, at(700))).to.equal(nil)
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, at(600))).to.equal("entered")
		expect(ReplicationVisibilityTracker.has(set, 3)).to.equal(true)
		expect(set.count).to.equal(1)
	end)

	it("holds membership between 600 and 630 studs", function()
		local set = ReplicationVisibilityTracker.new()
		ReplicationVisibilityTracker.update(set, VIEWER, 3, at(100))
		for _, distance in { 610, 630, 605, 629, 601 } do
			expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, at(distance))).to.equal(nil)
		end
		expect(ReplicationVisibilityTracker.has(set, 3)).to.equal(true)
	end)

	it("leaves past 630 studs and does not re-enter until back within 600", function()
		local set = ReplicationVisibilityTracker.new()
		ReplicationVisibilityTracker.update(set, VIEWER, 3, at(100))
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, at(631))).to.equal("left")
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, at(615))).to.equal(nil)
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, at(599))).to.equal("entered")
	end)

	it("ignores a NaN position instead of churning", function()
		local set = ReplicationVisibilityTracker.new()
		local nan = Vector3.new(0 / 0, 0, 0)
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 3, nan)).to.equal(nil)
		ReplicationVisibilityTracker.update(set, VIEWER, 4, at(10))
		expect(ReplicationVisibilityTracker.update(set, VIEWER, 4, nan)).to.equal(nil)
		expect(ReplicationVisibilityTracker.has(set, 4)).to.equal(true)
	end)

	it("remove reports whether the slot was a member", function()
		local set = ReplicationVisibilityTracker.new()
		ReplicationVisibilityTracker.update(set, VIEWER, 3, at(10))
		expect(ReplicationVisibilityTracker.remove(set, 3)).to.equal(true)
		expect(ReplicationVisibilityTracker.remove(set, 3)).to.equal(false)
		expect(set.count).to.equal(0)
	end)
end
