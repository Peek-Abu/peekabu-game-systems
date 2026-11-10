--!strict
--[=[
	TrainingPassRules: Mr. Harlow's scripted pass at the training's escape stop (owner-approved redesign, 2026-11-10:
	"he walks right past you"). Pure: TrainingHarlowSystem senses and carries out the commands.

	- `begin`: the player reached the stop. The STAFF door opens (its creak, its light spilling in), and after
	  PASS.enter he walks in to the first lane point.
	- Walking the lane: point by point. At the lane point nearest the player (decided as he arrives, so it follows a
	  player who moves) he stops once, turns to face them for PASS.pause, then walks on. Heading for the last point
	  opens his exit door; arriving there (he is through it) shuts it.
	- Gone: PASS.slam after the door shuts he is parked offstage and the STAFF door shuts. A pass where he caught nobody
	  is `clean` (the stop is done). After a catch he comes round again PASS.retry later.
	- Spotted in the open (walking or paused, never while the doors play): a real chase (his own brain). Once his
	  brain has stopped hunting for PASS.calm, he walks straight to his exit door and leaves, with no more stops.
	- Missing (no Harlow in the shift) for PASS.absent during a pass: the pass ends as if he left, so nobody is stuck.

	@class TrainingPassRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

export type Phase = "offstage" | "opening" | "walk" | "pause" | "chase" | "closing" | "gone"

export type Pass = {
	phase: Phase,
	-- When the phase began.
	since: number,
	-- The lane point he is walking to (or stands at).
	at: number,
	-- He has had his one stop this pass.
	paused: boolean,
	-- He caught the player this pass.
	caught: boolean,
	-- Since when his brain has not been hunting (in a chase).
	calmSince: number?,
	-- Since when he has been missing from the shift.
	missingSince: number?,
}

export type Sense = {
	now: number,
	-- His directed walk has arrived (he stands frozen at its point).
	arrived: boolean,
	-- He sees the player in the open: not hidden, a clear line, within PASS.spot.
	spotted: boolean,
	-- His own brain is after the player (chase, search, stare, alert or catch).
	hunting: boolean,
	-- He is not in the shift (no rig).
	missing: boolean,
	-- Where the player is (nil: no character).
	player: Vector3?,
}

export type Command =
	{ kind: "openStaff" }
	| { kind: "closeStaff" }
	| { kind: "openExit" }
	| { kind: "closeExit" }
	| { kind: "walk", position: Vector3 }
	| { kind: "face", position: Vector3 }
	| { kind: "chase" }
	| { kind: "park" }

local PASS = TrainingConstants.PASS

local TrainingPassRules = {}

function TrainingPassRules.new(): Pass
	return {
		phase = "offstage",
		since = 0,
		at = 1,
		paused = false,
		caught = false,
		calmSince = nil,
		missingSince = nil,
	}
end

local function enter(pass: Pass, phase: Phase, now: number)
	pass.phase = phase
	pass.since = now
end

--[=[
	The player reached the stop: the STAFF door opens. Nothing once a pass is under way.
]=]
function TrainingPassRules.begin(pass: Pass, now: number): { Command }
	if pass.phase ~= "offstage" then
		return {}
	end
	enter(pass, "opening", now)
	pass.at = 1
	pass.paused = false
	pass.caught = false
	pass.calmSince = nil
	pass.missingSince = nil
	return { { kind = "openStaff" } }
end

-- The lane point (all but the last, which is past his exit door) nearest `player`.
local function nearest(lane: { Vector3 }, player: Vector3): number
	local best, bestDistance = 1, math.huge
	for index = 1, #lane - 1 do
		local offset = (lane[index] - player) * Vector3.new(1, 0, 1)
		if offset.Magnitude < bestDistance then
			best, bestDistance = index, offset.Magnitude
		end
	end
	return best
end

-- On from lane point `pass.at`: through the exit door (opening it) or to the next point.
local function onward(pass: Pass, lane: { Vector3 }): { Command }
	pass.at += 1
	local walk: Command = { kind = "walk", position = lane[pass.at] }
	if pass.at == #lane then
		return { { kind = "openExit" }, walk }
	end
	return { walk }
end

local function arrive(pass: Pass, sense: Sense, lane: { Vector3 }): { Command }
	if pass.at >= #lane then
		enter(pass, "closing", sense.now)
		return { { kind = "closeExit" } }
	end
	local player = sense.player
	if not pass.paused and player ~= nil and pass.at >= nearest(lane, player) then
		enter(pass, "pause", sense.now)
		return { { kind = "face", position = player } }
	end
	return onward(pass, lane)
end

--[=[
	One poll of the pass: the commands to carry out now.
]=]
function TrainingPassRules.step(pass: Pass, sense: Sense, lane: { Vector3 }): { Command }
	local now, phase = sense.now, pass.phase
	if phase ~= "offstage" and phase ~= "gone" then
		if not sense.missing then
			pass.missingSince = nil
		else
			local since = pass.missingSince
			if since == nil then
				pass.missingSince = now
			elseif now - since >= PASS.absent then
				enter(pass, "gone", now)
				return { { kind = "closeStaff" } }
			end
			return {}
		end
	end
	if (phase == "walk" or phase == "pause") and sense.spotted then
		enter(pass, "chase", now)
		pass.calmSince = nil
		return { { kind = "chase" } }
	end
	if phase == "opening" then
		if now - pass.since < PASS.enter then
			return {}
		end
		enter(pass, "walk", now)
		return { { kind = "walk", position = lane[pass.at] } }
	elseif phase == "walk" then
		return if sense.arrived then arrive(pass, sense, lane) else {}
	elseif phase == "pause" then
		if now - pass.since < PASS.pause then
			return {}
		end
		pass.paused = true
		enter(pass, "walk", now)
		return onward(pass, lane)
	elseif phase == "chase" then
		if sense.hunting then
			pass.calmSince = nil
			return {}
		end
		local calm = pass.calmSince
		if calm == nil then
			pass.calmSince = now
			return {}
		end
		if now - calm < PASS.calm then
			return {}
		end
		pass.paused = true
		pass.at = #lane - 1
		enter(pass, "walk", now)
		return { { kind = "walk", position = lane[pass.at] } }
	elseif phase == "closing" then
		if now - pass.since < PASS.slam then
			return {}
		end
		enter(pass, "gone", now)
		return { { kind = "park" }, { kind = "closeStaff" } }
	elseif phase == "gone" then
		if pass.caught and now - pass.since >= PASS.retry then
			pass.phase = "offstage"
			return TrainingPassRules.begin(pass, now)
		end
	end
	return {}
end

-- He caught the player this pass (the stop is not done when he leaves; he comes round again).
function TrainingPassRules.caught(pass: Pass)
	pass.caught = true
end

-- He has left and caught nobody: the stop is done.
function TrainingPassRules.clean(pass: Pass): boolean
	return pass.phase == "gone" and not pass.caught
end

return TrainingPassRules
