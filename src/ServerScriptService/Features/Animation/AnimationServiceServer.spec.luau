--[=[
	AnimationServiceServer's grant surface against a fake "action" channel (the test seam), so no
	character or packet is needed. The channel stands in for AnimationGrantTracker: one state per layer
	key, `set` / `get` / `clear`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationService = require(ServerScriptService.Features.Animation.AnimationServiceServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" }

local function fakeChannel()
	local channel = { kind = "action", states = {}, sets = {}, clears = {}, nextResult = nil }
	channel.set = function(_self, player, key, data, startMs, durationMs)
		table.insert(
			channel.sets,
			{ player = player, key = key, data = data, startMs = startMs, durationMs = durationMs }
		)
		if channel.nextResult ~= nil then
			return channel.nextResult
		end
		local replacing = channel.states[key] ~= nil
		channel.states[key] = { key = key, data = data, startMs = startMs, durationMs = durationMs }
		return if replacing then "replaced" else "created"
	end
	channel.get = function(_self, _player, key)
		return channel.states[key]
	end
	channel.clear = function(_self, _player, key)
		local had = channel.states[key] ~= nil
		channel.states[key] = nil
		if had then
			table.insert(channel.clears, key)
		end
		return had
	end
	return channel
end

return function()
	local channel, previous

	beforeEach(function()
		channel = fakeChannel()
		previous = AnimationService:_setActionChannel(channel)
		AnimationService:_setRoll(function(count)
			return count -- always the highest variant
		end)
	end)

	afterEach(function()
		AnimationService:_setActionChannel(previous)
		AnimationService:_setRoll(nil)
	end)

	describe("play (grants)", function()
		it("refuses an unknown id before anything reaches the channel", function()
			local ok, reason = AnimationService:play(fakePlayer, "no-such-action")
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
			expect(#channel.sets).to.equal(0)
		end)

		it("refuses a registered entry that is not replicable", function()
			local ok = AnimationService:play(fakePlayer, "idle")
			expect(ok).to.equal(false)
			expect(#channel.sets).to.equal(0)
		end)

		it("grants on the entry's layer with the server's variant, stamped by the session clock", function()
			local def = AnimationRegistry.get("testleap")
			expect(AnimationService:play(fakePlayer, "testleap")).to.equal(true)
			local set = channel.sets[1]
			expect(set.player).to.equal(fakePlayer)
			expect(set.key).to.equal("full")
			expect(set.data.wireId).to.equal(def.wireId)
			expect(set.data.variant).to.equal(#def.variants)
			expect(set.startMs).to.be.a("number")
			expect(set.durationMs).to.equal(def.durationMs)
		end)

		it("honours a requested variant and speed, and shortens the duration with the speed", function()
			local def = AnimationRegistry.get("testleap")
			AnimationService:play(fakePlayer, "testleap", { speed = 2, variant = 0 })
			local set = channel.sets[1]
			expect(set.data.variant).to.equal(0)
			expect(set.data.speedMilli).to.equal(2000)
			expect(set.durationMs).to.equal(math.floor(def.durationMs / 2 + 0.5))
		end)

		it("grants a looped action open-ended", function()
			AnimationService:play(fakePlayer, "testpose")
			expect(channel.sets[1].key).to.equal("upper")
			expect(channel.sets[1].durationMs).to.equal(nil)
		end)

		-- Review Focus 5: `animationplay x testpose 1 1` asks for a variant the entry does not have.
		it("refuses a variant the entry does not have, before anything reaches the channel", function()
			local ok, reason = AnimationService:play(fakePlayer, "testpose", { variant = 1 })
			expect(ok).to.equal(false)
			expect(reason:find("variant", 1, true)).to.be.ok()
			expect(#channel.sets).to.equal(0)
		end)

		it("refuses a non-protected action while a protected one holds the layer", function()
			expect(AnimationService:play(fakePlayer, "testguard")).to.equal(true)
			local ok, reason = AnimationService:play(fakePlayer, "testleap")
			expect(ok).to.equal(false)
			expect(reason:find("protected", 1, true)).to.be.ok()
			expect(#channel.sets).to.equal(1)
		end)

		it("lets a protected action replace an attack on its layer", function()
			AnimationService:play(fakePlayer, "testleap")
			expect(AnimationService:play(fakePlayer, "testguard")).to.equal(true)
		end)

		it("keeps layers independent", function()
			AnimationService:play(fakePlayer, "testguard")
			expect(AnimationService:play(fakePlayer, "testpose")).to.equal(true)
		end)

		it("reports a player with no character", function()
			channel.nextResult = "no-body"
			local ok, reason = AnimationService:play(fakePlayer, "testleap")
			expect(ok).to.equal(false)
			expect(reason:find("no character", 1, true)).to.be.ok()
		end)
	end)

	describe("stop", function()
		it("stops by layer name", function()
			AnimationService:play(fakePlayer, "testpose")
			expect(AnimationService:stop(fakePlayer, "upper")).to.equal(true)
			expect(channel.clears[1]).to.equal("upper")
		end)

		it("stops by action id only while that action holds its layer", function()
			AnimationService:play(fakePlayer, "testleap")
			expect(AnimationService:stop(fakePlayer, "testguard")).to.equal(false)
			expect(AnimationService:stop(fakePlayer, "testleap")).to.equal(true)
		end)

		it("refuses something that is neither a layer nor a replicable action", function()
			local ok, reason = AnimationService:stop(fakePlayer, "idle")
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("reports an empty layer", function()
			expect(AnimationService:stop(fakePlayer, "overlay")).to.equal(false)
		end)
	end)

	describe("stopAttacks (the stop-attacks verb)", function()
		it("ends only attack-class actions", function()
			AnimationService:play(fakePlayer, "testleap")
			AnimationService:play(fakePlayer, "testpose")
			expect(AnimationService:stopAttacks(fakePlayer)).to.equal(1)
			expect(channel.clears[1]).to.equal("full")
			expect(channel.states.upper).to.be.ok()
		end)
	end)

	describe("stopAll (the hook Death and Ragdoll call)", function()
		it("ends every grant on the character whatever its class", function()
			AnimationService:play(fakePlayer, "testguard") -- protected, full
			AnimationService:play(fakePlayer, "testpose") -- upper
			expect(AnimationService:stopAll(fakePlayer)).to.equal(2)
			expect(#channel.clears).to.equal(2)
			expect(channel.states.full).to.equal(nil)
			expect(channel.states.upper).to.equal(nil)
		end)

		it("reports zero for a character with nothing playing", function()
			expect(AnimationService:stopAll(fakePlayer)).to.equal(0)
			expect(#channel.clears).to.equal(0)
		end)
	end)

	describe("validateStopClass", function()
		it("refuses to bulk-stop protected and ambient, accepts attack", function()
			expect(AnimationService:validateStopClass("protected")).to.equal(false)
			expect(AnimationService:validateStopClass("ambient")).to.equal(false)
			expect(AnimationService:validateStopClass("attack")).to.equal(true)
		end)

		it("refuses an unknown class string outright", function()
			expect(AnimationService:validateStopClass("sometimes")).to.equal(false)
		end)
	end)
end
