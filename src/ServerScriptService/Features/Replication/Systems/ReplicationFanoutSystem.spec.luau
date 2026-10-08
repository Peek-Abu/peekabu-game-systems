local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local Fanout = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)

local ORIGIN = Vector3.new(-1228, 10, -363)

local function body(userId, slot, position)
	local b = Fanout.newBody(userId, slot, 0, position)
	b.ready = true
	b.epoch.value = 1
	Fanout.respawned(b)
	return b
end

-- Simulate an accepted uplink sample for `b`.
local function feed(b, nowMs, position)
	b.ingest.latest = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = position,
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	b.ingest.latestMs = nowMs
	b.ingest.fresh = true
	b.position = position
end

local function recorder()
	local log = { sends = {}, enters = {}, leaves = {} }
	local hooks = {
		send = function(viewer, batch)
			table.insert(log.sends, { viewer = viewer.userId, batch = batch })
		end,
		visibility = function(viewer, subject, entered)
			table.insert(
				if entered then log.enters else log.leaves,
				{ viewer = viewer.userId, subject = subject.userId }
			)
		end,
	}
	return log, hooks
end

local function slotsIn(batch)
	local header = Codec.readHeader(batch, 0)
	local out = {}
	for i = 1, header.count do
		table.insert(out, Codec.readRecord(batch, Codec.HEADER_BYTES + (i - 1) * Codec.RECORD_BYTES).slot)
	end
	return out
end

local function sendsTo(log, userId)
	local out = {}
	for _, s in log.sends do
		if s.viewer == userId then
			table.insert(out, s.batch)
		end
	end
	return out
end

local function world(...)
	local w = Fanout.newWorld()
	for _, b in { ... } do
		Fanout.addBody(w, b)
	end
	return w
end

return function()
	it("relays a moving body to a nearby viewer every frame, after one enter each way", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		for frame = 1, 5 do
			feed(a, frame * 17, ORIGIN + Vector3.new(frame * 0.3, 0, 0))
			Fanout.step(w, frame * 17, hooks)
		end
		expect(#log.enters).to.equal(2)
		local batches = sendsTo(log, 2)
		expect(#batches).to.equal(5)
		for _, batch in batches do
			expect(slotsIn(batch)[1]).to.equal(1)
		end
	end)

	it("never sends a viewer its own body", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		expect(#sendsTo(log, 1)).to.equal(0)
	end)

	it("encodes each body once per frame: two viewers get identical bytes", function()
		local a = body(1, 1, ORIGIN)
		local v1, v2 = body(2, 2, ORIGIN + Vector3.new(30, 0, 0)), body(3, 3, ORIGIN + Vector3.new(0, 0, 30))
		local w = world(a, v1, v2)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		local b1, b2 = sendsTo(log, 2)[1], sendsTo(log, 3)[1]
		expect(buffer.readstring(b1, 0, buffer.len(b1))).to.equal(buffer.readstring(b2, 0, buffer.len(b2)))
	end)

	it("enters at 600 studs and leaves past 630, once each", function()
		local a, v = body(1, 1, ORIGIN + Vector3.new(700, 0, 0)), body(2, 2, ORIGIN)
		local w = world(a, v)
		local log, hooks = recorder()
		for frame, distance in { 700, 590, 615, 625, 640, 620, 595 } do
			feed(a, frame * 17, ORIGIN + Vector3.new(distance, 0, 0))
			Fanout.step(w, frame * 17, hooks)
		end
		local enters, leaves = 0, 0
		for _, e in log.enters do
			if e.viewer == 2 then
				enters += 1
			end
		end
		for _, l in log.leaves do
			if l.viewer == 2 then
				leaves += 1
			end
		end
		expect(enters).to.equal(2)
		expect(leaves).to.equal(1)
	end)

	it("sends a still body only on change, its two resends and the 1 Hz repair", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 0, ORIGIN)
		for frame = 1, 72 do -- 1.2 s
			Fanout.step(w, frame * 1000 / 60, hooks)
		end
		expect(#sendsTo(log, 2)).to.equal(4)
	end)

	it("gives a viewer nothing until it is ready", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		v.ready = false
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		expect(#sendsTo(log, 2)).to.equal(0)
		for _, e in log.enters do
			expect(e.viewer).never.to.equal(2)
		end
	end)

	it("takes a body that died out of every viewer", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		a.alive = false
		Fanout.step(w, 34, hooks)
		expect(#log.leaves).to.equal(1)
		expect(log.leaves[1].viewer).to.equal(2)
		expect(log.leaves[1].subject).to.equal(1)
	end)

	it("removeBody fires a leave for each viewer that had the body", function()
		local a = body(1, 1, ORIGIN)
		local v1, v2 = body(2, 2, ORIGIN + Vector3.new(30, 0, 0)), body(3, 3, ORIGIN + Vector3.new(0, 0, 30))
		local w = world(a, v1, v2)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		expect(Fanout.removeBody(w, 1, hooks)).to.equal(a)
		local fromA = 0
		for _, l in log.leaves do
			if l.subject == 1 then
				fromA += 1
			end
		end
		expect(fromA).to.equal(2)
		expect(w.bodies[1]).to.equal(nil)
	end)

	it("a full body stays full when the max rises", function()
		local a = body(1, 1, ORIGIN)
		expect(a.health).to.equal(a.maxHealth)
		expect(Fanout.setMaxHealth(a, 200)).to.equal(true)
		expect(a.maxHealth).to.equal(200)
		expect(a.health).to.equal(200)
	end)

	it("setMaxHealth keeps a damaged body's health, clamps down, and refuses nonsense", function()
		local a = body(1, 1, ORIGIN)
		a.health = 60
		expect(Fanout.setMaxHealth(a, 210)).to.equal(true)
		expect(a.maxHealth).to.equal(210)
		expect(a.health).to.equal(60)
		expect(Fanout.setMaxHealth(a, 50)).to.equal(true)
		expect(a.health).to.equal(50)
		expect(Fanout.setMaxHealth(a, 0 / 0)).to.equal(false)
		expect(Fanout.setMaxHealth(a, 0)).to.equal(false)
		expect(Fanout.setMaxHealth(a, math.huge)).to.equal(false)
		expect(a.maxHealth).to.equal(50)
		Fanout.respawned(a)
		expect(a.health).to.equal(50)
	end)

	it("enterRecord synthesises a still record at the spawn point before any uplink", function()
		local a = body(1, 1, ORIGIN + Vector3.new(5, 0, 0))
		local record, sampleMs = Fanout.enterRecord(a, 1234)
		expect(sampleMs).to.equal(1234)
		expect(record.position).to.equal(ORIGIN + Vector3.new(5, 0, 0))
		expect(record.velocity).to.equal(Vector3.zero)
		feed(a, 1300, ORIGIN)
		local latest, latestMs = Fanout.enterRecord(a, 1400)
		expect(latest).to.equal(a.ingest.latest)
		expect(latestMs).to.equal(1300)
	end)

	it("enterPayload packs the enter record into one 16 B buffer the batch codec reads back", function()
		local a = body(1, 5, ORIGIN)
		a.generation = 2
		feed(a, 1300, ORIGIN + Vector3.new(3, 0, 0))
		local payload = Fanout.enterPayload(a, 1400)
		expect(payload.slot).to.equal(5)
		expect(payload.generation).to.equal(2)
		expect(payload.batchTimeMs).to.equal(1400)
		expect(buffer.len(payload.record)).to.equal(Codec.RECORD_BYTES)
		local record = Codec.readRecord(payload.record, 0)
		expect(record.slot).to.equal(5)
		expect(record.generation).to.equal(2)
		expect(record.epoch).to.equal(1)
		expect(record.ageMs).to.equal(100)
		expect((record.position - (ORIGIN + Vector3.new(3, 0, 0))).Magnitude < 0.5).to.equal(true)
	end)

	it("enterPayload before any uplink is a still record at the spawn point with age 0", function()
		local a = body(1, 1, ORIGIN + Vector3.new(5, 0, 0))
		local payload = Fanout.enterPayload(a, 1234)
		local record = Codec.readRecord(payload.record, 0)
		expect(record.ageMs).to.equal(0)
		expect((record.position - (ORIGIN + Vector3.new(5, 0, 0))).Magnitude < 0.5).to.equal(true)
	end)
end
