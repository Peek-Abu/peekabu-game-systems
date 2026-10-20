local CatchViewModel = require(script.Parent.CatchViewModel)
local OccupantConstants = require(game:GetService("ReplicatedStorage").Shared.Features.Occupant.Data.OccupantConstants)

local REPORT = { room = "Archive", clock = 222, backAt = 108, dropped = { "Monitor", "Employee of the Month plaque" } }

local function snapshot(extra)
	local value = {
		phase = "running",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		endsAt = 352,
		quota = 350,
		cleared = 0,
		bonus = 0,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
		crew = {},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function input(extra)
	local value = {
		snapshot = snapshot(),
		me = { dead = true, caughtUntil = 106 },
		report = REPORT,
		targetName = "Sam",
		target = { carrying = "coffeeMachine", room = "Server room", roomDepth = 2, cam = 6 },
		now = 100,
		prevKey = "←",
		nextKey = "→",
		phone = false,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("cctv", function()
		it("shows only while the local player is down in a running shift", function()
			expect(CatchViewModel.cctv(input({ me = { caughtUntil = 106 } }))).to.equal(nil)
			expect(CatchViewModel.cctv(input({ snapshot = snapshot({ phase = "results" }) }))).to.equal(nil)
			expect(CatchViewModel.cctv(input()) ~= nil).to.equal(true)
		end)

		it("shows OUT FOR THE SHIFT for a knocked-out player with no deadline", function()
			local view = CatchViewModel.cctv(input({ me = { dead = true, knockedOut = true } }))
			expect(view ~= nil).to.equal(true)
			expect(view.back).to.equal("OUT FOR THE SHIFT")
			expect(CatchViewModel.cctv(input({ me = { dead = true, lives = 2 } }))).to.equal(nil)
		end)

		it("labels the camera, the room and who is watched", function()
			local view = CatchViewModel.cctv(input())
			expect(view.rec).to.equal("REC   CAM 06 · SERVER ROOM")
			expect(view.watching).to.equal("WATCHING  SAM")
			expect(view.details).to.equal("carrying: Coffee machine · 2 rooms from the truck")
			expect(view.canSwitch).to.equal(true)
		end)

		it("says one room, and the loading bay, in words", function()
			local near = CatchViewModel.cctv(input({ target = { roomDepth = 1, room = "Reception", cam = 2 } }))
			expect(near.details).to.equal("hands empty · 1 room from the truck")
			local bay = CatchViewModel.cctv(input({ target = { roomDepth = 0, room = "Loading bay", cam = 1 } }))
			expect(bay.details).to.equal("hands empty · at the truck")
		end)

		it("reads NO SIGNAL with nobody to watch", function()
			local value = input()
			value.targetName = nil
			value.target = nil
			local view = CatchViewModel.cctv(value)
			expect(view.watching).to.equal("NO SIGNAL")
			expect(view.rec).to.equal("REC   CAM -- · NO SIGNAL")
			-- Solo (or everyone down): no teammate to switch to, so no previous / next controls.
			expect(view.canSwitch).to.equal(false)
		end)

		it("counts down to the respawn and never below 0:00", function()
			expect(CatchViewModel.cctv(input()).back).to.equal("BACK ON THE CLOCK IN 0:06")
			expect(CatchViewModel.cctv(input({ now = 120 })).back).to.equal("BACK ON THE CLOCK IN 0:00")
		end)

		it("stamps a night clock from the time into the shift", function()
			-- endsAt 352, now 100: 252 s left of 420, so 168 s in: 03:02:48.
			expect(CatchViewModel.cctv(input()).stamp).to.equal("THU 03:02:48")
			expect(CatchViewModel.nightClock(3600)).to.equal("04:00:00")
		end)

		it("writes the incident report with the clock and the room", function()
			local view = CatchViewModel.cctv(input())
			expect(view.incidentTitle).to.equal("INCIDENT REPORT · YOU")
			expect(view.incident[1]).to.equal("Caught by the Manager at 3:42.")
			expect(view.incident[2]).to.equal("Your cargo dropped in the archive.")
		end)

		it("says nothing dropped for empty hands, and keeps the phone short", function()
			local empty = table.clone(REPORT)
			empty.dropped = {}
			expect(CatchViewModel.cctv(input({ report = empty })).incident[2]).to.equal("You were carrying nothing.")
			local phone = CatchViewModel.cctv(input({ phone = true }))
			expect(phone.incidentTitle).to.equal("INCIDENT REPORT")
			expect(phone.incident[1]).to.equal("Caught by the Manager.")
			expect(phone.details).to.equal("carrying: Coffee machine")
		end)

		it("dead but not caught shows no CCTV", function()
			expect(CatchViewModel.cctv(input({ me = { dead = true } }))).to.equal(nil)
		end)

		it("a stale report is not shown", function()
			local stale = table.clone(REPORT)
			stale.backAt = 50
			local view = CatchViewModel.cctv(input({ report = stale }))
			expect(#view.incident).to.equal(0)
			expect(view.back).to.equal("BACK ON THE CLOCK IN 0:06")
		end)

		it("phrases every room with 'the'", function()
			expect(CatchViewModel.roomPhrase("Manager's office")).to.equal("the manager's office")
			expect(CatchViewModel.roomPhrase("Break room")).to.equal("the break room")
		end)
	end)

	describe("rehired", function()
		local function rehiredInput(extra)
			local value = {
				report = REPORT,
				me = { dead = true, caughtUntil = 106 },
				name = "Ava",
				rehiredAt = nil,
				nowServer = 105,
				nowClock = 50,
				phone = false,
			}
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("shows from just before the respawn until a few seconds after it", function()
			expect(CatchViewModel.rehired(rehiredInput({ nowServer = 100 }))).to.equal(nil)
			expect(CatchViewModel.rehired(rehiredInput()) ~= nil).to.equal(true)
			local after = rehiredInput({ me = {}, rehiredAt = 49 })
			expect(CatchViewModel.rehired(after) ~= nil).to.equal(true)
			after.nowClock = 53
			expect(CatchViewModel.rehired(after)).to.equal(nil)
		end)

		-- 2-player test (2026-10-18): the player could walk around under the notice for its whole hold, and it then
		-- vanished at once. The notice now holds while the player is held still (OccupantServiceClient locks movement
		-- for REHIRED_HOLD), then fades out over REHIRED_FADE as control comes back.
		it("is shown until the hold ends, then fades out as the player can move", function()
			local after = rehiredInput({ me = {}, rehiredAt = 49 })
			after.nowClock = 49 + OccupantConstants.REHIRED_HOLD - 0.1
			expect(CatchViewModel.rehired(after).shown).to.equal(true)
			after.nowClock = 49 + OccupantConstants.REHIRED_HOLD + OccupantConstants.REHIRED_FADE / 2
			local fading = CatchViewModel.rehired(after)
			expect(fading ~= nil).to.equal(true)
			expect(fading.shown).to.equal(false)
			after.nowClock = 49 + OccupantConstants.REHIRED_HOLD + OccupantConstants.REHIRED_FADE + 0.1
			expect(CatchViewModel.rehired(after)).to.equal(nil)
		end)

		it("is shown before the respawn", function()
			expect(CatchViewModel.rehired(rehiredInput()).shown).to.equal(true)
		end)

		it("needs a report", function()
			local value = rehiredInput()
			value.report = nil
			expect(CatchViewModel.rehired(value)).to.equal(nil)
		end)

		it("fills the HR notice", function()
			local view = CatchViewModel.rehired(rehiredInput())
			expect(view.title).to.equal("Rehired.")
			expect(view.rows[1]).to.equal("Name: Ava")
			expect(view.rows[2]).to.equal("Employment ended: 3:42 (caught by the Manager)")
			expect(view.rows[3]).to.equal("Re-hired: 3:34, no questions asked")
			expect(view.rows[4]).to.equal("Dropped: Monitor, Employee of the Month plaque. Go back for them!")
			expect(view.stamp).to.equal("REHIRED")
			expect(view.footer).to.equal("Respawning at the loading bay…")
		end)

		it("ignores a stale report before the respawn", function()
			local stale = table.clone(REPORT)
			stale.backAt = 50
			expect(CatchViewModel.rehired(rehiredInput({ report = stale }))).to.equal(nil)
		end)

		it("says nothing was dropped", function()
			local empty = table.clone(REPORT)
			empty.dropped = {}
			expect(CatchViewModel.rehired(rehiredInput({ report = empty })).rows[4]).to.equal("Dropped: nothing.")
		end)
	end)

	describe("rehirePending", function()
		-- Read on the local CharacterAdded: the server clears the deadline only after the new character exists, so a
		-- caught player's next character still sees it and is held still from its first frame.
		it("is pending while the local player still carries a catch deadline", function()
			expect(CatchViewModel.rehirePending({ dead = true, caughtUntil = 106 })).to.equal(true)
			expect(CatchViewModel.rehirePending({ caughtUntil = 106 })).to.equal(true)
		end)

		it("is not pending after a plain death, with no entry, or once the deadline is cleared", function()
			expect(CatchViewModel.rehirePending({ dead = true })).to.equal(false)
			expect(CatchViewModel.rehirePending({})).to.equal(false)
			expect(CatchViewModel.rehirePending(nil)).to.equal(false)
		end)
	end)

	describe("ticking", function()
		-- The overlay and the notice follow the clock only while something they show counts down, so an idle HUD
		-- does not re-render on the clock.
		it("ticks the CCTV only while the local player is down with a deadline", function()
			expect(CatchViewModel.cctvTicks({ dead = true, caughtUntil = 106 })).to.equal(true)
			expect(CatchViewModel.cctvTicks({ caughtUntil = 106 })).to.equal(false)
			expect(CatchViewModel.cctvTicks({ dead = true })).to.equal(false)
			expect(CatchViewModel.cctvTicks({})).to.equal(false)
			expect(CatchViewModel.cctvTicks(nil)).to.equal(false)
		end)

		it("ticks the notice while a catch counts down and until its hold after the respawn", function()
			expect(CatchViewModel.rehiredTicks(REPORT, { dead = true, caughtUntil = 106 }, nil, 50)).to.equal(true)
			expect(CatchViewModel.rehiredTicks(REPORT, {}, 49, 50)).to.equal(true)
			-- Through the fade out, so the notice is told when the hold ends and when the fade is over.
			local fading = 49 + OccupantConstants.REHIRED_HOLD + OccupantConstants.REHIRED_FADE / 2
			expect(CatchViewModel.rehiredTicks(REPORT, {}, 49, fading)).to.equal(true)
			-- Past the hold the notice is gone for good: nothing to tick for.
			expect(CatchViewModel.rehiredTicks(REPORT, {}, 49, 60)).to.equal(false)
			expect(CatchViewModel.rehiredTicks(REPORT, {}, nil, 50)).to.equal(false)
			expect(CatchViewModel.rehiredTicks(nil, { dead = true, caughtUntil = 106 }, 49, 50)).to.equal(false)
		end)
	end)

	describe("spectateKeys", function()
		it("prints the first keyboard binding of each spectate action", function()
			local prev, nextKey = CatchViewModel.spectateKeys({
				spectatePrev = { Enum.KeyCode.Left },
				spectateNext = { Enum.KeyCode.E },
			})
			expect(prev).to.equal("←")
			expect(nextKey).to.equal("E")
		end)

		it("falls back to the arrow keys without bindings", function()
			local prev, nextKey = CatchViewModel.spectateKeys({})
			expect(prev).to.equal("←")
			expect(nextKey).to.equal("→")
		end)
	end)
end
