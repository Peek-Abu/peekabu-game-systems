local ServerScriptService = game:GetService("ServerScriptService")
local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)
local ReplicationBodyStateSender = require(ServerScriptService.Features.Replication.Net.ReplicationBodyStateSender)

-- A relay over fresh maps with a settable clock.
local function world(maxStates)
	local bodies, players = {}, {}
	local clock = { ms = 1000 }
	local relay = ReplicationBodyStateSender.new(bodies, players, function()
		return clock.ms
	end, maxStates)
	return relay, bodies, players, clock
end

-- A ready, live body (slot = userId) and its fake player.
local function addBody(bodies, players, userId)
	local body = ReplicationFanoutSystem.newBody(userId, userId, 0, Vector3.zero)
	body.ready = true
	body.alive = true
	bodies[userId] = body
	players[userId] = { UserId = userId, Name = `P{userId}` }
	return body, players[userId]
end

-- Senders that record every message.
local function recorder()
	local log = { started = {}, stopped = {} }
	local senders = {
		started = function(target, subject, epoch, key, data, startMs, durationMs)
			table.insert(log.started, {
				target = target,
				subject = subject,
				epoch = epoch,
				key = key,
				data = data,
				startMs = startMs,
				durationMs = durationMs,
			})
		end,
		stopped = function(target, subject, epoch, key, startMs)
			table.insert(
				log.stopped,
				{ target = target, subject = subject, epoch = epoch, key = key, startMs = startMs }
			)
		end,
	}
	return senders, log
end

local function targetIds(messages)
	local ids = {}
	for _, message in messages do
		table.insert(ids, message.target.UserId)
	end
	table.sort(ids)
	return ids
end

-- Subject 1 (epoch 4), observer 2 (has 1 loaded), bystander 3.
local function scene(maxStates)
	local relay, bodies, players, clock = world(maxStates)
	local subjectBody, subject = addBody(bodies, players, 1)
	subjectBody.epoch.value = 4
	local observerBody = addBody(bodies, players, 2)
	observerBody.relevant[1] = true
	addBody(bodies, players, 3)
	local senders, log = recorder()
	local channel = ReplicationBodyStateSender.define(relay, "action", senders)
	return relay, channel, log, bodies, players, clock, subject
end

return function()
	describe("define", function()
		it("refuses to define a kind twice", function()
			local relay = world()
			local senders = recorder()
			ReplicationBodyStateSender.define(relay, "action", senders)
			expect(function()
				ReplicationBodyStateSender.define(relay, "action", senders)
			end).to.throw()
		end)
	end)

	describe("set", function()
		it("sends Started to the owner and every observer, with the body's epoch", function()
			local _, channel, log, _, _, _, subject = scene()
			expect(channel:set(subject, "full", "leap", 1000, 600)).to.equal("created")
			local ids = targetIds(log.started)
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal(1)
			expect(ids[2]).to.equal(2)
			for _, message in log.started do
				expect(message.subject).to.equal(subject)
				expect(message.epoch).to.equal(4)
				expect(message.key).to.equal("full")
				expect(message.data).to.equal("leap")
				expect(message.startMs).to.equal(1000)
				expect(message.durationMs).to.equal(600)
			end
		end)

		-- Review Focus 4: one player alone in the server still sees their own action.
		it("sends Started to the owner even when nobody observes the body", function()
			local relay, bodies, players = world()
			local _, subject = addBody(bodies, players, 1)
			local senders, log = recorder()
			local channel = ReplicationBodyStateSender.define(relay, "action", senders)
			channel:set(subject, "full", "leap", 1000, 600)
			expect(#log.started).to.equal(1)
			expect(log.started[1].target).to.equal(subject)
		end)

		it("skips an owner whose client is not ready", function()
			local _, channel, log, bodies, _, _, subject = scene()
			bodies[1].ready = false
			channel:set(subject, "full", "leap", 1000, 600)
			local ids = targetIds(log.started)
			expect(#ids).to.equal(1)
			expect(ids[1]).to.equal(2)
		end)

		it("refuses a player with no live body and sends nothing", function()
			local _, channel, log, bodies, _, _, subject = scene()
			bodies[1].alive = false
			expect(channel:set(subject, "full", "leap", 1000, 600)).to.equal("no-body")
			expect(#log.started).to.equal(0)
		end)

		it("sends Started again on a replace, and no Stopped", function()
			local _, channel, log, _, _, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 600)
			expect(channel:set(subject, "full", "guard", 1100, 300)).to.equal("replaced")
			expect(#log.started).to.equal(4)
			expect(#log.stopped).to.equal(0)
		end)

		it("refuses past the per-body cap and sends nothing for the refused state", function()
			local _, channel, log, _, _, _, subject = scene(1)
			channel:set(subject, "full", "leap", 1000, 600)
			expect(channel:set(subject, "upper", "pose", 1000, nil)).to.equal("full")
			expect(#log.started).to.equal(2)
		end)
	end)

	describe("clear (an early stop)", function()
		it("sends Stopped with the cleared state's start to the owner and observers", function()
			local _, channel, log, _, _, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 600)
			expect(channel:clear(subject, "full")).to.equal(true)
			local ids = targetIds(log.stopped)
			expect(#ids).to.equal(2)
			expect(log.stopped[1].startMs).to.equal(1000)
			expect(log.stopped[1].key).to.equal("full")
			expect(log.stopped[1].epoch).to.equal(4)
		end)

		it("sends nothing for a key that holds nothing or already ran out", function()
			local _, channel, log, _, _, clock, subject = scene()
			expect(channel:clear(subject, "upper")).to.equal(false)
			channel:set(subject, "full", "leap", 1000, 100)
			clock.ms = 1200
			expect(channel:clear(subject, "full")).to.equal(false)
			expect(#log.stopped).to.equal(0)
		end)
	end)

	describe("replayTo (right after a viewer's Enter)", function()
		it("sends every live state, with its original start time, to that one viewer", function()
			local relay, channel, log, _, players, clock, subject = scene()
			channel:set(subject, "full", "leap", 1000, 5000)
			channel:set(subject, "upper", "pose", 1500, nil)
			clock.ms = 3000
			local before = #log.started
			expect(ReplicationBodyStateSender.replayTo(relay, 1, players[3])).to.equal(2)
			expect(#log.started).to.equal(before + 2)
			expect(log.started[before + 1].target).to.equal(players[3])
			expect(log.started[before + 1].startMs).to.equal(1000)
			expect(log.started[before + 2].startMs).to.equal(1500)
			expect(ReplicationBodyStateSender.stats(relay).action.replayed).to.equal(2)
		end)

		it("replays nothing for a body without states or without a live body", function()
			local relay, channel, _, bodies, players, _, subject = scene()
			expect(ReplicationBodyStateSender.replayTo(relay, 1, players[3])).to.equal(0)
			channel:set(subject, "full", "leap", 1000, 5000)
			bodies[1].alive = false
			expect(ReplicationBodyStateSender.replayTo(relay, 1, players[3])).to.equal(0)
		end)

		it("leaves out states that ended before the viewer arrived", function()
			local relay, channel, _, _, players, clock, subject = scene()
			channel:set(subject, "full", "leap", 1000, 500)
			clock.ms = 2000
			expect(ReplicationBodyStateSender.replayTo(relay, 1, players[3])).to.equal(0)
		end)
	end)

	describe("clearBody (respawn, slot switch, leave)", function()
		it("drops the body's states without a message", function()
			local relay, channel, log, _, players, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 5000)
			ReplicationBodyStateSender.clearBody(relay, 1)
			expect(channel:get(subject, "full")).to.equal(nil)
			expect(#log.stopped).to.equal(0)
			expect(ReplicationBodyStateSender.replayTo(relay, 1, players[3])).to.equal(0)
		end)
	end)

	describe("stats", function()
		it("reports active states and counters per kind", function()
			local relay, channel, _, _, _, _, subject = scene()
			channel:set(subject, "full", "leap", 1000, 5000)
			channel:set(subject, "full", "guard", 1100, 5000)
			local stats = ReplicationBodyStateSender.stats(relay).action
			expect(stats.active).to.equal(1)
			expect(stats.counters.created).to.equal(1)
			expect(stats.counters.replaced).to.equal(1)
		end)
	end)
end
