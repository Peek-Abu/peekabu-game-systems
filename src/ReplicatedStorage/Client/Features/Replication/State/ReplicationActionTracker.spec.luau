--[=[
	ReplicationActionTracker against a fake registry, a settable clock and fake rigs. User 2's body is in epoch 1 unless a
	test says otherwise; wire 1 is a 1000 ms one-shot on the full layer, wire 3 an open-ended loop on upper.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationActionTracker = require(ReplicatedStorage.Client.Features.Replication.State.ReplicationActionTracker)
local ReplicationStateTimingUtils =
	require(ReplicatedStorage.Shared.Features.Replication.Utils.ReplicationStateTimingUtils)

local DEFS = {
	[1] = { id = "leap", def = { looped = false, layer = "full", durationMs = 1000, interruption = "attack" } },
	[3] = { id = "pose", def = { looped = true, layer = "upper", interruption = "ambient" } },
}

local function resolveWire(wireId)
	local entry = DEFS[wireId]
	if entry == nil then
		return nil, nil
	end
	return entry.id, entry.def
end

-- A fake rig: records plays and stops; handles expose a settable time and length.
local function makeTarget(options)
	options = options or {}
	local target = { plays = {}, stops = {} }
	target.play = function(_self, id, opts)
		if options.fail then
			return nil, options.fail
		end
		local handle =
			{ id = id, opts = opts, stopped = false, time = opts.startAt or 0, clipLength = options.length or 0 }
		handle.stop = function()
			handle.stopped = true
		end
		handle.isPlaying = function()
			return not handle.stopped
		end
		handle.timePosition = function()
			return handle.time
		end
		handle.length = function()
			return handle.clipLength
		end
		handle.adjustSpeed = function() end
		handle.onMarker = function()
			return function() end
		end
		table.insert(target.plays, handle)
		return handle, nil
	end
	target.stop = function(_self, id)
		table.insert(target.stops, id)
		return true
	end
	return target
end

local function started(overrides)
	local message = {
		userId = 2,
		epoch = 1,
		layer = 1,
		wireId = 1,
		variant = 0,
		speedMilli = 1000,
		startMs = 10000,
		durationMs = 1000,
	}
	for key, value in overrides or {} do
		message[key] = value
	end
	return message
end

local POSE = { layer = 2, wireId = 3, durationMs = nil }

local function pose(overrides)
	local message = started(POSE)
	message.durationMs = nil
	for key, value in overrides or {} do
		message[key] = value
	end
	return message
end

-- A state whose clock reads `clock.ms` for every body, with user 2 known in epoch 1.
local function setup()
	local clock = { ms = 10000 }
	local state = ReplicationActionTracker.new(resolveWire, function(_userId)
		return clock.ms
	end)
	ReplicationActionTracker.resetBody(state, 2, 1)
	return state, clock
end

return function()
	describe("arrival", function()
		it("plays a Started on an attached rig at once, with the server's variant and speed", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			expect(
				ReplicationActionTracker.started(state, started({ variant = 1, speedMilli = 2000, durationMs = 500 }))
			).to.equal("played")
			local play = target.plays[1]
			expect(play.id).to.equal("leap")
			expect(play.opts.variant).to.equal(1)
			expect(play.opts.speed).to.equal(2)
			expect(play.opts.startAt).to.equal(0)
		end)

		it("starts a late arrival that far into the clip, at its speed", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			clock.ms = 10400
			ReplicationActionTracker.started(state, started({ speedMilli = 1500 }))
			expect(target.plays[1].opts.startAt).to.be.near(0.6, 1e-6)
			expect(state.counters.joinedLate).to.equal(1)
		end)

		it("keeps an action pending until its body has a rig, then plays it from the right point", function()
			local state, clock = setup()
			expect(ReplicationActionTracker.started(state, started())).to.equal("pending")
			expect(state.counters.pendingRig).to.equal(1)
			clock.ms = 10300
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			expect(target.plays[1].opts.startAt).to.be.near(0.3, 1e-6)
		end)

		it("waits for the body's clock to reach the start (a puppet's render time)", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			expect(ReplicationActionTracker.started(state, started({ startMs = 10200 }))).to.equal("pending")
			ReplicationActionTracker.step(state)
			expect(#target.plays).to.equal(0)
			clock.ms = 10200
			ReplicationActionTracker.step(state)
			expect(#target.plays).to.equal(1)
			expect(target.plays[1].opts.startAt).to.equal(0)
		end)

		it("ignores a Started that is already past its duration", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			clock.ms = 11500
			expect(ReplicationActionTracker.started(state, started())).to.equal("expired")
			expect(#target.plays).to.equal(0)
		end)

		it("ignores a Started from another body epoch", function()
			local state = setup()
			expect(ReplicationActionTracker.started(state, started({ epoch = 2 }))).to.equal("stale")
			expect(state.counters.stale).to.equal(1)
		end)

		it("refuses an unknown wire id, or a layer that does not match the entry", function()
			local state = setup()
			expect(ReplicationActionTracker.started(state, started({ wireId = 99 }))).to.equal("unknown")
			expect(ReplicationActionTracker.started(state, started({ layer = 2 }))).to.equal("unknown")
			expect(state.counters.unknown).to.equal(2)
		end)
	end)

	describe("non-finite input", function()
		it("refuses a Started whose start, speed or duration is NaN or infinite", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			expect(ReplicationActionTracker.started(state, started({ startMs = 0 / 0 }))).to.equal("unknown")
			expect(ReplicationActionTracker.started(state, started({ startMs = math.huge }))).to.equal("unknown")
			expect(ReplicationActionTracker.started(state, started({ speedMilli = math.huge }))).to.equal("unknown")
			expect(ReplicationActionTracker.started(state, started({ durationMs = 0 / 0 }))).to.equal("unknown")
			expect(#target.plays).to.equal(0)
			expect((ReplicationActionTracker.counts(state))).to.equal(0)
		end)

		it("never hands the player a non-finite startAt when the clock is not finite", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			clock.ms = 0 / 0
			ReplicationActionTracker.started(state, pose())
			clock.ms = math.huge
			ReplicationActionTracker.step(state)
			expect(#target.plays).to.equal(0)
		end)
	end)

	describe("replace and stop", function()
		it("replaces the action on a layer with a newer Started", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			clock.ms = 10100
			ReplicationActionTracker.started(state, started({ startMs = 10100 }))
			expect(#target.plays).to.equal(2)
			expect(target.stops[1]).to.equal("leap")
		end)

		it("plays actions on different layers together", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.started(state, pose())
			expect(#target.plays).to.equal(2)
			expect(#target.stops).to.equal(0)
		end)

		it("stops the action a Stopped names", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			expect(ReplicationActionTracker.stopped(state, { userId = 2, epoch = 1, layer = 1, startMs = 10000 })).to.equal(
				true
			)
			expect(target.stops[1]).to.equal("leap")
			expect(state.counters.stopped).to.equal(1)
		end)

		it("leaves a newer action alone when a Stopped names an older start", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			clock.ms = 10100
			ReplicationActionTracker.started(state, started({ startMs = 10100 }))
			expect(ReplicationActionTracker.stopped(state, { userId = 2, epoch = 1, layer = 1, startMs = 10000 })).to.equal(
				false
			)
		end)
	end)

	describe("body lifecycle", function()
		it("drops the old epoch's actions when the body's epoch changes", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.resetBody(state, 2, 2)
			expect(target.stops[1]).to.equal("leap")
			expect((ReplicationActionTracker.counts(state))).to.equal(0)
		end)

		it("drops pending actions of the old epoch when a rig of a new epoch attaches", function()
			local state = setup()
			ReplicationActionTracker.started(state, started())
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 2, target)
			expect(#target.plays).to.equal(0)
		end)

		-- A Started that beats the rig (owner after Spawn, puppet not yet acquired): held, and dropped if the
		-- rig that finally appears belongs to another epoch.
		it("holds a Started that beat its rig and drops it if the rig's epoch differs", function()
			local state = ReplicationActionTracker.new(resolveWire, function()
				return 10000
			end)
			expect(ReplicationActionTracker.started(state, started())).to.equal("pending")
			local stale = makeTarget()
			ReplicationActionTracker.attach(state, 2, 2, stale)
			expect(#stale.plays).to.equal(0)
			expect((ReplicationActionTracker.counts(state))).to.equal(0)
		end)

		-- The owner's slot row is the epoch authority: a Spawn build of an older epoch must not rewind it.
		it("attachOwner drops a stale build's attach and keeps the newer epoch", function()
			local state = setup()
			ReplicationActionTracker.resetBody(state, 2, 2)
			local stale = makeTarget()
			expect(ReplicationActionTracker.attachOwner(state, 2, 1, stale)).to.equal(false)
			expect(#stale.plays).to.equal(0)
			expect(ReplicationActionTracker.started(state, started({ epoch = 2 }))).to.equal("pending")
			expect(ReplicationActionTracker.started(state, started({ epoch = 1, layer = 3, wireId = 3 }))).to.equal(
				"stale"
			)
		end)

		it("attachOwner compares epochs modulo 256", function()
			local state = setup()
			ReplicationActionTracker.resetBody(state, 2, 0)
			expect(ReplicationActionTracker.attachOwner(state, 2, 255, makeTarget())).to.equal(false)
			ReplicationActionTracker.resetBody(state, 2, 255)
			local wrapped = makeTarget()
			expect(ReplicationActionTracker.attachOwner(state, 2, 0, wrapped)).to.equal(true)
			ReplicationActionTracker.started(state, started({ epoch = 0 }))
			expect(#wrapped.plays).to.equal(1)
		end)

		it("attachOwner attaches when the epoch matches or is newer", function()
			local state = setup()
			ReplicationActionTracker.resetBody(state, 2, 1)
			local current = makeTarget()
			expect(ReplicationActionTracker.attachOwner(state, 2, 1, current)).to.equal(true)
			local newer = makeTarget()
			expect(ReplicationActionTracker.attachOwner(state, 2, 3, newer)).to.equal(true)
			ReplicationActionTracker.started(state, started({ epoch = 3 }))
			expect(#newer.plays).to.equal(1)
		end)

		it("keeps actions pending across a detach and plays them on the next rig", function()
			local state, clock = setup()
			ReplicationActionTracker.attach(state, 2, 1, makeTarget())
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.detach(state, 2)
			clock.ms = 10200
			local nextTarget = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, nextTarget)
			expect(nextTarget.plays[1].opts.startAt).to.be.near(0.2, 1e-6)
		end)

		it("forget drops the actions but keeps the epoch (the body left range)", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.forget(state, 2)
			expect(target.stops[1]).to.equal("leap")
			expect(ReplicationActionTracker.started(state, started({ epoch = 2 }))).to.equal("stale")
		end)

		-- Review Focus 1: the slot table's new epoch arrives first, the new epoch's Started next, and the owner
		-- rig (or the puppet) is rebuilt only later.
		it("plays a new epoch's action on the rebuilt rig after a respawn mid-action", function()
			local state, clock = setup()
			local oldRig = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, oldRig)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.resetBody(state, 2, 2)
			ReplicationActionTracker.detach(state, 2)
			clock.ms = 10100
			expect(ReplicationActionTracker.started(state, started({ epoch = 2, startMs = 10100 }))).to.equal("pending")
			local newRig = makeTarget()
			ReplicationActionTracker.attach(state, 2, 2, newRig)
			expect(oldRig.stops[1]).to.equal("leap")
			expect(#newRig.plays).to.equal(1)
		end)

		-- Review Focus 3: the server replays the action after the next Enter, with its original start.
		it("resumes at the right point when the body leaves range and comes back mid-action", function()
			local state, clock = setup()
			ReplicationActionTracker.attach(state, 2, 1, makeTarget())
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.detach(state, 2)
			ReplicationActionTracker.forget(state, 2)
			clock.ms = 10600
			local again = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, again)
			expect(ReplicationActionTracker.started(state, started())).to.equal("played")
			expect(again.plays[1].opts.startAt).to.be.near(0.6, 1e-6)
		end)

		it("remove forgets the body entirely (its slot was released)", function()
			local state = setup()
			ReplicationActionTracker.remove(state, 2)
			expect(ReplicationActionTracker.started(state, started({ epoch = 2 }))).to.equal("pending")
		end)
	end)

	describe("step", function()
		it("drops a one-shot when its time is up without stopping it (the clip ends by itself)", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			clock.ms = 11000
			ReplicationActionTracker.step(state)
			expect(#target.stops).to.equal(0)
			expect((ReplicationActionTracker.counts(state))).to.equal(0)
		end)

		it("stops an open-ended action at the safety cap", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, pose())
			clock.ms = 10000 + ReplicationStateTimingUtils.MAX_OPEN_STATE_MS
			ReplicationActionTracker.step(state)
			expect(target.stops[1]).to.equal("pose")
			expect(state.counters.capped).to.equal(1)
		end)
	end)

	describe("LOD freeze", function()
		it("re-plays running actions at their current point when the body unfreezes", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, pose())
			ReplicationActionTracker.setLive(state, 2, false)
			clock.ms = 10500
			ReplicationActionTracker.setLive(state, 2, true)
			expect(#target.plays).to.equal(2)
			expect(target.plays[2].opts.startAt).to.be.near(0.5, 1e-6)
		end)

		it("keeps an action that arrives while frozen pending until the body unfreezes", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.setLive(state, 2, false)
			expect(ReplicationActionTracker.started(state, started())).to.equal("pending")
			ReplicationActionTracker.setLive(state, 2, true)
			expect(#target.plays).to.equal(1)
		end)

		it("stops a held clip once its time is up while frozen, so unfreezing cannot resume it", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.setLive(state, 2, false)
			clock.ms = 11500
			ReplicationActionTracker.step(state)
			expect(target.stops[1]).to.equal("leap")
			ReplicationActionTracker.setLive(state, 2, true)
			expect(#target.plays).to.equal(1)
		end)

		-- Review Focus 2: a Stopped for a frozen puppet must stop its held track, or unfreezing resumes it.
		it("stops a held clip when a Stopped arrives while frozen, and does not re-play it", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, pose())
			ReplicationActionTracker.setLive(state, 2, false)
			expect(ReplicationActionTracker.stopped(state, { userId = 2, epoch = 1, layer = 2, startMs = 10000 })).to.equal(
				true
			)
			expect(target.stops[1]).to.equal("pose")
			ReplicationActionTracker.setLive(state, 2, true)
			expect(#target.plays).to.equal(1)
		end)

		it("drops an action that ended while frozen when the body unfreezes", function()
			local state, clock = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.setLive(state, 2, false)
			clock.ms = 11500
			ReplicationActionTracker.setLive(state, 2, true)
			expect(target.stops[1]).to.equal("leap")
			expect(#target.plays).to.equal(1)
		end)
	end)

	describe("play failures", function()
		it("counts a clip that fails to load and drops the action", function()
			local state = setup()
			ReplicationActionTracker.attach(state, 2, 1, makeTarget({ fail = "load-failed" }))
			expect(ReplicationActionTracker.started(state, started())).to.equal("failed")
			expect(state.counters.loadFailures).to.equal(1)
			expect((ReplicationActionTracker.counts(state))).to.equal(0)
		end)

		it("drops a one-shot the player says has already ended", function()
			local state = setup()
			ReplicationActionTracker.attach(state, 2, 1, makeTarget({ fail = "elapsed" }))
			expect(ReplicationActionTracker.started(state, started())).to.equal("expired")
		end)
	end)

	describe("readouts", function()
		it("reports a clip whose real length disagrees with its declaration, once per clip", function()
			local state, clock = setup()
			ReplicationActionTracker.attach(state, 2, 1, makeTarget({ length = 1.3 }))
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.step(state)
			expect(state.counters.lengthMismatches).to.equal(1)
			expect(#state.warnings).to.equal(1)
			clock.ms = 10100
			ReplicationActionTracker.started(state, started({ startMs = 10100 }))
			ReplicationActionTracker.step(state)
			expect(state.counters.lengthMismatches).to.equal(1)
		end)

		it("passes a clip within the tolerance", function()
			local state = setup()
			ReplicationActionTracker.attach(state, 2, 1, makeTarget({ length = 1.03 }))
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.step(state)
			expect(state.counters.lengthMismatches).to.equal(0)
		end)

		it("waits for the clip to load before checking its length", function()
			local state = setup()
			local target = makeTarget()
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			ReplicationActionTracker.step(state)
			expect(state.counters.lengthMismatches).to.equal(0)
			target.plays[1].clipLength = 1.3
			ReplicationActionTracker.step(state)
			expect(state.counters.lengthMismatches).to.equal(1)
		end)

		it("samples the gap between a track and its start time as drift", function()
			local state, clock = setup()
			local target = makeTarget({ length = 1 })
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, started())
			target.plays[1].time = 0.05
			clock.ms = 10100
			expect(ReplicationActionTracker.sampleDrift(state)).to.be.near(50, 1e-6)
			expect(state.counters.maxDriftMs).to.equal(50)
		end)

		it("measures a looped clip's drift across the loop seam", function()
			local state, clock = setup()
			local target = makeTarget({ length = 1 })
			ReplicationActionTracker.attach(state, 2, 1, target)
			ReplicationActionTracker.started(state, pose())
			target.plays[1].time = 0.01
			clock.ms = 10990
			expect(ReplicationActionTracker.sampleDrift(state)).to.be.near(20, 1e-6)
		end)
	end)
end
