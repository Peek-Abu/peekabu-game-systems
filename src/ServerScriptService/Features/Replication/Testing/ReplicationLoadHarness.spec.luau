local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ReplicationUplinkReceiver = require(ServerScriptService.Features.Replication.Net.ReplicationUplinkReceiver)
local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)
local ReplicationUplinkSender = require(ReplicatedStorage.Client.Features.Replication.Net.ReplicationUplinkSender)

local PLAYERS = 60
local FRAMES = 300 -- 5 s at 60 Hz
local FRAME_MS = 1000 / 60
local FIRST_USER = -71000

-- 60 owners walking small circles inside one 160-stud square (everyone sees everyone: the worst case for
-- the fan-out), each streaming through the REAL uplink pipeline (RequestHandler) and one server fan-out per
-- frame. Owner-side packet building is outside the measured windows; only server work is timed.
local function run()
	local world = ReplicationFanoutSystem.newWorld()
	local bodies, senders, players, byUser = {}, {}, {}, {}
	for i = 1, PLAYERS do
		local base = Vector3.new(-1228 + (i % 8) * 20, 10, -363 + (i // 8) * 20)
		local body = ReplicationFanoutSystem.newBody(FIRST_USER - i, i, 0, base)
		body.ready = true
		body.epoch.value = 1
		ReplicationFanoutSystem.respawned(body)
		ReplicationFanoutSystem.addBody(world, body)
		bodies[i] = { body = body, base = base }
		senders[i] = ReplicationUplinkSender.new()
		players[i] = { UserId = body.userId }
		byUser[body.userId] = body
	end
	local nowMs = 0
	local handler = ReplicationUplinkReceiver.wrap(function(player)
		local body = byUser[player.UserId]
		return if body ~= nil and body.alive then body.ingest else nil
	end, function()
		return math.floor(nowMs)
	end, function(player, state)
		local body = byUser[player.UserId]
		if body ~= nil and state.latest ~= nil then
			body.position = state.latest.position
		end
	end)
	local hooks = {
		send = function() end,
		visibility = function() end,
	}
	local uplinkSeconds, packets, fanoutSeconds, garbageKb, batchesSent = 0, 0, 0, 0, 0
	local outgoing = {}
	for frame = 1, FRAMES do
		nowMs = frame * FRAME_MS
		table.clear(outgoing)
		for i, entry in bodies do
			local angle = frame / 60 * 2 + i
			local record = {
				slot = 0,
				generation = 0,
				epoch = 1,
				ageMs = 0,
				position = entry.base + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3,
				yaw = angle,
				pitch = 0,
				velocity = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 6,
				state = 8,
				grounded = true,
				hasAction = false,
				rotation = nil,
			}
			local packet = ReplicationUplinkSender.step(senders[i], math.floor(nowMs), record)
			if packet ~= nil then
				table.insert(outgoing, { packet = packet, player = players[i] })
			end
		end
		local before = collectgarbage("count")
		local started = os.clock()
		for _, out in outgoing do
			handler(out.packet, out.player)
		end
		uplinkSeconds += os.clock() - started
		packets += #outgoing
		local fanoutStarted = os.clock()
		batchesSent += ReplicationFanoutSystem.step(world, math.floor(nowMs), hooks)
		fanoutSeconds += os.clock() - fanoutStarted
		local after = collectgarbage("count")
		if after > before then
			garbageKb += after - before
		end
	end
	for i = 1, PLAYERS do
		RequestHandler.resetRateLimit(FIRST_USER - i)
	end
	return {
		uplinkMicroseconds = uplinkSeconds / math.max(packets, 1) * 1e6,
		fanoutMilliseconds = fanoutSeconds / FRAMES * 1000,
		garbageKbPerSecond = garbageKb / (FRAMES / 60),
		packets = packets,
		batches = batchesSent,
	}
end

return function()
	describe("server load at 60 players in one view", function()
		local result
		beforeAll(function()
			result = run()
			print(
				string.format(
					"[R2 load] %d players: %.1f µs per uplink packet (RequestHandler + decode + ingest, %d packets) · fan-out %.3f ms/frame (%d batches) · server garbage %.0f KB/s",
					PLAYERS,
					result.uplinkMicroseconds,
					result.packets,
					result.fanoutMilliseconds,
					result.batches,
					result.garbageKbPerSecond
				)
			)
		end)

		it("streams every owner and relays to every viewer", function()
			expect(result.packets > PLAYERS * FRAMES * 0.9).to.equal(true)
			expect(result.batches > PLAYERS * (FRAMES - 1) * 0.9).to.equal(true)
		end)

		it("keeps an uplink packet under 100 µs on the server", function()
			expect(result.uplinkMicroseconds < 100).to.equal(true)
		end)

		it("keeps the fan-out under 4 ms per frame", function()
			expect(result.fanoutMilliseconds < 4).to.equal(true)
		end)

		-- Loose on purpose: decoding and the per-viewer batch buffers allocate by design (about 2–4 MB/s at
		-- this load); the printed number is what gets compared with the scorecard.
		it("keeps server garbage under 10 MB per second", function()
			expect(result.garbageKbPerSecond < 10000).to.equal(true)
		end)
	end)
end
