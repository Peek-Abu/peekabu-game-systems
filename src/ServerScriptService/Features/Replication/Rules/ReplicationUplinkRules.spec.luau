local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Uplink = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationUplinkCodec)
local ReplicationUplinkRules = require(ServerScriptService.Features.Replication.Rules.ReplicationUplinkRules)

local function sample(sampleMs, x, overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200 + x, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return { record = r, sampleMs = sampleMs }
end

-- Encode then decode, exactly as the wire does, and ingest at `nowMs` (default: 30 ms after sending).
local function ingest(state, sentMs, samples, nowMs)
	local b = Uplink.encode(sentMs, samples)
	local ok, reason, uplink = Uplink.decode(b)
	assert(ok, reason)
	return ReplicationUplinkRules.ingest(state, b, uplink, nowMs or sentMs + 30)
end

local function fresh(epoch)
	local state = ReplicationUplinkRules.new()
	ReplicationUplinkRules.reset(state, epoch or 1)
	return state
end

return function()
	it("accepts a new sample and marks the body fresh", function()
		local state = fresh()
		expect(ingest(state, 1000, { sample(1000, 0) })).to.equal(1)
		expect(state.fresh).to.equal(true)
		expect(state.latestMs).to.equal(1000)
		expect(state.latest.position.X).to.be.near(-1200, 0.02)
	end)

	it("takes redundant samples oldest first and counts the repeats as duplicates", function()
		local state = fresh()
		local s1, s2, s3 = sample(1000, 0), sample(1017, 0.3), sample(1034, 0.6)
		ingest(state, 1017, { s2, s1 })
		expect(ingest(state, 1034, { s3, s2, s1 })).to.equal(1)
		expect(state.counters.accepted).to.equal(3)
		expect(state.counters.duplicate).to.equal(2)
		expect(state.latestMs).to.equal(1034)
	end)

	it("counts a sample whose content changed as a mismatched duplicate and keeps the first version", function()
		local state = fresh()
		ingest(state, 1000, { sample(1000, 0) })
		ingest(state, 1017, { sample(1017, 0.3), sample(1000, 5) }) -- "the 1000 ms sample", now 5 studs away
		expect(state.counters.mismatched).to.equal(1)
		expect(state.counters.accepted).to.equal(2)
	end)

	it("drops samples from another body epoch", function()
		local state = fresh(2)
		expect(ingest(state, 1000, { sample(1000, 0, { epoch = 1 }) })).to.equal(0)
		expect(state.counters.wrongEpoch).to.equal(1)
	end)

	it("matches the epoch on its low three bits", function()
		local state = fresh(9) -- 9 % 8 == 1
		expect(ingest(state, 1000, { sample(1000, 0, { epoch = 1 }) })).to.equal(1)
	end)

	it("drops a sample more than 64 ms ahead of server time", function()
		local state = fresh()
		expect(ingest(state, 1100, { sample(1100, 0) }, 1000)).to.equal(0)
		expect(state.counters.ahead).to.equal(1)
		expect(ingest(state, 1060, { sample(1060, 0) }, 1000)).to.equal(1)
	end)

	it("accepts a backlog sample up to 1000 ms old and drops older ones as stale", function()
		local state = fresh()
		expect(ingest(state, 4000, { sample(4000, 0) }, 4900)).to.equal(1)
		expect(ingest(state, 4100, { sample(4100, 0) }, 5200)).to.equal(0) -- 1100 ms old
		expect(state.counters.stale).to.equal(1)
	end)

	it("never reads an old sample as a future one", function()
		local state = fresh()
		-- Taken at 9000, carried in a packet sent at 10000 that arrives at 10020: stale, never "ahead".
		expect(ingest(state, 10000, { sample(10000, 1), sample(9000, 0) }, 10020)).to.equal(1)
		expect(state.counters.ahead).to.equal(0)
		expect(state.counters.stale).to.equal(1)
		expect(state.latestMs).to.equal(10000)
	end)

	it("drops a sample closer than 15 ms to the newest", function()
		local state = fresh()
		ingest(state, 1000, { sample(1000, 0) })
		expect(ingest(state, 1010, { sample(1010, 0.2) })).to.equal(0)
		expect(state.counters.tooFast).to.equal(1)
	end)

	it("counts an older sample outside the duplicate window as stale", function()
		local state = fresh()
		for i = 0, 5 do
			ingest(state, 1000 + i * 17, { sample(1000 + i * 17, i * 0.3) })
		end
		-- The 1000 ms sample has left the last-4 window.
		expect(ingest(state, 1200, { sample(1200, 3), sample(1000, 0) })).to.equal(1)
		expect(state.counters.stale).to.equal(1)
	end)

	it("reset starts a new body: new epoch, empty window, counters kept", function()
		local state = fresh(1)
		ingest(state, 1000, { sample(1000, 0) })
		ReplicationUplinkRules.reset(state, 2)
		expect(state.latest).to.equal(nil)
		expect(state.fresh).to.equal(false)
		expect(state.counters.accepted).to.equal(1)
		expect(ingest(state, 990, { sample(990, 0, { epoch = 2 }) }, 1020)).to.equal(1)
	end)

	it("clockSeconds is the send time, clamped to server time + 64 ms", function()
		expect(ReplicationUplinkRules.clockSeconds(5000, 6000)).to.be.near(5, 1e-9)
		expect(ReplicationUplinkRules.clockSeconds(9000, 6000)).to.be.near(6.064, 1e-9)
	end)

	it("bounds a hostile send time: a tiny one is stale, a huge one is ahead", function()
		local state = fresh()
		-- sampleMs = 0 - 0, taken "long ago" relative to server time 5000.
		expect(ingest(state, 0, { sample(0, 0) }, 5000)).to.equal(0)
		expect(state.counters.stale).to.equal(1)
		-- sentMs near the u32 maximum: far past server time.
		expect(ingest(state, 4000000000, { sample(4000000000, 0) }, 5000)).to.equal(0)
		expect(state.counters.ahead).to.equal(1)
		expect(state.latest).to.equal(nil)
	end)

	it("tracks the age at acceptance of the newest accepted sample and the max over the last 120", function()
		local state = fresh()
		expect(state.counters.lastAcceptedAgeMs).to.equal(0)
		expect(ReplicationUplinkRules.maxAcceptedAgeMs(state)).to.equal(0)
		expect(ingest(state, 1000, { sample(1000, 0) }, 1040)).to.equal(1)
		expect(state.counters.lastAcceptedAgeMs).to.equal(40)
		expect(ReplicationUplinkRules.maxAcceptedAgeMs(state)).to.equal(40)
		expect(ingest(state, 1100, { sample(1100, 1) }, 1110)).to.equal(1)
		expect(state.counters.lastAcceptedAgeMs).to.equal(10)
		expect(ReplicationUplinkRules.maxAcceptedAgeMs(state)).to.equal(40)
		-- 120 further samples push the 40 ms one out of the ring.
		for i = 1, 120 do
			local ms = 1100 + i * 20
			ingest(state, ms, { sample(ms, 2) }, ms + 5)
		end
		expect(state.counters.lastAcceptedAgeMs).to.equal(5)
		expect(ReplicationUplinkRules.maxAcceptedAgeMs(state)).to.equal(5)
	end)
end
