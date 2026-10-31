--[=[
	Unit tests for AnimationFidgetSystem: the wait, what cancels a fidget, and the no-repeat rule. Runs against a fake
	player with time passed in, so every window is deterministic.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationFidgetSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationFidgetSystem)

local function makeFakePlayer()
	local fake = { plays = {} }
	fake.play = function(_self, id, opts)
		local handle = { id = id, opts = opts, stopped = false, finished = false }
		handle.stop = function(_handleSelf, fadeTime)
			handle.stopped = true
			handle.stopFade = fadeTime
		end
		handle.isPlaying = function(_handleSelf)
			return not handle.stopped and not handle.finished
		end
		table.insert(fake.plays, handle)
		return handle, nil
	end
	return fake
end

local IDLE = { pose = "idle", blocked = false }

return function()
	local function make(fake, clips, seed)
		return AnimationFidgetSystem.new(
			fake,
			{ clips = clips or { "clip" }, minDelay = 8, maxDelay = 15, random = Random.new(seed or 1) }
		)
	end

	-- Advances `system` in idle, one second at a time.
	local function run(system, from, to)
		for now = from, to do
			system:update(now, IDLE)
		end
	end

	describe("the wait", function()
		it("plays nothing before 8 seconds of standing still", function()
			local fake = makeFakePlayer()
			run(make(fake), 0, 7)
			expect(#fake.plays).to.equal(0)
		end)

		it("plays one clip by 16 seconds of standing still", function()
			for seed = 1, 20 do
				local fake = makeFakePlayer()
				run(make(fake, nil, seed), 0, 16)
				expect(#fake.plays).to.equal(1)
				expect(fake.plays[1].id).to.equal("clip")
			end
		end)

		it("waits again after a clip ends, not while it plays", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 60)
			expect(#fake.plays).to.equal(1)
			fake.plays[1].finished = true
			run(system, 61, 68)
			expect(#fake.plays).to.equal(1)
			run(system, 69, 77)
			expect(#fake.plays).to.equal(2)
		end)
	end)

	describe("the idle loop", function()
		local function idleAt(phase)
			return { pose = "idle", blocked = false, idlePhase = phase }
		end

		it("holds a due clip until the idle comes round to its first pose", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			for now = 0, 20 do
				system:update(now, idleAt(now * 0.1))
			end
			system:update(21, idleAt(2.5))
			expect(#fake.plays).to.equal(0)
			system:update(22, idleAt(0.01))
			expect(#fake.plays).to.equal(1)
		end)

		it("does not count a turn of the loop from before the clip was due", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			system:update(0, idleAt(2))
			system:update(1, idleAt(0.1))
			system:update(100, idleAt(0.2))
			expect(#fake.plays).to.equal(0)
		end)

		it("forgets the loop while blocked, so a new idle track is not a turn", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			system:update(0, idleAt(2))
			system:update(100, idleAt(2.5))
			system:update(101, { pose = "idle", blocked = true, idlePhase = 2.9 })
			system:update(102, idleAt(0))
			expect(#fake.plays).to.equal(0)
		end)

		it("plays at once when it cannot see the idle", function()
			local fake = makeFakePlayer()
			run(make(fake), 0, 16)
			expect(#fake.plays).to.equal(1)
		end)
	end)

	describe("what cancels it", function()
		it("resets the wait on any other pose", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 7)
			system:update(7.5, { pose = "walk", blocked = false })
			run(system, 8, 15)
			expect(#fake.plays).to.equal(0)
		end)

		it("resets the wait while blocked", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 7)
			system:update(7.5, { pose = "idle", blocked = true })
			run(system, 8, 15)
			expect(#fake.plays).to.equal(0)
		end)

		it("does not wait on a nil pose", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			for now = 0, 30 do
				system:update(now, { pose = nil, blocked = false })
			end
			expect(#fake.plays).to.equal(0)
		end)

		it("stops a playing clip with a short fade when the pose changes", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 16)
			system:update(17, { pose = "walk", blocked = false })
			expect(fake.plays[1].stopped).to.equal(true)
			expect(fake.plays[1].stopFade).to.equal(AnimationFidgetSystem.FADE)
		end)

		it("stops a playing clip when blocked, and waits the full window after", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 16)
			system:update(17, { pose = "idle", blocked = true })
			expect(fake.plays[1].stopped).to.equal(true)
			run(system, 18, 25)
			expect(#fake.plays).to.equal(1)
		end)

		it("stops a playing clip on destroy and plays nothing after", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 16)
			system:destroy()
			expect(fake.plays[1].stopped).to.equal(true)
			run(system, 17, 60)
			expect(#fake.plays).to.equal(1)
		end)
	end)

	describe("the clip", function()
		it("never plays the same clip twice in a row when it has a choice", function()
			local fake = makeFakePlayer()
			local system = make(fake, { "a", "b", "c" })
			local now = 0
			for _ = 1, 40 do
				for _ = 1, 17 do
					now += 1
					system:update(now, IDLE)
				end
				local last = fake.plays[#fake.plays]
				if last ~= nil then
					last.finished = true
				end
			end
			expect(#fake.plays > 10).to.equal(true)
			for index = 2, #fake.plays do
				expect(fake.plays[index].id).never.to.equal(fake.plays[index - 1].id)
			end
		end)

		it("repeats its only clip", function()
			local fake = makeFakePlayer()
			local system = make(fake)
			run(system, 0, 16)
			fake.plays[1].finished = true
			run(system, 17, 40)
			expect(#fake.plays).to.equal(2)
		end)

		it("does nothing without clips", function()
			local fake = makeFakePlayer()
			run(make(fake, {}), 0, 60)
			expect(#fake.plays).to.equal(0)
		end)

		it("tries again after a clip fails to play", function()
			local fake = makeFakePlayer()
			local realPlay = fake.play
			local failed = false
			fake.play = function(self, id, opts)
				if not failed then
					failed = true
					return nil, "load-failed"
				end
				return realPlay(self, id, opts)
			end
			run(make(fake), 0, 40)
			expect(#fake.plays).to.equal(1)
		end)
	end)

	describe("loopTime", function()
		local function track(assetId, time, playing)
			return { Animation = { AnimationId = assetId }, IsPlaying = playing ~= false, TimePosition = time }
		end

		it("reads the time of the clip it is asked for", function()
			local tracks = { track("rbxassetid://1", 3), track("rbxassetid://2", 1.5) }
			expect(AnimationFidgetSystem.loopTime(tracks, "rbxassetid://2")).to.equal(1.5)
		end)

		it("is nil when the clip is not playing", function()
			expect(AnimationFidgetSystem.loopTime({ track("rbxassetid://2", 1, false) }, "rbxassetid://2")).never.to.be.ok()
			expect(AnimationFidgetSystem.loopTime({}, "rbxassetid://2")).never.to.be.ok()
			expect(AnimationFidgetSystem.loopTime({ track("rbxassetid://2", 1) }, nil)).never.to.be.ok()
		end)
	end)

	describe("actionPlaying", function()
		local function track(priority, assetId, playing)
			return { Priority = priority, Animation = { AnimationId = assetId }, IsPlaying = playing ~= false }
		end

		it("sees a playing Action clip", function()
			local tracks = { track(Enum.AnimationPriority.Action, "rbxassetid://1") }
			expect(AnimationFidgetSystem.actionPlaying(tracks, {})).to.equal(true)
		end)

		it("sees the higher Action priorities", function()
			for _, priority in
				{
					Enum.AnimationPriority.Action2,
					Enum.AnimationPriority.Action3,
					Enum.AnimationPriority.Action4,
				}
			do
				expect(AnimationFidgetSystem.actionPlaying({ track(priority, "rbxassetid://1") }, {})).to.equal(true)
			end
		end)

		it("ignores the idle and other low clips", function()
			local tracks = {
				track(Enum.AnimationPriority.Core, "rbxassetid://1"),
				track(Enum.AnimationPriority.Idle, "rbxassetid://2"),
				track(Enum.AnimationPriority.Movement, "rbxassetid://3"),
			}
			expect(AnimationFidgetSystem.actionPlaying(tracks, {})).to.equal(false)
		end)

		it("ignores the fidget's own clips", function()
			local tracks = { track(Enum.AnimationPriority.Action, "rbxassetid://7") }
			expect(AnimationFidgetSystem.actionPlaying(tracks, { "rbxassetid://7" })).to.equal(false)
		end)

		it("ignores a clip that is no longer playing", function()
			local tracks = { track(Enum.AnimationPriority.Action, "rbxassetid://1", false) }
			expect(AnimationFidgetSystem.actionPlaying(tracks, {})).to.equal(false)
		end)
	end)
end
