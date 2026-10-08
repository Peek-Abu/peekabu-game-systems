local ServerScriptService = game:GetService("ServerScriptService")
local ReplicationSlotTracker = require(ServerScriptService.Features.Replication.State.ReplicationSlotTracker)

return function()
	describe("slots", function()
		it("claims the lowest free slot, starting at 1", function()
			local slots = ReplicationSlotTracker.new()
			expect(ReplicationSlotTracker.claim(slots)).to.equal(1)
			expect(ReplicationSlotTracker.claim(slots)).to.equal(2)
			ReplicationSlotTracker.release(slots, 1)
			expect(ReplicationSlotTracker.claim(slots)).to.equal(1)
			expect(ReplicationSlotTracker.count(slots)).to.equal(2)
		end)

		it("returns nil when all 127 slots are taken", function()
			local slots = ReplicationSlotTracker.new()
			for _ = 1, ReplicationSlotTracker.MAX_SLOT do
				expect(ReplicationSlotTracker.claim(slots)).to.be.ok()
			end
			expect(ReplicationSlotTracker.claim(slots)).to.equal(nil)
		end)

		it("release bumps the slot generation, so a reused slot is a new identity", function()
			local slots = ReplicationSlotTracker.new()
			local slot = ReplicationSlotTracker.claim(slots)
			expect(ReplicationSlotTracker.generationOf(slots, slot)).to.equal(0)
			ReplicationSlotTracker.release(slots, slot)
			expect(ReplicationSlotTracker.claim(slots)).to.equal(slot)
			expect(ReplicationSlotTracker.generationOf(slots, slot)).to.equal(1)
		end)

		it("wraps the generation at 4 (2 bits on the wire)", function()
			local slots = ReplicationSlotTracker.new()
			for _ = 1, 4 do
				ReplicationSlotTracker.claim(slots)
				ReplicationSlotTracker.release(slots, 1)
			end
			expect(ReplicationSlotTracker.generationOf(slots, 1)).to.equal(0)
		end)

		it("ignores releasing a slot that is not in use", function()
			local slots = ReplicationSlotTracker.new()
			ReplicationSlotTracker.release(slots, 5)
			expect(ReplicationSlotTracker.generationOf(slots, 5)).to.equal(0)
		end)
	end)

	describe("epochs", function()
		it("bumps from 0 and keeps bumps at least 250 ms apart", function()
			local epoch = ReplicationSlotTracker.newEpoch()
			expect(ReplicationSlotTracker.bumpEpoch(epoch, 1000)).to.equal(true)
			expect(epoch.value).to.equal(1)
			expect(ReplicationSlotTracker.bumpEpoch(epoch, 1200)).to.equal(false)
			expect(epoch.value).to.equal(1)
			expect(ReplicationSlotTracker.bumpEpoch(epoch, 1250)).to.equal(true)
			expect(epoch.value).to.equal(2)
		end)

		it("wraps the full epoch at 256", function()
			local epoch = ReplicationSlotTracker.newEpoch()
			epoch.value = 255
			ReplicationSlotTracker.bumpEpoch(epoch, 0)
			expect(epoch.value).to.equal(0)
		end)
	end)
end
