local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local ReplicationDownlinkSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationDownlinkSystem)

local FRAME_MS = 1000 / 60

local function record(overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200, 40, -350),
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
	return r
end

-- One encoded record per slot (all 20 ms old at `nowMs`), as the fan-out prepares them.
local function encoded(count, nowMs)
	local bytes, lengths = {}, {}
	for slot = 1, count do
		local b = buffer.create(ReplicationDownlinkSystem.SCRATCH_BYTES)
		local position = Vector3.new(-1228 + slot, 10, -363)
		lengths[slot] =
			ReplicationDownlinkSystem.encode(b, slot, 0, 1, record({ position = position }), nowMs - 20, nowMs)
		bytes[slot] = b
	end
	return bytes, lengths
end

local function range(first, last)
	local t = {}
	for i = first, last do
		table.insert(t, i)
	end
	return t
end

-- Distances parallel to `slots`: `distanceOf(slot)` studs from the viewer.
local function distancesFor(slots, distanceOf)
	local t = {}
	for i, slot in slots do
		t[i] = distanceOf(slot)
	end
	return t
end

local function constant(distance)
	return function()
		return distance
	end
end

local function slotsIn(batch)
	local out = {}
	if batch == nil then
		return out
	end
	local header = Codec.readHeader(batch, 0)
	for i = 1, header.count do
		table.insert(out, Codec.readRecord(batch, Codec.HEADER_BYTES + (i - 1) * Codec.RECORD_BYTES).slot)
	end
	return out
end

local function contains(list, value)
	return table.find(list, value) ~= nil
end

return function()
	describe("encode", function()
		it("writes slot, generation, the epoch's low bits and the age at batch time", function()
			local b = buffer.create(ReplicationDownlinkSystem.SCRATCH_BYTES)
			expect(ReplicationDownlinkSystem.encode(b, 7, 2, 9, record(), 980, 1000)).to.equal(16)
			local r = Codec.readRecord(b, 0)
			expect(r.slot).to.equal(7)
			expect(r.generation).to.equal(2)
			expect(r.epoch).to.equal(1)
			expect(r.ageMs).to.equal(20)
			expect(r.velocity.X).to.be.near(16, 0.2)
			expect(r.hasAction).to.equal(false)
		end)

		it("restamps a sample older than 1023 ms as a still body at batch time", function()
			local b = buffer.create(ReplicationDownlinkSystem.SCRATCH_BYTES)
			ReplicationDownlinkSystem.encode(b, 7, 0, 1, record(), -500, 1000)
			local r = Codec.readRecord(b, 0)
			expect(r.ageMs).to.equal(0)
			expect(r.velocity.Magnitude).to.equal(0)
			expect(r.position.X).to.be.near(-1200, 0.02)
		end)

		it("clamps a sample stamped after the batch time to age 0", function()
			local b = buffer.create(ReplicationDownlinkSystem.SCRATCH_BYTES)
			ReplicationDownlinkSystem.encode(b, 7, 0, 1, record(), 1040, 1000)
			expect(Codec.readRecord(b, 0).ageMs).to.equal(0)
		end)
	end)

	describe("closeness", function()
		it("weighs 3 within 50 studs, falls linearly, and weighs 1 from 600 studs", function()
			local config = ReplicationDownlinkSystem.DEFAULT_CONFIG
			expect(ReplicationDownlinkSystem.closeness(config, 0)).to.equal(3)
			expect(ReplicationDownlinkSystem.closeness(config, 50)).to.equal(3)
			expect(ReplicationDownlinkSystem.closeness(config, 325)).to.be.near(2, 1e-9)
			expect(ReplicationDownlinkSystem.closeness(config, 600)).to.equal(1)
			expect(ReplicationDownlinkSystem.closeness(config, 630)).to.equal(1)
		end)
	end)

	describe("pack", function()
		it("packs every candidate under the cap behind a sequenced header", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(5, 1000)
			local slots = range(1, 5)
			local batch =
				ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distancesFor(slots, constant(10)))
			expect(buffer.len(batch)).to.equal(Codec.HEADER_BYTES + 5 * 16)
			local header = Codec.readHeader(batch, 0)
			expect(header.seq).to.equal(1)
			expect(header.count).to.equal(5)
			expect(header.batchTimeMs).to.equal(1000)
			expect(buffer.readstring(batch, Codec.HEADER_BYTES, 16)).to.equal(buffer.readstring(bytes[1], 0, 16))
		end)

		it("sends every due body when they all fit, whatever their scores, and resets the scores", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			viewer.scores[1] = 0
			viewer.scores[5] = 1000
			local bytes, lengths = encoded(5, 1000)
			local slots = range(1, 5)
			local distances = { 10, 200, 290, 550, 620 }
			local sent = slotsIn(ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distances))
			expect(#sent).to.equal(5)
			for slot = 1, 5 do
				expect(contains(sent, slot)).to.equal(true)
				expect(viewer.scores[slot]).to.equal(0)
			end
		end)

		it("never exceeds 700 B: 50 bodies send 43, and the rest go first next frame", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(50, 1000)
			local slots = range(1, 50)
			local distances = distancesFor(slots, constant(10))
			local first = ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distances)
			expect(buffer.len(first) <= ReplicationDownlinkSystem.HARD_CAP_BYTES).to.equal(true)
			expect(#slotsIn(first)).to.equal(43)
			local second = slotsIn(ReplicationDownlinkSystem.pack(viewer, 1017, slots, bytes, lengths, distances))
			for i = 1, 7 do
				expect(second[i]).to.equal(43 + i)
			end
		end)

		it("sends the nearer bodies first over the cap", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(50, 1000)
			local slots = range(1, 50)
			-- Slots 1–25 at 550 studs, 26–50 at 20 studs: listed first, the far ones still lose.
			local distances = distancesFor(slots, function(slot)
				return if slot <= 25 then 550 else 20
			end)
			local sent = slotsIn(ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distances))
			expect(#sent).to.equal(43)
			for slot = 26, 50 do
				expect(contains(sent, slot)).to.equal(true)
			end
		end)

		it("resets a sent body's score and keeps the unsent ones' scores and pending flags", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(50, 1000)
			local slots = range(1, 50)
			local distances = distancesFor(slots, function(slot)
				return if slot <= 25 then 550 else 20
			end)
			local sent = slotsIn(ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distances))
			local farWeight = ReplicationDownlinkSystem.closeness(ReplicationDownlinkSystem.DEFAULT_CONFIG, 550)
			for slot = 1, 50 do
				if contains(sent, slot) then
					expect(viewer.scores[slot]).to.equal(0)
					expect(viewer.pending[slot]).to.equal(nil)
				else
					expect(viewer.scores[slot]).to.be.near(farWeight, 1e-9)
					expect(viewer.pending[slot]).to.equal(true)
				end
			end
		end)

		it("never accumulates a score for a body that is not due", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(51, 0)
			local slots = range(1, 50)
			local distances = distancesFor(slots, constant(10))
			ReplicationDownlinkSystem.pack(viewer, 0, slots, bytes, lengths, distances)
			expect(viewer.scores[1]).to.equal(0) -- sent in the first frame
			local rest = range(2, 50)
			local restDistances = distancesFor(rest, constant(10))
			for frame = 1, 5 do
				ReplicationDownlinkSystem.pack(viewer, frame * FRAME_MS, rest, bytes, lengths, restDistances)
			end
			expect(viewer.scores[1]).to.equal(0)
			expect(viewer.scores[51]).to.equal(nil)
		end)

		it("sends a far body within a bound set by the weights, under sustained overload", function()
			local config = ReplicationDownlinkSystem.DEFAULT_CONFIG
			local n = 50
			local far = n -- the highest slot: it loses every tie
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(n, 0)
			local slots = range(1, n)
			local distances = distancesFor(slots, function(slot)
				return if slot == far then config.farStuds else 10
			end)
			--[[
				The bound. Near bodies gain wNear = 3 per frame, the far one wFar = 1 (it is beyond the far cap,
				so it is held the one frame after each send). Per frame at least K records go:
				K = floor((24000 / 60 − 7) / 16) = 24. Say the far body is unsent for T frames after a send. In
				the last floor(T / 2) of them its score is at least wFar · T / 2, and every body sent instead
				had a score at least that high, so it had waited at least T / (2 · r) frames since its own
				previous send (r = wNear / wFar): each of the other n − 1 bodies is sent at most r + 1 times in
				that window. Those windows hold at least K · floor(T / 2) sends, so
				K · floor(T / 2) ≤ (n − 1)(r + 1): floor(T / 2) ≤ 8 here, T ≤ 17, and the far body is sent at
				least once in every 18 frames.
			]]
			local ratio = config.nearWeight / config.farWeight
			local perFrame =
				math.floor((ReplicationDownlinkSystem.BUDGET_BYTES_PER_SECOND / 60 - Codec.HEADER_BYTES) / 16)
			local halfWindow = math.floor((n - 1) * (ratio + 1) / perFrame)
			local bound = 2 * halfWindow + 2 -- frames between two sends: T + 1
			local lastSentFrame, maxGap = 0, 0
			for frame = 1, 600 do
				local batch = ReplicationDownlinkSystem.pack(viewer, frame * FRAME_MS, slots, bytes, lengths, distances)
				if contains(slotsIn(batch), far) then
					maxGap = math.max(maxGap, frame - lastSentFrame)
					lastSentFrame = frame
				end
			end
			maxGap = math.max(maxGap, 600 - lastSentFrame)
			expect(bound).to.equal(18)
			expect(maxGap > 2).to.equal(true) -- overloaded: the far body really waited
			expect(maxGap <= bound).to.equal(true)
		end)

		it("holds a far body inside 33 ms, never a near one, and sends it once the interval passes", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(2, 1000)
			local slots = { 1, 2 }
			local distances = { 100, 400 }
			expect(#slotsIn(ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distances))).to.equal(2)
			local held = slotsIn(ReplicationDownlinkSystem.pack(viewer, 1017, slots, bytes, lengths, distances))
			expect(contains(held, 1)).to.equal(true)
			expect(contains(held, 2)).to.equal(false)
			expect(viewer.pending[2]).to.equal(true)
			expect(viewer.scores[2]).to.equal(0) -- held: keeps its place, gains nothing
			local after = slotsIn(ReplicationDownlinkSystem.pack(viewer, 1034, slots, bytes, lengths, distances))
			expect(contains(after, 1)).to.equal(true)
			expect(contains(after, 2)).to.equal(true)
			expect(viewer.pending[2]).to.equal(nil)
		end)

		it("keeps to the 24 KB/s budget over a second", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			local bytes, lengths = encoded(50, 0)
			local slots = range(1, 50)
			local distances = distancesFor(slots, constant(10))
			local total = 0
			for frame = 0, 59 do
				local batch = ReplicationDownlinkSystem.pack(viewer, frame * FRAME_MS, slots, bytes, lengths, distances)
				if batch ~= nil then
					total += buffer.len(batch)
				end
			end
			expect(
				total <= ReplicationDownlinkSystem.HARD_CAP_BYTES + ReplicationDownlinkSystem.BUDGET_BYTES_PER_SECOND
			).to.equal(true)
			expect(total >= 22000).to.equal(true)
		end)

		it("sends nothing when the allowance cannot fit a record, and marks every candidate pending", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			viewer.allowanceBytes = 10
			viewer.lastPackMs = 1000
			local bytes, lengths = encoded(3, 1000)
			local slots = range(1, 3)
			expect(
				ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distancesFor(slots, constant(10)))
			).to.equal(nil)
			expect(viewer.pending[1]).to.equal(true)
			expect(viewer.pending[3]).to.equal(true)
			expect(viewer.seq).to.equal(0)
		end)

		it("clears a body's pending flag once it is sent", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			viewer.pending[2] = true
			local bytes, lengths = encoded(3, 1000)
			local slots = range(1, 3)
			ReplicationDownlinkSystem.pack(viewer, 1000, slots, bytes, lengths, distancesFor(slots, constant(10)))
			expect(viewer.pending[2]).to.equal(nil)
		end)

		it("returns nil for no candidates", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			expect(ReplicationDownlinkSystem.pack(viewer, 1000, {}, {}, {}, {})).to.equal(nil)
		end)

		it("forget drops a body's pending flag, score and last send time", function()
			local viewer = ReplicationDownlinkSystem.newViewer()
			viewer.pending[4] = true
			viewer.scores[4] = 12
			viewer.lastSentMs[4] = 1000
			ReplicationDownlinkSystem.forget(viewer, 4)
			expect(viewer.pending[4]).to.equal(nil)
			expect(viewer.scores[4]).to.equal(nil)
			expect(viewer.lastSentMs[4]).to.equal(nil)
		end)
	end)
end
