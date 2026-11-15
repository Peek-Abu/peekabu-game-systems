local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantWatchRules = require(script.Parent.OccupantWatchRules)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- The monster stands 30 studs down +Z from the crew member, its head, chest and knees.
local HEAD = Vector3.new(0, 8, 30)
local CHEST = Vector3.new(0, 5, 30)
local KNEES = Vector3.new(0, 1.5, 30)

-- A camera report as the server keeps it: at `position` looking along `look` (world up unless `up`), a `fov`-degree
-- (vertical) screen of `aspect` (default 70 degrees, 16:9), received at 100.
local function report(position, look, fov, aspect, up)
	local tanV, tanH = OccupantWatchRules.screen(fov or 70, aspect or 16 / 9)
	return {
		position = position,
		look = look,
		up = up or Vector3.yAxis,
		tanV = tanV,
		tanH = tanH,
		receivedAt = 100,
	}
end

-- A crew member at the origin (head at y 5), camera 8 studs behind the head looking at the monster's chest, a report
-- received at 100, every ray clear; `extra` overrides any field.
local function viewer(extra)
	local camera = Vector3.new(0, 7, -8)
	local value = {
		alive = true,
		downed = false,
		hidden = false,
		inTruck = false,
		vacuuming = false,
		head = Vector3.new(0, 5, 0),
		report = report(camera, (CHEST - camera).Unit),
		cameraClear = true,
		sightlines = {
			{ point = HEAD, clear = true },
			{ point = CHEST, clear = true },
			{ point = KNEES, clear = true },
		},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function lines(head, chest, knees)
	return {
		{ point = HEAD, clear = head },
		{ point = CHEST, clear = chest },
		{ point = KNEES, clear = knees },
	}
end

return function()
	describe("watching", function()
		it("counts a crew member who looks straight at it with a clear line", function()
			expect(OccupantWatchRules.watching(viewer(), 100.1)).to.equal(true)
		end)

		it("never counts someone dead, knocked down, hidden (even peeking) or in the truck", function()
			expect(OccupantWatchRules.watching(viewer({ alive = false }), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer({ downed = true }), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer({ hidden = true }), 100.1)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer({ inTruck = true }), 100.1)).to.equal(false)
			-- B1 (owner 11-14): a running vacuum takes your eyes; you cannot clean and freeze it at once.
			expect(OccupantWatchRules.watching(viewer({ vacuuming = true }), 100.1)).to.equal(false)
		end)

		it("needs a camera report", function()
			local v = viewer()
			v.report = nil
			expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
		end)

		it("drops a stale report (0.3 s old or more)", function()
			expect(OccupantWatchRules.watching(viewer(), 100 + C.FREEZE_REPORT_FRESH - 0.01)).to.equal(true)
			expect(OccupantWatchRules.watching(viewer(), 100 + C.FREEZE_REPORT_FRESH)).to.equal(false)
			expect(OccupantWatchRules.watching(viewer(), 101)).to.equal(false)
		end)

		it("refuses a forged camera far from the head", function()
			local far = Vector3.new(0, 7, 20)
			local v = viewer({ report = report(far, (CHEST - far).Unit) })
			expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
			local edge = Vector3.new(0, 5, -C.FREEZE_CAMERA_RANGE)
			local ok = viewer({ report = report(edge, (CHEST - edge).Unit) })
			expect(OccupantWatchRules.watching(ok, 100.1)).to.equal(true)
		end)

		it("refuses a camera through a wall (the head-to-camera line is blocked)", function()
			expect(OccupantWatchRules.watching(viewer({ cameraClear = false }), 100.1)).to.equal(false)
		end)

		it("counts it anywhere on the screen, out to its very edges (owner 11-14: the edges must count)", function()
			-- A 70 degree, 16:9 screen reaches atan(16/9 x tan 35) = 51.2 degrees left and right, 35 up and down.
			local camera = Vector3.new(0, 5, 0)
			local function seenAt(yaw, pitch, fov, aspect)
				local direction = CFrame.Angles(0, math.rad(yaw), 0)
					* CFrame.Angles(math.rad(pitch), 0, 0)
					* Vector3.new(0, 0, -1)
				local point = camera + direction * 20
				return OccupantWatchRules.watching(
					viewer({
						report = report(camera, Vector3.new(0, 0, -1), fov, aspect),
						sightlines = { { point = point, clear = true } },
					}),
					100.1
				)
			end
			expect(seenAt(0, 0)).to.equal(true)
			expect(seenAt(49, 0)).to.equal(true)
			expect(seenAt(-49, 0)).to.equal(true)
			expect(seenAt(54, 0)).to.equal(false)
			expect(seenAt(0, 33)).to.equal(true)
			expect(seenAt(0, -33)).to.equal(true)
			expect(seenAt(0, 38)).to.equal(false)
			-- Near a corner of the screen, just inside both edges.
			expect(seenAt(40, 25)).to.equal(true)
			-- A wide phone screen (2.2:1) reaches further to the sides (57 degrees).
			expect(seenAt(55, 0, 70, 2.2)).to.equal(true)
			expect(seenAt(55, 0)).to.equal(false)
			-- Behind the camera never.
			expect(seenAt(180, 0)).to.equal(false)
			expect(seenAt(95, 0, 70, 3)).to.equal(false)
		end)

		it("never counts what is behind the kid's own head (P1 11-14: it froze closing in from behind)", function()
			-- A kid running down +Z with the default third-person camera 12.5 studs behind and 2 above their head.
			-- Bramble chasing them sits between that camera and their back, so it shows on their screen from ~12 studs
			-- behind them (its head; its chest at y 4 from 9.3), far outside its 4.6-stud reach: counted, it froze there
			-- every time and never caught anyone.
			local head = Vector3.new(0, 5, 0)
			local camera = Vector3.new(0, 7, -12.5)
			local look = (Vector3.new(0, 4, 10) - camera).Unit
			local function watchedAt(z)
				local point = Vector3.new(0, 4, z)
				local v = viewer({
					head = head,
					report = report(camera, look),
					sightlines = { { point = point, clear = true } },
				})
				return OccupantWatchRules.onScreen(v.report, point), OccupantWatchRules.watching(v, 100.1)
			end
			for _, z in { -9, -8, -4.6, -2, -0.5 } do
				local shown, watched = watchedAt(z)
				expect(shown).to.equal(true)
				expect(watched).to.equal(false)
			end
			-- Beside or ahead of them it still counts, and so does a kid who turns their camera round to face it.
			local _, beside = watchedAt(0.5)
			expect(beside).to.equal(true)
			local turned = Vector3.new(0, 7, 12.5)
			local behind = Vector3.new(0, 4, -4)
			local faced = viewer({
				head = head,
				report = report(turned, (behind - turned).Unit),
				sightlines = { { point = behind, clear = true } },
			})
			expect(OccupantWatchRules.watching(faced, 100.1)).to.equal(true)
		end)

		it("takes the camera's own up (a rolled camera's screen turns with it)", function()
			local camera = Vector3.new(0, 5, 0)
			-- Rolled 90 degrees: the screen's long side now runs up and down, so 45 degrees up is on it.
			local high = camera + (CFrame.Angles(math.rad(45), 0, 0) * Vector3.new(0, 0, -1)) * 20
			local rolled = viewer({
				report = report(camera, Vector3.new(0, 0, -1), 70, 16 / 9, Vector3.new(1, 0, 0)),
				sightlines = { { point = high, clear = true } },
			})
			expect(OccupantWatchRules.watching(rolled, 100.1)).to.equal(true)
			local level = viewer({
				report = report(camera, Vector3.new(0, 0, -1), 70, 16 / 9),
				sightlines = { { point = high, clear = true } },
			})
			expect(OccupantWatchRules.watching(level, 100.1)).to.equal(false)
		end)

		it("refuses a zero or broken look direction", function()
			local camera = Vector3.new(0, 7, -8)
			local v = viewer({ report = report(camera, Vector3.zero) })
			expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
		end)

		it("counts any one clear ray to a point on its body (partly hidden still counts)", function()
			expect(OccupantWatchRules.watching(viewer({ sightlines = lines(true, false, false) }), 100.1)).to.equal(
				true
			)
			expect(OccupantWatchRules.watching(viewer({ sightlines = lines(false, false, true) }), 100.1)).to.equal(
				true
			)
			expect(OccupantWatchRules.watching(viewer({ sightlines = lines(false, false, false) }), 100.1)).to.equal(
				false
			)
		end)

		it(
			"needs a clear ray to a point on the screen (a clear point behind the camera's view does not count)",
			function()
				local camera = Vector3.new(0, 7, -8)
				local behind = Vector3.new(0, 5, -40)
				local v = viewer({
					report = report(camera, (CHEST - camera).Unit),
					sightlines = { { point = behind, clear = true }, { point = CHEST, clear = false } },
				})
				expect(OccupantWatchRules.watching(v, 100.1)).to.equal(false)
			end
		)

		it("caps sight at 80 studs from the camera", function()
			local camera = Vector3.new(0, 7, -8)
			local near = Vector3.new(0, 5, -8 + C.FREEZE_RANGE - 1)
			local far = Vector3.new(0, 5, -8 + C.FREEZE_RANGE + 1)
			local function at(point)
				return viewer({
					report = report(camera, (point - camera).Unit),
					sightlines = { { point = point, clear = true } },
				})
			end
			expect(OccupantWatchRules.watching(at(near), 100.1)).to.equal(true)
			expect(OccupantWatchRules.watching(at(far), 100.1)).to.equal(false)
		end)
	end)

	describe("the pieces", function()
		it("fresh: under 0.3 s, never without a report", function()
			expect(OccupantWatchRules.fresh(report(Vector3.zero, Vector3.zAxis), 100.29)).to.equal(true)
			expect(OccupantWatchRules.fresh(nil, 5)).to.equal(false)
		end)

		it("cameraNear: within 16 studs of the head", function()
			expect(OccupantWatchRules.cameraNear(Vector3.zero, Vector3.new(0, 0, 16))).to.equal(true)
			expect(OccupantWatchRules.cameraNear(Vector3.zero, Vector3.new(0, 0, 16.5))).to.equal(false)
		end)

		it("screen: the half-screen tangents of a vertical FOV and aspect, clamped to a real screen", function()
			local tanV, tanH = OccupantWatchRules.screen(70, 16 / 9)
			local slack = 1 + C.FREEZE_SCREEN_SLACK
			expect(tanV).to.be.near(math.tan(math.rad(35)) * slack, 1e-6)
			expect(tanH).to.be.near(math.tan(math.rad(35)) * 16 / 9 * slack, 1e-6)
			-- A forged huge FOV or a silly aspect is held to FREEZE_FOV_MAX and FREEZE_ASPECT_MAX.
			local bigV, bigH = OccupantWatchRules.screen(179, 50)
			expect(bigV).to.be.near(math.tan(math.rad(C.FREEZE_FOV_MAX / 2)) * slack, 1e-6)
			expect(bigH).to.be.near(bigV * C.FREEZE_ASPECT_MAX, 1e-6)
			local smallV, smallH = OccupantWatchRules.screen(0, 0)
			expect(smallV).to.be.near(math.tan(math.rad(C.FREEZE_FOV_MIN / 2)) * slack, 1e-6)
			expect(smallH).to.be.near(smallV * C.FREEZE_ASPECT_MIN, 1e-6)
		end)

		it("onScreen: in front of the camera and within both half-screens", function()
			local r = report(Vector3.zero, Vector3.new(0, 0, -1))
			expect(OccupantWatchRules.onScreen(r, Vector3.new(0, 0, -10))).to.equal(true)
			expect(OccupantWatchRules.onScreen(r, Vector3.new(0, 0, 10))).to.equal(false)
			expect(OccupantWatchRules.onScreen(r, Vector3.zero)).to.equal(false)
			expect(OccupantWatchRules.onScreen(r, Vector3.new(r.tanH * 10 * 0.99, 0, -10))).to.equal(true)
			expect(OccupantWatchRules.onScreen(r, Vector3.new(r.tanH * 10 * 1.01, 0, -10))).to.equal(false)
			expect(OccupantWatchRules.onScreen(r, Vector3.new(0, -r.tanV * 10 * 0.99, -10))).to.equal(true)
			expect(OccupantWatchRules.onScreen(r, Vector3.new(0, r.tanV * 10 * 1.01, -10))).to.equal(false)
		end)

		it("eligible: alive, standing, not hiding, outside the truck and not vacuuming", function()
			expect(OccupantWatchRules.eligible(viewer())).to.equal(true)
			expect(OccupantWatchRules.eligible(viewer({ hidden = true }))).to.equal(false)
			expect(OccupantWatchRules.eligible(viewer({ vacuuming = true }))).to.equal(false)
		end)
	end)

	describe("the freeze", function()
		it("starts unfrozen, never unfrozen before", function()
			local state = OccupantWatchRules.newFreeze()
			expect(state.frozen).to.equal(false)
			expect(state.unfrozenAt).to.equal(nil)
		end)

		it("freezes at once when someone watches, remembering when", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			expect(state.frozen).to.equal(true)
			expect(state.frozenAt).to.equal(10)
			local still = OccupantWatchRules.advance(state, true, 12)
			expect(still.frozenAt).to.equal(10)
		end)

		it("holds 0.4 s after the last watcher looks away, then unfreezes", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			local beat = OccupantWatchRules.advance(state, false, 10 + C.FREEZE_UNFREEZE_BEAT - 0.05)
			expect(beat.frozen).to.equal(true)
			local free = OccupantWatchRules.advance(beat, false, 10 + C.FREEZE_UNFREEZE_BEAT)
			expect(free.frozen).to.equal(false)
			expect(free.unfrozenAt).to.equal(10 + C.FREEZE_UNFREEZE_BEAT)
			expect(free.frozenAt).to.equal(nil)
		end)

		it("a glance back inside the beat keeps it frozen and restarts the beat", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			local away = OccupantWatchRules.advance(state, false, 10.3)
			local back = OccupantWatchRules.advance(away, true, 10.35)
			local again = OccupantWatchRules.advance(back, false, 10.6)
			expect(again.frozen).to.equal(true)
			expect(again.frozenAt).to.equal(10)
			local free = OccupantWatchRules.advance(again, false, 10.35 + C.FREEZE_UNFREEZE_BEAT)
			expect(free.frozen).to.equal(false)
		end)

		it("stays unfrozen while nobody watches", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), false, 10)
			expect(state.frozen).to.equal(false)
			expect(state.unfrozenAt).to.equal(nil)
		end)

		it("never changes the state it is given", function()
			local state = OccupantWatchRules.newFreeze()
			OccupantWatchRules.advance(state, true, 10)
			expect(state.frozen).to.equal(false)
		end)
	end)

	describe("the catch block", function()
		it("allows a catch when it was never frozen", function()
			expect(OccupantWatchRules.canCatch(OccupantWatchRules.newFreeze(), 10)).to.equal(true)
		end)

		it("never while frozen", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			expect(OccupantWatchRules.canCatch(state, 10)).to.equal(false)
		end)

		it("not for 0.6 s after unfreezing, then again", function()
			local state = OccupantWatchRules.advance(OccupantWatchRules.newFreeze(), true, 10)
			local free = OccupantWatchRules.advance(state, false, 10.4)
			expect(OccupantWatchRules.canCatch(free, 10.4 + C.FREEZE_CATCH_BLOCK - 0.05)).to.equal(false)
			expect(OccupantWatchRules.canCatch(free, 10.4 + C.FREEZE_CATCH_BLOCK)).to.equal(true)
		end)
	end)
	describe("the brain's side", function()
		local W = OccupantWatchRules
		local function fresh()
			return OccupantBrainRules.newMind(1, 1, 0)
		end
		local function senses(extra)
			local value = {
				position = Vector3.new(60, 3, 60),
				look = Vector3.new(1, 0, 0),
				now = 100,
				sightRange = C.SIGHT_RANGE,
				sightAngle = C.SIGHT_ANGLE,
				players = {},
				resting = false,
				route = {},
				restPoint = Vector3.new(200, 0, 200),
				zone = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) },
			}
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("pause moves every clock that times what he does, and nothing else", function()
			local mind = fresh()
			mind.since = 10
			mind.chaseAt = 11
			mind.arrivedAt = 12
			mind.phaseAt = 13
			mind.standUntil = 14
			mind.grace = { [7] = 50 }
			local copy = table.clone(mind)
			W.pause(copy, 2)
			expect(copy.since).to.equal(12)
			expect(copy.chaseAt).to.equal(13)
			expect(copy.arrivedAt).to.equal(14)
			expect(copy.phaseAt).to.equal(15)
			expect(copy.standUntil).to.equal(16)
			expect(copy.reactUntil).to.equal(nil)
			expect(copy.grace[7]).to.equal(50)
			expect(copy.nextWorkAt).to.equal(mind.nextWorkAt)
			expect(mind.since).to.equal(10)
		end)

		it("pause does nothing for no time", function()
			local mind = fresh()
			mind.since = 10
			W.pause(mind, 0)
			W.pause(mind, -3)
			expect(mind.since).to.equal(10)
		end)

		it("frozenSeconds counts from his last think, or from the freeze if it began later", function()
			local mind = fresh()
			mind.lastThink = 100
			expect(W.frozenSeconds(mind, senses({ now = 101, frozenAt = 99 }))).to.be.near(1, 1e-6)
			expect(W.frozenSeconds(mind, senses({ now = 101, frozenAt = 100.75 }))).to.be.near(0.25, 1e-6)
			expect(W.frozenSeconds(fresh(), senses({ now = 101 }))).to.equal(0)
		end)

		it("catchBlocked: while frozen and for FREEZE_CATCH_BLOCK after, never without freeze senses", function()
			expect(W.catchBlocked(senses({ frozen = true }))).to.equal(true)
			expect(W.catchBlocked(senses({ unfrozenAt = 100 - C.FREEZE_CATCH_BLOCK / 2 }))).to.equal(true)
			expect(W.catchBlocked(senses({ unfrozenAt = 100 - C.FREEZE_CATCH_BLOCK - 0.01 }))).to.equal(false)
			expect(W.catchBlocked(senses())).to.equal(false)
			expect(W.catchBlocked(senses({ frozen = false }))).to.equal(false)
		end)

		it("withoutCatch turns a grab into a run at them and drops a catch effect", function()
			local glimpse = { userId = 7, position = Vector3.new(62, 3, 60), clear = true }
			local step = {
				mind = fresh(),
				intent = { kind = "attack", target = 7 },
				effects = { { kind = "catch", userId = 7 }, { kind = "release" } },
			}
			local safe = W.withoutCatch(step, senses({ players = { glimpse } }))
			expect(safe.intent.kind).to.equal("goTo")
			expect(safe.intent.position).to.equal(glimpse.position)
			expect(safe.intent.run).to.equal(true)
			expect(#safe.effects).to.equal(1)
			expect(safe.effects[1].kind).to.equal("release")
			expect(#step.effects).to.equal(2)
		end)

		it("withoutCatch idles when the grabbed player is not in his senses", function()
			local step = { mind = fresh(), intent = { kind = "attack", target = 7 } }
			expect(W.withoutCatch(step, senses()).intent.kind).to.equal("idle")
		end)

		it("withoutCatch leaves any other intent alone", function()
			local goTo = { kind = "goTo", position = Vector3.new(1, 0, 1), run = false }
			local step = { mind = fresh(), intent = goTo, effects = { { kind = "catch", userId = 7 } } }
			local safe = W.withoutCatch(step, senses())
			expect(safe.intent).to.equal(goTo)
			expect(safe.effects).to.equal(nil)
		end)
	end)

	describe("the lunge (the head's kid becomes the chase target)", function()
		local W = OccupantWatchRules
		local function fresh()
			return OccupantBrainRules.newMind(1, 1, 0)
		end
		local function senses(extra)
			local value = {
				position = Vector3.new(60, 3, 60),
				look = Vector3.new(1, 0, 0),
				now = 100,
				sightRange = C.SIGHT_RANGE,
				sightAngle = C.SIGHT_ANGLE,
				players = {},
				resting = false,
				route = {},
				restPoint = Vector3.new(200, 0, 200),
				zone = { min = Vector3.new(0, -5, 0), max = Vector3.new(40, 20, 30) },
			}
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end
		local function kid(userId, x, extra)
			local value = { userId = userId, position = Vector3.new(x, 3, 60), clear = false }
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("chases the head's kid from patrol, running to where they are", function()
			local mind = W.lunge(fresh(), senses({ players = { kid(7, 120) }, lunge = 7 }))
			expect(mind.mode).to.equal("chase")
			expect(mind.target).to.equal(7)
			expect(mind.lastSeen).to.equal(Vector3.new(120, 3, 60))
			expect(mind.chaseAt).to.equal(100)
		end)

		it("switches a chase to the head's kid", function()
			local chasing = W.lunge(fresh(), senses({ players = { kid(7, 120), kid(8, 90) }, lunge = 7 }))
			local switched = W.lunge(chasing, senses({ now = 101, players = { kid(7, 120), kid(8, 90) }, lunge = 8 }))
			expect(switched.target).to.equal(8)
			expect(switched.chaseAt).to.equal(101)
		end)

		it("keeps a chase of the same kid as it is (its give-up clock too)", function()
			local chasing = W.lunge(fresh(), senses({ players = { kid(7, 120) }, lunge = 7 }))
			local again = W.lunge(chasing, senses({ now = 103, players = { kid(7, 120) }, lunge = 7 }))
			expect(again).to.equal(chasing)
		end)

		it("does nothing without a lunge, while frozen, or during a catch", function()
			local mind = fresh()
			expect(W.lunge(mind, senses({ players = { kid(7, 120) } }))).to.equal(mind)
			expect(W.lunge(mind, senses({ players = { kid(7, 120) }, lunge = 7, frozen = true }))).to.equal(mind)
			local catching = table.clone(mind)
			catching.mode = "catch"
			expect(W.lunge(catching, senses({ players = { kid(7, 120) }, lunge = 7 }))).to.equal(catching)
			-- On a perch he drops first (OccupantPerchRules); he never lunges off the top of the lockers.
			local perched = table.clone(mind)
			perched.mode = "perch"
			expect(W.lunge(perched, senses({ players = { kid(7, 120) }, lunge = 7 }))).to.equal(perched)
		end)

		it("never goes for a kid who is hidden, in grace, or not in his senses (out, or caught)", function()
			local mind = fresh()
			local hidden = senses({ players = { kid(7, 120, { hidden = true }) }, lunge = 7 })
			expect(W.lunge(mind, hidden)).to.equal(mind)
			local graced = table.clone(mind)
			graced.grace = { [7] = 105 }
			expect(W.lunge(graced, senses({ players = { kid(7, 120) }, lunge = 7 }))).to.equal(graced)
			expect(W.lunge(mind, senses({ players = { kid(8, 120) }, lunge = 7 }))).to.equal(mind)
		end)

		it("never goes for a kid in the truck's box", function()
			local mind = fresh()
			local safe = { userId = 7, position = Vector3.new(20, 3, 15), clear = true }
			expect(W.lunge(mind, senses({ players = { safe }, lunge = 7 }))).to.equal(mind)
		end)
	end)
end
