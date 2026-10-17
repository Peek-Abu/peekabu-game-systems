--[=[
	Unit tests for AnimationLocomotionSystem — the pure state→pose core that replaces the forked Roblox
	Animate script. Everything runs against a fake AnimationPlayerSystem; time is passed in explicitly, so
	the jump window and every transition are deterministic.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)

-- A fake AnimationPlayerSystem recording plays/stops. Handles record adjustSpeed.
local function makeFakePlayer(options)
	options = options or {}
	local fake = {
		plays = {},
		stops = {},
		stopAllCalls = 0,
	}
	fake.play = function(_self, id, opts)
		if options.failIds and options.failIds[id] then
			return nil, "unknown-id"
		end
		local handle = {
			id = id,
			opts = opts or {},
			adjustments = {},
			stopped = false,
		}
		handle.stop = function(_handleSelf, fadeTime)
			handle.stopped = true
			handle.stopFade = fadeTime
		end
		handle.adjustSpeed = function(_handleSelf, speed)
			table.insert(handle.adjustments, speed)
		end
		handle.isPlaying = function(_handleSelf)
			return not handle.stopped
		end
		handle.onMarker = function(_handleSelf, _markerName, _callback)
			return function() end
		end
		table.insert(fake.plays, handle)
		return handle, nil
	end
	fake.stop = function(_self, id, fadeTime)
		table.insert(fake.stops, { id = id, fadeTime = fadeTime })
		return true
	end
	fake.stopAll = function(_self, _fadeTime)
		fake.stopAllCalls += 1
	end
	return fake
end

local function lastPlay(fake)
	return fake.plays[#fake.plays]
end

return function()
	local function makeAnimator(fake, config)
		return AnimationLocomotionSystem.new(fake, config)
	end

	describe("movement poses", function()
		it("plays idle when standing still", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			expect(animator:currentPose()).to.equal("idle")
			expect(lastPlay(fake).id).to.equal("idle")
		end)

		it("walks below the walk/run threshold and runs above it, speed-scaled", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { walkRunThreshold = 10, walkScale = 16, runScale = 16 })
			animator:handleEvent("running", 8, 0)
			expect(animator:currentPose()).to.equal("walk")
			expect(lastPlay(fake).opts.speed).to.be.near(8 / 16, 1e-6)
			animator:handleEvent("running", 20, 1)
			expect(animator:currentPose()).to.equal("run")
			expect(lastPlay(fake).opts.speed).to.be.near(20 / 16, 1e-6)
		end)

		it("adjusts speed WITHOUT replaying when the pose is unchanged (no fade thrash)", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { walkRunThreshold = 10, walkScale = 16 })
			animator:handleEvent("running", 6, 0)
			animator:handleEvent("running", 8, 1)
			expect(#fake.plays).to.equal(1)
			local handle = fake.plays[1]
			expect(#handle.adjustments).to.equal(1)
			expect(handle.adjustments[1]).to.be.near(8 / 16, 1e-6)
		end)

		it("stops the previous pose when switching", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			animator:handleEvent("running", 20, 1)
			expect(#fake.stops).to.equal(1)
			expect(fake.stops[1].id).to.equal("idle")
		end)
	end)

	describe("jump and fall", function()
		it("plays jump on jumping and holds it through the jump window", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
			animator:handleEvent("jumping", nil, 10)
			expect(animator:currentPose()).to.equal("jump")
			animator:handleEvent("freefall", nil, 10.1)
			expect(animator:currentPose()).to.equal("jump")
		end)

		it("falls once the jump window has elapsed", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
			animator:handleEvent("jumping", nil, 10)
			animator:handleEvent("freefall", nil, 10.5)
			expect(animator:currentPose()).to.equal("fall")
		end)

		it("falls immediately in freefall with no preceding jump", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("freefall", nil, 5)
			expect(animator:currentPose()).to.equal("fall")
		end)
	end)

	-- The long-fall T-pose fix: the Humanoid reports Freefall ONCE, usually inside the jump window. Before
	-- the fix that freefall was dropped, and once the one-shot jump clip ended nothing played at all.
	describe("a freefall inside the jump window", function()
		it("plays the fall pose when the jump window ends", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
			animator:handleEvent("jumping", nil, 10)
			animator:handleEvent("freefall", nil, 10.1)
			animator:update(10.2)
			expect(animator:currentPose()).to.equal("jump")
			animator:update(10.31)
			expect(animator:currentPose()).to.equal("fall")
		end)

		it("plays the fall pose once, not on every later update", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
			animator:handleEvent("jumping", nil, 10)
			animator:handleEvent("freefall", nil, 10.1)
			animator:update(10.31)
			animator:update(10.5)
			animator:update(12)
			expect(#fake.plays).to.equal(2) -- jump, then fall
			expect(lastPlay(fake).id).to.equal("fall")
		end)

		it("forgets the remembered fall when the body lands inside the window", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
			animator:handleEvent("jumping", nil, 10)
			animator:handleEvent("freefall", nil, 10.1)
			animator:handleEvent("running", 0, 10.2)
			animator:update(10.5)
			expect(animator:currentPose()).to.equal("idle")
		end)

		it("a second jump restarts the window and the fall waits for it", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { jumpDuration = 0.3 })
			animator:handleEvent("jumping", nil, 10)
			animator:handleEvent("freefall", nil, 10.1)
			animator:handleEvent("jumping", nil, 10.25)
			animator:handleEvent("freefall", nil, 10.3)
			animator:update(10.5)
			expect(animator:currentPose()).to.equal("jump")
			animator:update(10.6)
			expect(animator:currentPose()).to.equal("fall")
		end)

		it("does nothing on update when no fall is remembered", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 20, 0)
			animator:update(5)
			expect(animator:currentPose()).to.equal("run")
			expect(#fake.plays).to.equal(1)
		end)

		it("forgets the remembered fall when disabled, overridden or dead", function()
			local disabled = makeAnimator(makeFakePlayer(), { jumpDuration = 0.3 })
			disabled:handleEvent("jumping", nil, 10)
			disabled:handleEvent("freefall", nil, 10.1)
			disabled:setEnabled(false)
			disabled:setEnabled(true)
			disabled:update(11)
			expect(disabled:currentPose()).to.equal("idle")

			local overridden = makeAnimator(makeFakePlayer(), { jumpDuration = 0.3 })
			overridden:handleEvent("jumping", nil, 10)
			overridden:handleEvent("freefall", nil, 10.1)
			overridden:setPoseOverride("sneakidle")
			overridden:clearPoseOverride()
			overridden:update(11)
			expect(overridden:currentPose()).to.equal("idle")

			local dead = makeAnimator(makeFakePlayer(), { jumpDuration = 0.3 })
			dead:handleEvent("jumping", nil, 10)
			dead:handleEvent("freefall", nil, 10.1)
			dead:handleEvent("died", nil, 10.2)
			dead:update(11)
			expect(dead:currentPose()).to.equal(nil)
		end)
	end)

	describe("stride play-rate clamp (puppets, spec §6.8)", function()
		it("clamps the walk and run rate to the configured range", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(
				fake,
				{ walkRunThreshold = 18, walkScale = 16, runScale = 16, minRate = 0.7, maxRate = 1.4 }
			)
			animator:handleEvent("running", 4, 0)
			expect(lastPlay(fake).opts.speed).to.be.near(0.7, 1e-6)
			animator:handleEvent("running", 40, 1)
			expect(lastPlay(fake).opts.speed).to.be.near(1.4, 1e-6)
		end)

		it("leaves the rate unclamped by default (the owner's rig)", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { walkScale = 16 })
			animator:handleEvent("running", 4, 0)
			expect(lastPlay(fake).opts.speed).to.be.near(0.25, 1e-6)
		end)

		it("caps walk and run separately when per-pose maximums are set", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, {
				walkRunThreshold = 18,
				walkScale = 1.27,
				runScale = 1.52,
				minRate = 0.6,
				maxRate = 9,
				walkMaxRate = 2.5,
				runMaxRate = 3,
			})
			animator:handleEvent("running", 16, 0)
			expect(lastPlay(fake).opts.speed).to.be.near(2.5, 1e-6)
			animator:handleEvent("running", 24, 1)
			expect(lastPlay(fake).opts.speed).to.be.near(3, 1e-6)
			animator:handleEvent("running", 2, 2)
			expect(lastPlay(fake).opts.speed).to.be.near(2 / 1.27, 1e-6)
		end)

		it("does not clamp climbing", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { climbScale = 5, minRate = 0.7, maxRate = 1.4 })
			animator:handleEvent("climbing", 1, 0)
			expect(lastPlay(fake).opts.speed).to.be.near(0.2, 1e-6)
		end)
	end)

	describe("pose ids (per-character clip sets)", function()
		local POSE_IDS = { idle = "pippaidle", walk = "pippawalk", run = "pipparun" }

		it("plays the mapped registry ids while reporting the logical pose", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { walkRunThreshold = 18, poseIds = POSE_IDS })
			animator:handleEvent("running", 0, 0)
			expect(animator:currentPose()).to.equal("idle")
			expect(lastPlay(fake).id).to.equal("pippaidle")
			animator:handleEvent("running", 10, 1)
			expect(animator:currentPose()).to.equal("walk")
			expect(lastPlay(fake).id).to.equal("pippawalk")
			expect(fake.stops[#fake.stops].id).to.equal("pippaidle")
			animator:handleEvent("running", 20, 2)
			expect(lastPlay(fake).id).to.equal("pipparun")
			expect(fake.stops[#fake.stops].id).to.equal("pippawalk")
		end)

		it("keeps the stock id for poses the map leaves out", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { poseIds = POSE_IDS })
			animator:handleEvent("jumping", nil, 0)
			expect(lastPlay(fake).id).to.equal("jump")
			expect(fake.stops[#fake.stops]).to.equal(nil)
		end)

		it("stops the mapped id on died and on destroy", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { poseIds = POSE_IDS })
			animator:handleEvent("running", 10, 0)
			animator:handleEvent("died", nil, 1)
			expect(fake.stops[#fake.stops].id).to.equal("pippawalk")

			local fake2 = makeFakePlayer()
			local animator2 = makeAnimator(fake2, { poseIds = POSE_IDS })
			animator2:handleEvent("running", 0, 0)
			animator2:destroy()
			expect(fake2.stops[#fake2.stops].id).to.equal("pippaidle")
		end)
	end)

	describe("stance (crouch)", function()
		local CROUCH_IDS = {
			idle = "pippaidle",
			walk = "pippawalk",
			run = "pipparun",
			crouchidle = "pippacrouchidle",
			crouchwalk = "pippacrouchwalk",
		}
		local CONFIG = {
			walkRunThreshold = 18,
			walkScale = 1.6,
			runScale = 1.9,
			crouchScale = 1.625,
			minRate = 0.6,
			walkMaxRate = 2.5,
			runMaxRate = 2.2,
			crouchMaxRate = 2,
			poseIds = CROUCH_IDS,
		}

		it("stands by default", function()
			local animator = makeAnimator(makeFakePlayer(), CONFIG)
			expect(animator:currentStance()).to.equal("stand")
		end)

		it("crouch-idles still and crouch-walks moving, its stride scaled and capped on its own", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, CONFIG)
			animator:setStance("crouch")
			animator:handleEvent("running", 0, 0)
			expect(animator:currentPose()).to.equal("crouchidle")
			expect(lastPlay(fake).id).to.equal("pippacrouchidle")
			animator:handleEvent("running", 2, 1)
			expect(animator:currentPose()).to.equal("crouchwalk")
			expect(lastPlay(fake).id).to.equal("pippacrouchwalk")
			expect(lastPlay(fake).opts.speed).to.be.near(2 / 1.625, 1e-6)
			-- At the crouch speed (9) the stride is capped by crouchMaxRate, not the walk's cap.
			animator:handleEvent("running", 9, 2)
			expect(lastPlay(fake).adjustments[#lastPlay(fake).adjustments]).to.be.near(2, 1e-6)
			-- Any speed crouched is the crouch walk (never the run).
			animator:handleEvent("running", 25, 3)
			expect(animator:currentPose()).to.equal("crouchwalk")
		end)

		it("re-poses at once on a stance change, at the last running speed, and back", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, CONFIG)
			animator:handleEvent("running", 8, 0)
			expect(animator:currentPose()).to.equal("walk")
			animator:setStance("crouch")
			expect(animator:currentPose()).to.equal("crouchwalk")
			expect(fake.stops[#fake.stops].id).to.equal("pippawalk")
			animator:setStance("stand")
			expect(animator:currentPose()).to.equal("walk")
			expect(fake.stops[#fake.stops].id).to.equal("pippacrouchwalk")
			expect(lastPlay(fake).opts.speed).to.be.near(2.5, 1e-6)
		end)

		it("stays standing for a clip set without crouch poses (the stock set)", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { poseIds = { idle = "pippaidle", walk = "pippawalk" } })
			animator:setStance("crouch")
			animator:handleEvent("running", 0, 0)
			expect(animator:currentPose()).to.equal("idle")
			expect(lastPlay(fake).id).to.equal("pippaidle")
		end)

		it("leaves jumps and falls alone, and lands back in the crouch", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, CONFIG)
			animator:setStance("crouch")
			animator:handleEvent("running", 0, 0)
			animator:handleEvent("jumping", nil, 1)
			expect(animator:currentPose()).to.equal("jump")
			-- Mid-air a stance change waits for the landing.
			animator:setStance("stand")
			expect(animator:currentPose()).to.equal("jump")
			animator:setStance("crouch")
			animator:handleEvent("running", 0, 2)
			expect(animator:currentPose()).to.equal("crouchidle")
		end)

		it("ignores stance changes under an override or the kill switch, and resumes crouched", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, CONFIG)
			animator:handleEvent("running", 0, 0)
			animator:setPoseOverride("sit")
			animator:setStance("crouch")
			expect(animator:currentPose()).to.equal("sit")
			animator:clearPoseOverride()
			expect(animator:currentPose()).to.equal("crouchidle")
			animator:setEnabled(false)
			animator:setStance("stand")
			expect(animator:currentPose()).to.equal(nil)
			animator:setEnabled(true)
			expect(animator:currentPose()).to.equal("idle")
		end)

		it("does nothing once dead", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, CONFIG)
			animator:handleEvent("running", 0, 0)
			animator:handleEvent("died", nil, 1)
			local plays = #fake.plays
			animator:setStance("crouch")
			expect(#fake.plays).to.equal(plays)
			expect(animator:currentPose()).to.equal(nil)
		end)
	end)

	describe("other states", function()
		it("swims when moving and swim-idles when not", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("swimming", 6, 0)
			expect(animator:currentPose()).to.equal("swim")
			animator:handleEvent("swimming", 0.5, 1)
			expect(animator:currentPose()).to.equal("swimidle")
		end)

		it("climbs speed-scaled, sits when seated, idles on gettingUp", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake, { climbScale = 5 })
			animator:handleEvent("climbing", 10, 0)
			expect(animator:currentPose()).to.equal("climb")
			expect(lastPlay(fake).opts.speed).to.be.near(10 / 5, 1e-6)
			animator:handleEvent("seated", nil, 1)
			expect(animator:currentPose()).to.equal("sit")
			animator:handleEvent("gettingUp", nil, 2)
			expect(animator:currentPose()).to.equal("idle")
		end)

		-- No death pose (V5 decision): the old game deprecated its death animation. Locomotion
		-- stops and latches; the Death/Ragdoll phase owns what death looks like.
		it("stops everything on died and ignores later state events", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 20, 0)
			animator:handleEvent("died", nil, 1)
			expect(animator:currentPose()).to.equal(nil)
			expect(fake.stops[#fake.stops].id).to.equal("run")
			animator:handleEvent("running", 20, 2)
			expect(animator:currentPose()).to.equal(nil)
		end)
	end)

	describe("kill switch", function()
		it("stops the current pose, ignores events while disabled, and idles on re-enable", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 20, 0)
			animator:setEnabled(false)
			expect(animator:currentPose()).to.equal(nil)
			expect(fake.stops[#fake.stops].id).to.equal("run")
			animator:handleEvent("running", 20, 1)
			expect(animator:currentPose()).to.equal(nil)
			animator:setEnabled(true)
			expect(animator:currentPose()).to.equal("idle")
		end)
	end)

	describe("pose override (the Movement phase's seam)", function()
		it("suppresses state-driven poses until cleared", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			local ok = animator:setPoseOverride("sneakidle")
			expect(ok).to.equal(true)
			expect(animator:currentPose()).to.equal("sneakidle")
			animator:handleEvent("running", 20, 1)
			expect(animator:currentPose()).to.equal("sneakidle")
			animator:clearPoseOverride()
			expect(animator:currentPose()).to.equal("idle")
			animator:handleEvent("running", 20, 2)
			expect(animator:currentPose()).to.equal("run")
		end)

		it("surfaces the player's refusal and keeps the current pose", function()
			local fake = makeFakePlayer({ failIds = { ["not-registered"] = true } })
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			local ok, reason = animator:setPoseOverride("not-registered")
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
			expect(animator:currentPose()).to.equal("idle")
		end)
	end)

	describe("kill switch with an active override", function()
		-- Qodo PR #13 finding: disabling with an override active must STOP the override track,
		-- not just forget it.
		it("stops the override pose when disabled, and re-enables to idle", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			animator:setPoseOverride("sneakidle")
			animator:setEnabled(false)
			expect(animator:currentPose()).to.equal(nil)
			local stoppedOverride = false
			for _, stop in fake.stops do
				if stop.id == "sneakidle" then
					stoppedOverride = true
				end
			end
			expect(stoppedOverride).to.equal(true)
			animator:setEnabled(true)
			expect(animator:currentPose()).to.equal("idle")
		end)
	end)

	describe("death wins over everything", function()
		-- PR #13 review finding: died used to be swallowed by the override/enabled guard, leaving
		-- an override track playing on a corpse until respawn.
		it("stops an active pose override on died and latches", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			animator:setPoseOverride("sneakidle")
			animator:handleEvent("died", nil, 1)
			expect(animator:currentPose()).to.equal(nil)
			local stoppedOverride = false
			for _, stop in fake.stops do
				if stop.id == "sneakidle" then
					stoppedOverride = true
				end
			end
			expect(stoppedOverride).to.equal(true)
			-- Latched: re-enabling must not resurrect a corpse into idle.
			animator:setEnabled(false)
			animator:setEnabled(true)
			expect(animator:currentPose()).to.equal(nil)
		end)

		it("still latches when dying while the kill switch is off", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 20, 0)
			animator:setEnabled(false)
			animator:handleEvent("died", nil, 1)
			animator:setEnabled(true)
			expect(animator:currentPose()).to.equal(nil)
		end)
	end)

	describe("destroy", function()
		it("stops its pose and goes inert", function()
			local fake = makeFakePlayer()
			local animator = makeAnimator(fake)
			animator:handleEvent("running", 0, 0)
			animator:destroy()
			expect(animator:currentPose()).to.equal(nil)
			animator:handleEvent("running", 20, 1)
			expect(animator:currentPose()).to.equal(nil)
		end)
	end)
end
