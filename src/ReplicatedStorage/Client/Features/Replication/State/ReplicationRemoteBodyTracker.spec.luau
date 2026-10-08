local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local ReplicationRemoteBodyTracker =
	require(ReplicatedStorage.Client.Features.Replication.State.ReplicationRemoteBodyTracker)

local LOCAL_USER = 1
local OTHER = 2

local function record(overrides)
	local r = {
		slot = 5,
		generation = 1,
		epoch = 2,
		ageMs = 0,
		position = Vector3.new(-1228, 10, -363),
		yaw = 0.5,
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
	return r
end

local function recordBytes(overrides)
	local b = buffer.create(Codec.RECORD_BYTES)
	Codec.writeRecord(b, 0, record(overrides))
	return b
end

local function batch(seq, batchTimeMs, list)
	local b = buffer.create(Codec.HEADER_BYTES + #list * Codec.RECORD_BYTES)
	Codec.writeHeader(b, 0, { seq = seq, batchTimeMs = batchTimeMs, count = #list })
	for i, overrides in list do
		Codec.writeRecord(b, Codec.HEADER_BYTES + (i - 1) * Codec.RECORD_BYTES, record(overrides))
	end
	return b
end

local function entry(overrides)
	local e = { slot = 5, userId = OTHER, generation = 1, epoch = 2, active = true }
	for key, value in overrides or {} do
		e[key] = value
	end
	return e
end

-- A state with slot 5 known and visible (its Enter sample at `enterMs`).
local function visibleState(enterMs)
	local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
	ReplicationRemoteBodyTracker.applySlot(state, entry())
	ReplicationRemoteBodyTracker.enter(state, 5, 1, enterMs or 1000, recordBytes())
	return state
end

return function()
	describe("slot table", function()
		it("adds a body for another player and ignores this client's own slot", function()
			local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
			expect(ReplicationRemoteBodyTracker.applySlot(state, entry())).to.equal("added")
			expect(ReplicationRemoteBodyTracker.applySlot(state, entry({ slot = 6, userId = LOCAL_USER }))).to.equal(
				nil
			)
			expect(state.bodies[6]).to.equal(nil)
			expect(state.bodies[5].visible).to.equal(false)
		end)

		it("a new generation on a slot replaces the body (a rejoiner inherits nothing)", function()
			local state = visibleState()
			local change, old = ReplicationRemoteBodyTracker.applySlot(state, entry({ generation = 2, userId = 3 }))
			expect(change).to.equal("replaced")
			expect(old.userId).to.equal(OTHER)
			expect(state.bodies[5].userId).to.equal(3)
			expect(state.bodies[5].visible).to.equal(false)
			expect(#state.bodies[5].samples.samples).to.equal(0)
		end)

		it("releases only the matching generation", function()
			local state = visibleState()
			expect(ReplicationRemoteBodyTracker.applySlot(state, entry({ generation = 0, active = false }))).to.equal(
				nil
			)
			expect(state.bodies[5]).to.be.ok()
			local change, old = ReplicationRemoteBodyTracker.applySlot(state, entry({ active = false }))
			expect(change).to.equal("released")
			expect(old.slot).to.equal(5)
			expect(state.bodies[5]).to.equal(nil)
		end)

		it("the slot table resets a buffer that missed an epoch bump", function()
			local state = visibleState(1000)
			-- Epoch 3's records were all lost; epoch 4's are dropped (not current + 1)...
			ReplicationRemoteBodyTracker.onBatch(state, batch(1, 1100, { { epoch = 4 } }), 1120, 0)
			expect(state.stats.dropped).to.equal(1)
			-- ...until the reliable slot table says epoch 4.
			expect(ReplicationRemoteBodyTracker.applySlot(state, entry({ epoch = 4 }))).to.equal("epoch")
			expect(state.stats.resets).to.equal(1)
			ReplicationRemoteBodyTracker.onBatch(state, batch(2, 1200, { { epoch = 4 } }), 1220, 0)
			expect(#state.bodies[5].samples.samples).to.equal(1)
		end)

		it("does not reset a buffer that already flushed to the announced epoch", function()
			local state = visibleState(1000)
			ReplicationRemoteBodyTracker.onBatch(state, batch(1, 1100, { { epoch = 3 } }), 1120, 0) -- current + 1: flushes
			ReplicationRemoteBodyTracker.applySlot(state, entry({ epoch = 3 }))
			expect(state.stats.resets).to.equal(0)
			expect(#state.bodies[5].samples.samples).to.equal(1)
		end)
	end)

	describe("enter and leave", function()
		it("enter shows the body with a fresh buffer holding the full-state sample", function()
			local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
			ReplicationRemoteBodyTracker.applySlot(state, entry())
			local body = ReplicationRemoteBodyTracker.enter(state, 5, 1, 1000, recordBytes({ ageMs = 30 }))
			expect(body.visible).to.equal(true)
			expect(#body.samples.samples).to.equal(1)
			expect(body.samples.samples[1].timeMs).to.equal(970)
		end)

		it("ignores an enter for an unknown slot or another generation", function()
			local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
			ReplicationRemoteBodyTracker.applySlot(state, entry())
			expect(ReplicationRemoteBodyTracker.enter(state, 7, 1, 1000, recordBytes())).to.equal(nil)
			expect(ReplicationRemoteBodyTracker.enter(state, 5, 2, 1000, recordBytes())).to.equal(nil)
		end)

		it("leave hides the body and forgets its samples", function()
			local state = visibleState()
			local body = ReplicationRemoteBodyTracker.leave(state, 5, 1)
			expect(body.visible).to.equal(false)
			expect(#body.samples.samples).to.equal(0)
		end)

		it("counts every enter and leave by outcome", function()
			local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
			ReplicationRemoteBodyTracker.applySlot(state, entry())
			ReplicationRemoteBodyTracker.enter(state, 7, 1, 1000, recordBytes())
			ReplicationRemoteBodyTracker.enter(state, 5, 2, 1000, recordBytes())
			ReplicationRemoteBodyTracker.enter(state, 5, 1, 1000, buffer.create(3))
			ReplicationRemoteBodyTracker.enter(state, 5, 1, 1000, recordBytes())
			ReplicationRemoteBodyTracker.leave(state, 7, 1)
			ReplicationRemoteBodyTracker.leave(state, 5, 1)
			local stats = state.stats
			expect(stats.enterAccepted).to.equal(1)
			expect(stats.enterNoBody).to.equal(1)
			expect(stats.enterGeneration).to.equal(1)
			expect(stats.enterBadRecord).to.equal(1)
			expect(stats.leaveAccepted).to.equal(1)
			expect(stats.leaveIgnored).to.equal(1)
		end)

		it("counts an enter whose sample the buffer drops (a stale slot-table epoch)", function()
			local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
			ReplicationRemoteBodyTracker.applySlot(state, entry({ epoch = 2 }))
			-- The record is two epochs ahead of the table: the buffer only accepts current or current + 1.
			ReplicationRemoteBodyTracker.enter(state, 5, 1, 1000, recordBytes({ epoch = 4 }))
			expect(state.stats.enterAccepted).to.equal(1)
			expect(state.stats.enterSampleDropped).to.equal(1)
		end)
	end)

	describe("describe", function()
		it("summarises each known body for the debugger", function()
			local state = visibleState(1000)
			ReplicationRemoteBodyTracker.applySlot(state, entry({ slot = 6, userId = 3, generation = 0, epoch = 7 }))
			local rows = ReplicationRemoteBodyTracker.describe(state)
			expect(rows["5"]).to.equal("user 2 · gen 1 · epoch 2 (buffer 2) · visible · 1 samples")
			expect(rows["6"]).to.equal("user 3 · gen 0 · epoch 7 (buffer 7) · hidden · 0 samples")
		end)
	end)

	describe("batches", function()
		it("rejects a malformed batch and counts it", function()
			local state = visibleState()
			local b = batch(1, 1100, { {} })
			buffer.writeu8(b, 6, 2) -- claims two records, holds one
			expect(ReplicationRemoteBodyTracker.onBatch(state, b, 1120, 0)).to.equal(false)
			expect(state.stats.rejected).to.equal(1)
		end)

		it("drops records for unknown slots, hidden bodies and other generations", function()
			local state = visibleState()
			ReplicationRemoteBodyTracker.onBatch(state, batch(1, 1100, { { slot = 9 }, { generation = 2 } }), 1120, 0)
			ReplicationRemoteBodyTracker.leave(state, 5, 1)
			ReplicationRemoteBodyTracker.onBatch(state, batch(2, 1200, { {} }), 1220, 0)
			expect(state.stats.dropped).to.equal(3)
		end)

		it("lets only new samples vote on lateness", function()
			local state = visibleState(1000)
			ReplicationRemoteBodyTracker.onBatch(state, batch(1, 1100, { {} }), 1150, 0) -- new: lateness 50
			ReplicationRemoteBodyTracker.onBatch(state, batch(2, 1100, { {} }), 1300, 0) -- a resend of the same sample
			expect(state.stats.newSamples).to.equal(1)
			expect(#state.clock.lateness).to.equal(1)
			expect(state.clock.lateness[1]).to.equal(50)
		end)

		it("a restamped repair is a new sample with transit-only lateness", function()
			local state = visibleState(1000)
			-- A still body: the server restamps each repair to its batch time (age 0, zero velocity).
			ReplicationRemoteBodyTracker.onBatch(state, batch(1, 3000, { { velocity = Vector3.zero } }), 3040, 0)
			ReplicationRemoteBodyTracker.onBatch(state, batch(2, 4000, { { velocity = Vector3.zero } }), 4040, 0)
			expect(state.stats.newSamples).to.equal(2)
			expect(state.clock.lateness[1]).to.equal(40)
			expect(state.clock.lateness[2]).to.equal(40)
		end)
	end)

	describe("frame", function()
		it("places visible bodies at the interpolated pose, facing their yaw", function()
			local state = visibleState(1000)
			ReplicationRemoteBodyTracker.onBatch(
				state,
				batch(1, 1017, { { position = Vector3.new(-1227.73, 10, -363) } }),
				1030,
				0
			)
			state.clock.delayMs = 10 -- white-box: pin the delay (render time 1008.5, between the two samples)
			state.clock.targetMs = 10
			local slots, cframes = {}, {}
			local count = ReplicationRemoteBodyTracker.frame(state, 1018.5, slots, cframes, nil)
			expect(count).to.equal(1)
			expect(slots[1]).to.equal(5)
			expect(cframes[1].Position.X > -1228 and cframes[1].Position.X < -1227.7).to.equal(true)
			local look = cframes[1].LookVector
			expect(math.atan2(-look.X, -look.Z)).to.be.near(0.5, 0.03)
		end)

		it("leaves each placed body's movement state at render time, for puppet locomotion", function()
			local state = visibleState(1000)
			local airborne = { state = 5, grounded = false, velocity = Vector3.new(16, -10, 0) }
			ReplicationRemoteBodyTracker.onBatch(state, batch(1, 1017, { airborne }), 1030, 0)
			state.clock.delayMs = 0 -- white-box: render time = now
			state.clock.targetMs = 0
			ReplicationRemoteBodyTracker.frame(state, 1016, {}, {}, nil)
			local body = state.bodies[5]
			expect(body.motionState).to.equal(5)
			expect(body.motionGrounded).to.equal(false)
			expect(body.motionVelocity.Y < 0).to.equal(true)
		end)

		it("skips hidden and empty bodies", function()
			local state = ReplicationRemoteBodyTracker.new(LOCAL_USER)
			ReplicationRemoteBodyTracker.applySlot(state, entry())
			local slots, cframes = {}, {}
			expect(ReplicationRemoteBodyTracker.frame(state, 1000, slots, cframes, nil)).to.equal(0)
		end)

		it("places nothing for a body whose buffer a respawn epoch just reset", function()
			local state = visibleState(1000)
			local slots, cframes = {}, {}
			state.clock.delayMs = 0
			state.clock.targetMs = 0
			expect(ReplicationRemoteBodyTracker.frame(state, 1010, slots, cframes, nil)).to.equal(1)
			expect(ReplicationRemoteBodyTracker.applySlot(state, entry({ epoch = 3 }))).to.equal("epoch")
			-- Still visible, but with no sample of the new epoch: the shell hides its puppet.
			expect(state.bodies[5].visible).to.equal(true)
			expect(ReplicationRemoteBodyTracker.frame(state, 1020, slots, cframes, nil)).to.equal(0)
		end)

		it("is starving only in hold, never when behind", function()
			local state = visibleState(1000)
			local slots, cframes = {}, {}
			state.clock.delayMs = 500 -- render time 500 ms before the only sample: behind
			state.clock.targetMs = 500
			ReplicationRemoteBodyTracker.frame(state, 1000, slots, cframes, nil)
			expect(state.starving).to.equal(false)
			state.clock.delayMs = 0 -- 300 ms past the only sample: hold
			state.clock.targetMs = 0
			ReplicationRemoteBodyTracker.frame(state, 1300, slots, cframes, nil)
			expect(state.starving).to.equal(true)
		end)
	end)
end
