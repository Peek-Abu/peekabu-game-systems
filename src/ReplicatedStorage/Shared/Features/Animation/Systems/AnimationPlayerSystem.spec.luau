--[=[
	Unit tests for AnimationPlayerSystem — the pure core of track ownership. Everything runs against a
	fabricated animator seam and a fabricated registry resolver: no Studio, no Animator, no assets.

	The seam fake records loads and play/stop calls so the cache contract ("a slide costs one load
	per character lifetime, not one per slide") is asserted, not assumed.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)

-- A fabricated AnimationDef. Interruption defaults to ambient, like locomotion.
local function makeDef(assetId, overrides)
	local def = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Core,
		looped = false,
		interruption = "ambient",
	}
	for key, value in overrides or {} do
		def[key] = value
	end
	return def
end

-- A fabricated seam whose tracks record what happened to them.
local function makeSeam(options)
	options = options or {}
	local seam = {
		loads = {},
		tracks = {},
		removedCallbacks = {},
	}
	seam.load = function(assetId)
		if options.failLoads then
			return nil
		end
		table.insert(seam.loads, assetId)
		local track = {
			assetId = assetId,
			playCalls = 0,
			stopCalls = 0,
			playing = false,
			speed = 1,
			priority = nil,
			looped = nil,
			endedCallbacks = {},
			markerCallbacks = {},
			timePos = 0,
			seeks = {},
			clipLength = options.length or 0, -- 0 = not loaded yet, like a real track
		}
		track.play = function(fadeTime, weight, speed)
			track.playCalls += 1
			track.playing = true
			track.lastFade = fadeTime
			track.lastWeight = weight
			track.speed = speed
		end
		track.stop = function(fadeTime)
			track.stopCalls += 1
			track.playing = false
			track.lastStopFade = fadeTime
			for _, callback in track.endedCallbacks do
				callback()
			end
		end
		track.adjustSpeed = function(speed)
			track.speed = speed
		end
		track.setPriority = function(priority)
			track.priority = priority
		end
		track.setLooped = function(looped)
			track.looped = looped
		end
		track.isPlaying = function()
			return track.playing
		end
		track.onEnded = function(callback)
			table.insert(track.endedCallbacks, callback)
			return function() end
		end
		track.onMarker = function(markerName, callback)
			track.markerCallbacks[markerName] = callback
			return function()
				track.markerCallbacks[markerName] = nil
			end
		end
		track.setTimePosition = function(seconds)
			track.timePos = seconds
			table.insert(track.seeks, seconds)
		end
		track.timePosition = function()
			return track.timePos
		end
		track.length = function()
			return track.clipLength
		end
		table.insert(seam.tracks, track)
		return track
	end
	seam.onRemoved = function(callback)
		table.insert(seam.removedCallbacks, callback)
		return function() end
	end
	seam.fireRemoved = function()
		for _, callback in seam.removedCallbacks do
			callback()
		end
	end
	return seam
end

local function makeResolver(defs)
	return function(id)
		return defs[id]
	end
end

return function()
	local DEFS = {
		idle = makeDef("rbxassetid://1", { looped = true }),
		swing = makeDef("rbxassetid://2", { interruption = "attack", priority = Enum.AnimationPriority.Action }),
		dodge = makeDef("rbxassetid://3", { interruption = "protected" }),
		reaction = makeDef("rbxassetid://10", {
			interruption = "protected",
			variants = { "rbxassetid://11", "rbxassetid://12" },
		}),
		-- Same asset as swing, different entry — the run/combatrun aliasing case.
		swingalias = makeDef("rbxassetid://2", { looped = true }),
	}

	local function makePlayer(seam, roll)
		return AnimationPlayerSystem.new(seam, makeResolver(DEFS), roll)
	end

	describe("play", function()
		it("loads once and replays from the cache — the per-play-LoadAnimation disease is dead", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle = player:play("swing")
			expect(handle).to.be.ok()
			handle:stop()
			player:play("swing")
			player:play("swing")
			expect(#seam.loads).to.equal(1)
			local counters = player:counters()
			expect(counters.loads).to.equal(1)
			expect(counters.hits).to.equal(2)
		end)

		it("applies the registry's priority and looped to the loaded track", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing")
			expect(seam.tracks[1].priority).to.equal(Enum.AnimationPriority.Action)
			expect(seam.tracks[1].looped).to.equal(false)
			player:play("idle")
			expect(seam.tracks[2].looped).to.equal(true)
		end)

		it("resolves play options over registry defaults", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing", { fadeTime = 0.25, speed = 2, priority = Enum.AnimationPriority.Action4 })
			expect(seam.tracks[1].lastFade).to.equal(0.25)
			expect(seam.tracks[1].speed).to.equal(2)
			expect(seam.tracks[1].priority).to.equal(Enum.AnimationPriority.Action4)
		end)

		it("does not re-Play an already-playing looped track (no fade thrash)", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle")
			player:play("idle")
			player:play("idle")
			expect(seam.tracks[1].playCalls).to.equal(1)
		end)

		it("restarts a non-looped track on replay", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing")
			player:play("swing")
			expect(seam.tracks[1].playCalls).to.equal(2)
		end)

		it("returns nil and a reason for an unknown id, without throwing", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle, reason = player:play("no-such-id")
			expect(handle).to.equal(nil)
			expect(reason).to.equal("unknown-id")
		end)

		it("returns nil and a reason when the seam cannot load", function()
			local seam = makeSeam({ failLoads = true })
			local player = makePlayer(seam)
			local handle, reason = player:play("swing")
			expect(handle).to.equal(nil)
			expect(reason).to.equal("load-failed")
		end)
	end)

	describe("variants", function()
		it("rolls one of assetId + variants using the injected roll", function()
			local seam = makeSeam()
			local player = makePlayer(seam, function(_count)
				return 3 -- always the last option
			end)
			player:play("reaction")
			expect(seam.tracks[1].assetId).to.equal("rbxassetid://12")
		end)

		-- Qodo PR #13 finding: replaying an id whose variant roll lands on a DIFFERENT asset must
		-- stop the outgoing track, or it plays on as a ghost no stop verb can reach.
		it("stops the previous track when a replay rolls a different variant", function()
			local seam = makeSeam()
			local rollValue = 1
			local player = makePlayer(seam, function(_count)
				return rollValue
			end)
			player:play("reaction")
			rollValue = 2
			player:play("reaction")
			expect(seam.tracks[1].stopCalls).to.equal(1)
			expect(seam.tracks[1].playing).to.equal(false)
			expect(seam.tracks[2].playing).to.equal(true)
			expect(#player:playing()).to.equal(1)
		end)

		it("caches per rolled asset — two variants are two loads, replaying one is a hit", function()
			local seam = makeSeam()
			local rollValue = 1
			local player = makePlayer(seam, function(_count)
				return rollValue
			end)
			local first = player:play("reaction")
			first:stop()
			rollValue = 2
			local second = player:play("reaction")
			second:stop()
			rollValue = 1
			player:play("reaction")
			expect(#seam.loads).to.equal(2)
			expect(player:counters().hits).to.equal(1)
		end)
	end)

	-- R3: a replicated action plays the SERVER's variant on every screen (the spike saw owner and viewers
	-- roll different clips).
	describe("chosen variant", function()
		it("plays the requested variant instead of rolling", function()
			local seam = makeSeam()
			local player = makePlayer(seam, function(_count)
				error("a requested variant must not roll")
			end)
			player:play("reaction", { variant = 2 })
			expect(seam.tracks[1].assetId).to.equal("rbxassetid://12")
		end)

		it("treats variant 0 as the entry's own asset", function()
			local seam = makeSeam()
			local player = makePlayer(seam, function(_count)
				return 3
			end)
			player:play("reaction", { variant = 0 })
			expect(seam.tracks[1].assetId).to.equal("rbxassetid://10")
		end)

		it("refuses a variant out of range or not whole, before loading anything", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle, reason = player:play("reaction", { variant = 3 })
			expect(handle).to.equal(nil)
			expect(reason).to.equal("bad-variant")
			expect(select(2, player:play("reaction", { variant = 1.5 }))).to.equal("bad-variant")
			expect(select(2, player:play("reaction", { variant = -1 }))).to.equal("bad-variant")
			expect(select(2, player:play("swing", { variant = 1 }))).to.equal("bad-variant")
			expect(#seam.loads).to.equal(0)
		end)
	end)

	-- R3: a viewer joining an action mid-way starts the clip at the owner's point in it.
	describe("start point", function()
		it("starts a one-shot that many seconds into the clip", function()
			local seam = makeSeam({ length = 1.2 })
			local player = makePlayer(seam)
			player:play("swing", { startAt = 0.4 })
			expect(seam.tracks[1].playCalls).to.equal(1)
			expect(seam.tracks[1].timePos).to.be.near(0.4, 1e-6)
		end)

		it("wraps the start point of a looped clip", function()
			local seam = makeSeam({ length = 1 })
			local player = makePlayer(seam)
			player:play("idle", { startAt = 2.25 })
			expect(seam.tracks[1].timePos).to.be.near(0.25, 1e-6)
		end)

		it("refuses a one-shot whose start point is past its end, without playing", function()
			local seam = makeSeam({ length = 1 })
			local player = makePlayer(seam)
			local handle, reason = player:play("swing", { startAt = 1.5 })
			expect(handle).to.equal(nil)
			expect(reason).to.equal("elapsed")
			expect(seam.tracks[1].playCalls).to.equal(0)
			expect(#player:playing()).to.equal(0)
		end)

		it("seeks as asked while the clip's length is not known yet", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing", { startAt = 0.4 })
			expect(seam.tracks[1].timePos).to.be.near(0.4, 1e-6)
		end)

		it("does not seek when no start point is given", function()
			local seam = makeSeam({ length = 1 })
			local player = makePlayer(seam)
			player:play("swing")
			expect(#seam.tracks[1].seeks).to.equal(0)
		end)

		it("re-seeks an already-playing looped clip instead of restarting it", function()
			local seam = makeSeam({ length = 2 })
			local player = makePlayer(seam)
			player:play("idle")
			player:play("idle", { startAt = 0.5 })
			expect(seam.tracks[1].playCalls).to.equal(1)
			expect(seam.tracks[1].timePos).to.be.near(0.5, 1e-6)
		end)
	end)

	describe("handle time and length", function()
		it("reads the track's time position and length through the handle", function()
			local seam = makeSeam({ length = 1.5 })
			local player = makePlayer(seam)
			local handle = player:play("swing", { startAt = 0.3 })
			expect(handle:timePosition()).to.be.near(0.3, 1e-6)
			expect(handle:length()).to.equal(1.5)
		end)

		it("reports time position 0 from a superseded handle", function()
			local seam = makeSeam({ length = 1.5 })
			local player = makePlayer(seam)
			local first = player:play("swing", { startAt = 0.3 })
			player:play("swing", { startAt = 0.6 })
			expect(first:timePosition()).to.equal(0)
		end)
	end)

	-- R3 puppet LOD (speed mode): a frozen puppet holds its pose with every track at speed 0.
	describe("pause", function()
		it("holds every live track at speed 0 and resumes each at its own speed", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing", { speed = 2 })
			player:play("idle", { speed = 0.5 })
			player:setPaused(true)
			expect(player:isPaused()).to.equal(true)
			expect(seam.tracks[1].speed).to.equal(0)
			expect(seam.tracks[2].speed).to.equal(0)
			player:setPaused(false)
			expect(seam.tracks[1].speed).to.equal(2)
			expect(seam.tracks[2].speed).to.equal(0.5)
		end)

		it("starts a play made while paused held at speed 0", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:setPaused(true)
			player:play("swing", { speed = 1.5 })
			expect(seam.tracks[1].speed).to.equal(0)
			player:setPaused(false)
			expect(seam.tracks[1].speed).to.equal(1.5)
		end)

		it("remembers a speed change made while paused", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle = player:play("swing")
			player:setPaused(true)
			handle:adjustSpeed(3)
			expect(seam.tracks[1].speed).to.equal(0)
			player:setPaused(false)
			expect(seam.tracks[1].speed).to.equal(3)
			expect(player:playing()[1].speed).to.equal(3)
		end)
	end)

	describe("asset aliasing", function()
		-- Qodo PR #13 finding: the cache is per (registry id, asset), so two entries sharing an
		-- asset id get INDEPENDENT tracks — no priority/looped/stop cross-talk.
		it("gives two entries sharing an asset id independent tracks", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing")
			player:play("swingalias")
			expect(#seam.loads).to.equal(2)
			expect(#player:playing()).to.equal(2)
			player:stop("swing")
			expect(seam.tracks[1].stopCalls).to.equal(1)
			expect(seam.tracks[1].playing).to.equal(false)
			expect(seam.tracks[2].playing).to.equal(true)
			expect(#player:playing()).to.equal(1)
		end)
	end)

	describe("handles", function()
		it("stop stops the underlying track and drops it from playing()", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle = player:play("swing")
			expect(#player:playing()).to.equal(1)
			handle:stop(0.3)
			expect(seam.tracks[1].lastStopFade).to.equal(0.3)
			expect(#player:playing()).to.equal(0)
		end)

		it("adjustSpeed reaches the track", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle = player:play("swing")
			handle:adjustSpeed(1.5)
			expect(seam.tracks[1].speed).to.equal(1.5)
		end)

		it("onMarker subscribes through to the track and disconnects", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle = player:play("swing")
			local got = nil
			local disconnect = handle:onMarker("hit", function(param)
				got = param
			end)
			seam.tracks[1].markerCallbacks.hit("right")
			expect(got).to.equal("right")
			disconnect()
			expect(seam.tracks[1].markerCallbacks.hit).to.equal(nil)
		end)
	end)

	describe("stale handles", function()
		-- Qodo PR #13 finding: a handle from a superseded play must not reach through to the
		-- track that replaced it — otherwise an old handle's stop() kills a newer replay and its
		-- adjustSpeed() desyncs the panel from reality.
		it("a superseded handle cannot stop the newer play", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local stale = player:play("swing")
			player:play("swing")
			stale:stop()
			expect(#player:playing()).to.equal(1)
			expect(seam.tracks[1].playing).to.equal(true)
		end)

		it("a superseded handle cannot adjust the newer play's speed", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local stale = player:play("swing")
			player:play("swing", { speed = 1 })
			stale:adjustSpeed(3)
			expect(player:playing()[1].speed).to.equal(1)
			expect(seam.tracks[1].speed).to.equal(1)
		end)

		it("reports isPlaying false once superseded", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local stale = player:play("swing")
			player:play("swing")
			expect(stale:isPlaying()).to.equal(false)
		end)

		it("the CURRENT handle still works normally", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing")
			local current = player:play("swing")
			current:adjustSpeed(2)
			expect(player:playing()[1].speed).to.equal(2)
			current:stop()
			expect(#player:playing()).to.equal(0)
		end)
	end)

	describe("bookkeeping", function()
		it("a track that ends on its own leaves playing() but stays cached", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("swing")
			-- The seam fake fires ended callbacks from stop; simulate a natural end the same way.
			seam.tracks[1].stop(0)
			expect(#player:playing()).to.equal(0)
			player:play("swing")
			expect(#seam.loads).to.equal(1)
		end)

		it("playing() reports id, declared class, looped, priority, weight and speed for the panel", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle", { speed = 1.25, weight = 0.8 })
			local snapshot = player:playing()
			expect(#snapshot).to.equal(1)
			expect(snapshot[1].id).to.equal("idle")
			expect(snapshot[1].interruption).to.equal("ambient")
			expect(snapshot[1].looped).to.equal(true)
			expect(snapshot[1].priority).to.equal(Enum.AnimationPriority.Core)
			expect(snapshot[1].weight).to.equal(0.8)
			expect(snapshot[1].speed).to.equal(1.25)
		end)

		it("adjustSpeed through a handle is reflected in playing()", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local handle = player:play("idle")
			handle:adjustSpeed(2)
			expect(player:playing()[1].speed).to.equal(2)
		end)
	end)

	describe("warm", function()
		it("loads into the cache without playing, so the first real play is a hit with no hitch", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			local ok = player:warm("swing")
			expect(ok).to.equal(true)
			expect(#seam.loads).to.equal(1)
			expect(seam.tracks[1].playCalls).to.equal(0)
			player:play("swing")
			local counters = player:counters()
			expect(counters.loads).to.equal(1)
			expect(counters.hits).to.equal(1)
		end)

		it("warms every variant of a variant set", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:warm("reaction")
			expect(#seam.loads).to.equal(3)
		end)

		it("is idempotent and reports unknown ids without throwing", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:warm("swing")
			player:warm("swing")
			expect(#seam.loads).to.equal(1)
			local ok, reason = player:warm("no-such-id")
			expect(ok).to.equal(false)
			expect(reason).to.equal("unknown-id")
		end)
	end)

	describe("stopClass", function()
		it("stops exactly the declared class", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle")
			player:play("swing")
			player:play("dodge")
			local result = player:stopClass("attack")
			expect(result.refused).to.equal(false)
			expect(#result.stopped).to.equal(1)
			expect(result.stopped[1]).to.equal("swing")
			expect(#player:playing()).to.equal(2)
		end)

		it("refuses to bulk-stop protected — a dodge must never die to a stop-attacks verb", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("dodge")
			local result = player:stopClass("protected")
			expect(result.refused).to.equal(true)
			expect(#result.stopped).to.equal(0)
			expect(#player:playing()).to.equal(1)
		end)

		it("refuses to bulk-stop ambient — a combat stop must never kill locomotion", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle")
			local result = player:stopClass("ambient")
			expect(result.refused).to.equal(true)
			expect(#player:playing()).to.equal(1)
		end)
	end)

	describe("stopAll and lifecycle", function()
		it("stopAll stops everything regardless of class (the kill switch path)", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle")
			player:play("dodge")
			player:stopAll(0)
			expect(#player:playing()).to.equal(0)
		end)

		it("destroy stops tracks, clears the cache, and refuses further plays", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle")
			player:destroy()
			expect(#player:playing()).to.equal(0)
			local handle, reason = player:play("idle")
			expect(handle).to.equal(nil)
			expect(reason).to.equal("destroyed")
		end)

		it("destroys itself when the seam reports the animator gone", function()
			local seam = makeSeam()
			local player = makePlayer(seam)
			player:play("idle")
			seam.fireRemoved()
			local handle, reason = player:play("idle")
			expect(handle).to.equal(nil)
			expect(reason).to.equal("destroyed")
		end)
	end)
end
