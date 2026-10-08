local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationStateTimingUtils =
	require(ReplicatedStorage.Shared.Features.Replication.Utils.ReplicationStateTimingUtils)

return function()
	local MAX = ReplicationStateTimingUtils.MAX_OPEN_STATE_MS

	it("keeps the safety cap at 30 s", function()
		expect(MAX).to.equal(30000)
	end)

	it("ends a timed state at start + duration", function()
		expect(ReplicationStateTimingUtils.endMs(1000, 250)).to.equal(1250)
		expect(ReplicationStateTimingUtils.isOver(1000, 250, 1249)).to.equal(false)
		expect(ReplicationStateTimingUtils.isOver(1000, 250, 1250)).to.equal(true)
	end)

	it("ends an open-ended state at the safety cap", function()
		expect(ReplicationStateTimingUtils.endMs(1000, nil)).to.equal(1000 + MAX)
		expect(ReplicationStateTimingUtils.isOver(1000, nil, 1000 + MAX - 1)).to.equal(false)
		expect(ReplicationStateTimingUtils.isOver(1000, nil, 1000 + MAX)).to.equal(true)
	end)
end
