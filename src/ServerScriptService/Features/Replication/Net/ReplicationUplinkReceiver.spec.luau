local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Codec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local Uplink = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationUplinkCodec)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ReplicationUplinkRules = require(ServerScriptService.Features.Replication.Rules.ReplicationUplinkRules)
local ReplicationUplinkReceiver = require(ServerScriptService.Features.Replication.Net.ReplicationUplinkReceiver)

local USER = -88001

local function packet(sentMs, overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200 + sentMs / 1000, 40, -350),
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
	return Uplink.encode(sentMs, { { record = r, sampleMs = sentMs } })
end

local function fixture(nowMs)
	local state = ReplicationUplinkRules.new()
	ReplicationUplinkRules.reset(state, 1)
	local f = { state = state, accepted = 0, nowMs = nowMs, player = { UserId = USER } }
	f.handler = ReplicationUplinkReceiver.wrap(function(player)
		return if player.UserId == USER then state else nil
	end, function()
		return f.nowMs
	end, function()
		f.accepted += 1
	end)
	return f
end

local function rejected()
	return RequestHandler.getRateLimitStatus(USER, ReplicationUplinkReceiver.ACTION).rejected
end

return function()
	afterEach(function()
		RequestHandler.resetRateLimit(USER)
	end)

	it("feeds a valid packet to ingest and reports the accept", function()
		local f = fixture(1030)
		f.handler(packet(1000), f.player)
		expect(f.accepted).to.equal(1)
		expect(f.state.latestMs).to.equal(1000)
	end)

	it("counts a malformed packet without a warning and never reaches ingest", function()
		local f = fixture(1030)
		local warnings = 0
		local unsubscribe = Logger.subscribe(function(entry)
			if entry.level == "WARN" then
				warnings += 1
			end
		end)
		f.handler(buffer.create(7), f.player)
		unsubscribe()
		expect(warnings).to.equal(0)
		expect(rejected()).to.equal(1)
		expect(f.state.counters.accepted).to.equal(0)
	end)

	it("rejects a ragdoll claim at validation", function()
		local f = fixture(1030)
		f.handler(packet(1000, { state = Codec.STATE_RAGDOLL }), f.player)
		expect(rejected()).to.equal(1)
		expect(f.accepted).to.equal(0)
	end)

	it("lets a backlog through: 30 packets sent 17 ms apart arrive at once", function()
		local f = fixture(1600)
		for i = 0, 29 do
			f.handler(packet(1100 + i * 17), f.player)
		end
		expect(rejected()).to.equal(0)
		expect(f.state.counters.accepted).to.equal(30)
	end)

	it("caps a flood: 30 packets with one send time pass the bucket at most", function()
		local f = fixture(1600)
		for _ = 1, 30 do
			f.handler(packet(1500), f.player)
		end
		expect(rejected()).to.equal(30 - ReplicationUplinkReceiver.BUCKET)
		expect(f.state.counters.accepted).to.equal(1)
		expect(f.state.counters.duplicate).to.equal(ReplicationUplinkReceiver.BUCKET - 1)
	end)

	it("refills nothing when the send time steps backwards", function()
		local f = fixture(1600)
		for _ = 1, ReplicationUplinkReceiver.BUCKET do
			f.handler(packet(1500), f.player)
		end
		f.handler(packet(1000), f.player)
		expect(rejected()).to.equal(1)
	end)
end
