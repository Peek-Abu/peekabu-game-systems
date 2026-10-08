local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationRenderClockSystem =
	require(ReplicatedStorage.Shared.Features.Replication.Systems.ReplicationRenderClockSystem)

local FRAME = 1000 / 60

-- Drive a clock for `seconds` of 60 Hz frames with one batch per frame at `lateness` ms, seq +1 each frame
-- (or +`seqStep`). Returns the clock and the time reached.
local function drive(clock, fromMs, seconds, lateness, seqStep, startSeq)
	local now = fromMs
	local seq = startSeq or 0
	for _ = 1, math.floor(seconds * 60) do
		now += FRAME
		ReplicationRenderClockSystem.noteFrame(clock, now)
		seq = (seq + (seqStep or 1)) % 65536
		ReplicationRenderClockSystem.onBatch(clock, now, seq, lateness, true)
		ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
	end
	return clock, now, seq
end

local function target(lateness, lossLevel)
	return lateness + (lossLevel + 1) * FRAME + 4
end

return function()
	describe("steady network", function()
		it("starts at the initial delay", function()
			expect(ReplicationRenderClockSystem.new().delayMs).to.equal(100)
		end)

		it("jumps to a target more than 25 ms above", function()
			local clock = drive(ReplicationRenderClockSystem.new(), 0, 1, 150)
			expect(clock.delayMs).to.be.near(target(150, 0), 0.01)
		end)

		it("ignores target moves under the 6 ms hysteresis", function()
			local clock = drive(ReplicationRenderClockSystem.new(), 0, 1, 150)
			drive(clock, 1000, 1, 153)
			expect(clock.delayMs).to.be.near(target(150, 0), 0.01)
		end)

		-- The next three set the target directly (white-box) so the rate is measured exactly: `sinceRetargetMs = 0`
		-- keeps a retarget from replacing it during the advances.
		it("glides up at 60 ms/s toward a target less than 25 ms above", function()
			local clock, now = drive(ReplicationRenderClockSystem.new(), 0, 5, 150)
			local start = clock.delayMs
			clock.targetMs = start + 15
			clock.sinceRetargetMs = 0
			ReplicationRenderClockSystem.advance(clock, now + 100, false, math.huge)
			expect(clock.delayMs).to.be.near(start + 6, 1e-6)
			ReplicationRenderClockSystem.advance(clock, now + 200, false, math.huge)
			expect(clock.delayMs).to.be.near(start + 12, 1e-6)
		end)

		it("jumps when starving even for a small rise", function()
			local clock, now = drive(ReplicationRenderClockSystem.new(), 0, 5, 150)
			local start = clock.delayMs
			clock.targetMs = start + 15
			clock.sinceRetargetMs = 0
			ReplicationRenderClockSystem.advance(clock, now + 16, true, math.huge)
			expect(clock.delayMs).to.be.near(start + 15, 1e-6)
		end)

		it("falls at 15 ms/s", function()
			local clock, now = drive(ReplicationRenderClockSystem.new(), 0, 5, 300)
			local start = clock.delayMs
			clock.targetMs = start - 50
			for i = 1, 10 do
				clock.sinceRetargetMs = 0
				ReplicationRenderClockSystem.advance(clock, now + i * 100, false, math.huge)
			end
			expect(clock.delayMs).to.be.near(start - 15, 1e-6)
		end)

		it("never exceeds 600 ms", function()
			local clock = drive(ReplicationRenderClockSystem.new(), 0, 5, 950)
			expect(clock.delayMs).to.equal(600)
		end)

		it("holds the initial delay until lateness samples arrive", function()
			local clock = ReplicationRenderClockSystem.new()
			local now = 0
			for _ = 1, 60 do
				now += FRAME
				ReplicationRenderClockSystem.noteFrame(clock, now)
				ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
			end
			expect(clock.delayMs).to.equal(100)
		end)
	end)

	describe("loss", function()
		it("adds one interval at 1.5–6 % loss and two above 6 %", function()
			local clock = drive(ReplicationRenderClockSystem.new(), 0, 5, 150, 2) -- every other batch lost: 50 %
			expect(clock.lossLevel).to.equal(2)
			expect(clock.delayMs).to.be.near(target(150, 2), 0.01)
		end)

		it("counts a seq wrap as one step", function()
			local clock = drive(ReplicationRenderClockSystem.new(), 0, 5, 150, 1, 65536 - 100)
			expect(clock.lossLevel).to.equal(0)
		end)

		it("ignores a duplicate re-arrival instead of counting it as loss", function()
			local clock = ReplicationRenderClockSystem.new()
			local now = 0
			for seq = 1, 300 do
				now += FRAME
				ReplicationRenderClockSystem.noteFrame(clock, now)
				ReplicationRenderClockSystem.onBatch(clock, now, seq, 150, true)
				if seq % 10 == 0 then
					ReplicationRenderClockSystem.onBatch(clock, now, seq - 3, 150, false) -- a late duplicate
				end
				ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
			end
			expect(clock.lossLevel).to.equal(0)
		end)

		it("resyncs after a large forward seq jump", function()
			local clock, now, seq = drive(ReplicationRenderClockSystem.new(), 0, 5, 150, 1)
			drive(clock, now, 5, 150, 2, (seq + 5000) % 65536)
			expect(clock.lossLevel).to.equal(2)
		end)

		it("counts a reordered arrival like a loss (5, 7, 6, 8 is one step gap)", function()
			local clock = ReplicationRenderClockSystem.new()
			local now = 0
			local seq = 0
			for _ = 1, 150 do
				for _, offset in { 1, 3, 2, 4 } do
					now += FRAME
					ReplicationRenderClockSystem.noteFrame(clock, now)
					ReplicationRenderClockSystem.onBatch(clock, now, (seq + offset) % 65536, 150, true)
					ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
				end
				seq += 4
			end
			-- Per group of four arrivals only three forward steps (summing 4) are recorded: the late batch is
			-- not taken back, so reorder raises the level exactly as loss does (25 % here).
			expect(clock.lossLevel).to.equal(2)
		end)

		it("still counts a batch that never arrives", function()
			local clock = ReplicationRenderClockSystem.new()
			local now = 0
			for seq = 1, 600 do
				if seq % 10 ~= 0 then -- 10 % loss
					now += FRAME
					ReplicationRenderClockSystem.noteFrame(clock, now)
					ReplicationRenderClockSystem.onBatch(clock, now, seq, 150, true)
					ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
				end
			end
			expect(clock.lossLevel).to.equal(2)
		end)
	end)

	describe("lateness sampling", function()
		it("does not let resends and repairs (old samples) vote", function()
			local clock, now = drive(ReplicationRenderClockSystem.new(), 0, 3, 150)
			for i = 1, 200 do
				ReplicationRenderClockSystem.onBatch(clock, now, i + 5000, 900, false)
			end
			drive(clock, now, 1, 150, 1, 5200)
			expect(clock.delayMs).to.be.near(target(150, 0), 0.01)
		end)

		it("adapts on a steady 8 FPS client", function()
			local clock = ReplicationRenderClockSystem.new()
			local now = 0
			local seq = 0
			for _ = 1, 80 do -- 10 s of 125 ms frames
				now += 125
				ReplicationRenderClockSystem.noteFrame(clock, now)
				seq += 1
				ReplicationRenderClockSystem.onBatch(clock, now, seq, 150, true)
				ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
			end
			expect(clock.delayMs).to.be.near(150 + 1000 / 60 + 4, 0.01)
			expect(clock.skipped <= 3).to.equal(true)
		end)

		it("keeps batches processed right after a local stall out of the delay", function()
			local clock, now, seq = drive(ReplicationRenderClockSystem.new(), 0, 5, 80)
			local before = clock.delayMs
			-- The window was in the background for 1.6 s; the backlog is processed in the frame that ends it.
			now += 1600
			for i = 1, 96 do
				ReplicationRenderClockSystem.onBatch(clock, now, (seq + i) % 65536, 1600 - i * FRAME, true)
			end
			ReplicationRenderClockSystem.noteFrame(clock, now)
			for i = 97, 100 do
				ReplicationRenderClockSystem.onBatch(clock, now + 5, (seq + i) % 65536, 1500, true)
			end
			ReplicationRenderClockSystem.advance(clock, now, false, math.huge)
			drive(clock, now, 1, 80, 1, (seq + 100) % 65536)
			expect(clock.skipped >= 100).to.equal(true)
			expect(clock.delayMs).to.be.near(before, 0.01)
		end)
	end)

	describe("reach", function()
		it("never renders further back than the buffers reach", function()
			local clock, now = drive(ReplicationRenderClockSystem.new(), 0, 5, 300)
			ReplicationRenderClockSystem.noteFrame(clock, now + FRAME)
			local delay = ReplicationRenderClockSystem.advance(clock, now + FRAME, false, 200)
			expect(delay).to.equal(200)
		end)
	end)

	describe("stats", function()
		it("reports an empty clock with the base stall threshold", function()
			local stats = ReplicationRenderClockSystem.stats(ReplicationRenderClockSystem.new())
			expect(stats.latenessCount).to.equal(0)
			expect(stats.latenessP50Ms).to.equal(0)
			expect(stats.latenessP95Ms).to.equal(0)
			expect(stats.latenessMaxMs).to.equal(0)
			expect(stats.frameGapMedianMs).to.equal(0)
			expect(stats.stallThresholdMs).to.equal(100)
			expect(stats.targetMs).to.equal(100)
			expect(stats.skipped).to.equal(0)
		end)

		it("computes percentiles, max and the stall threshold from known inputs", function()
			local clock = ReplicationRenderClockSystem.new()
			for i = 1, 100 do
				clock.lateness[i] = i
			end
			for i = 1, 5 do
				clock.frameGaps[i] = 50
			end
			clock.skipped = 7
			clock.targetMs = 321
			local stats = ReplicationRenderClockSystem.stats(clock)
			expect(stats.latenessCount).to.equal(100)
			expect(stats.latenessP50Ms).to.equal(50)
			expect(stats.latenessP95Ms).to.equal(95)
			expect(stats.latenessMaxMs).to.equal(100)
			expect(stats.frameGapMedianMs).to.equal(50)
			expect(stats.stallThresholdMs).to.equal(200) -- 4 x median 50 beats the 100 ms floor
			expect(stats.targetMs).to.equal(321)
			expect(stats.skipped).to.equal(7)
		end)
	end)
end
