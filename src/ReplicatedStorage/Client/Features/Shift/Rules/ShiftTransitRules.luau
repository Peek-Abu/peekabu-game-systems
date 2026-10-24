--!strict
--[=[
	ShiftTransitRules: what this client's transit screen shows, and whether a held client may reveal (ShiftTransitSystem).

	`cover`: the route slip while the client is held (and through its ARRIVED stamp), plain black while the client
	boots (until its first sync, so nothing unlit shows) and during a respawn blink; otherwise nothing.

	`verdict`: a held client is ready once its hold is built and the new office is here (its layout seed seen), its
	character stands within TRANSIT_PLACE_TOLERANCE of its spot, the area around the spot is streamed in, the lighting
	preset is applied (`scene`), that scene has then held still for TRANSIT_SETTLE_SECONDS and TRANSIT_SETTLE_FRAMES
	rendered frames (TRANSIT_COLD_SETTLE_SECONDS and _FRAMES when the camera arrived from far away: `cold`), and the
	slip has been up TRANSIT_MIN_SECONDS. The settle is the engine's own light catching up: right after the camera lands
	in a newly built, newly streamed office the render is still dark (about a second when the camera was nearby,
	several the first time it arrives from the depot) although every Lighting value and light is already set, and no
	API reports when it is done, so the screen waits for the scene to stop changing for a while, counted in time AND
	frames so a slow client waits longer. Short of that it waits (with the first condition still missing), until TRANSIT_CLIENT_TIMEOUT, when it
	reveals anyway (the reason is logged).

	`progress`: how far along those stages the client is (0..1), which the load screen's bar draws.

	`entranceSettled`: whether an office entrance's black cover may lift, from the frame times since the server's
	uncover arrived: ENTRANCE_SETTLE_FRAMES quick frames in a row, or ENTRANCE_SETTLE_MAX_SECONDS in all. Pure.

	@class ShiftTransitRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type CoverInput = {
	-- Held by a transit this client has not finished (or showing its ARRIVED stamp).
	held: boolean,
	-- Booting: no shift sync yet, within TRANSIT_BOOT_SECONDS.
	booting: boolean,
	-- A respawn blink runs until this os.clock() time.
	blinkUntil: number?,
	now: number,
}

export type VerdictInput = {
	hold: ShiftTypes.TransitHold,
	-- Seconds the slip has been up for this hold.
	shownFor: number,
	-- The office with the hold's layout seed is in the workspace (true when the hold names no seed).
	seedSeen: boolean,
	-- The local character's root, nil without one.
	position: Vector3?,
	streamed: boolean,
	lit: boolean,
	-- Seconds, and rendered frames, since the scene was last incomplete or changed (ShiftTransitSystem).
	settledFor: number,
	settledFrames: number,
	-- The camera arrived from more than TRANSIT_COLD_DISTANCE away during this hold (from the depot).
	cold: boolean,
}

local ShiftTransitRules = {}

function ShiftTransitRules.cover(input: CoverInput): ShiftTypes.TransitCover
	if input.held then
		return "slip"
	end
	if input.booting then
		return "black"
	end
	local blinkUntil = input.blinkUntil
	if blinkUntil ~= nil and input.now < blinkUntil then
		return "black"
	end
	return "none"
end

--[=[
	The first of the scene's own conditions still missing (office, placed, streamed, lighting), or nil once the scene is
	complete. The settle and the minimum time are not checked.
]=]
function ShiftTransitRules.scene(input: VerdictInput): string?
	local hold = input.hold
	if not hold.built or not input.seedSeen then
		return "office"
	end
	local position = input.position
	local spot = hold.spot
	if typeof(position) ~= "Vector3" or spot == nil then
		return "placed"
	end
	if (position - spot).Magnitude > ShiftConstants.TRANSIT_PLACE_TOLERANCE then
		return "placed"
	end
	if not input.streamed then
		return "streamed"
	end
	if not input.lit then
		return "lighting"
	end
	return nil
end

-- The settle this hold needs: seconds and rendered frames (longer when the camera arrived from far away).
local function settleOf(input: VerdictInput): (number, number)
	if input.cold then
		return ShiftConstants.TRANSIT_COLD_SETTLE_SECONDS, ShiftConstants.TRANSIT_COLD_SETTLE_FRAMES
	end
	return ShiftConstants.TRANSIT_SETTLE_SECONDS, ShiftConstants.TRANSIT_SETTLE_FRAMES
end

-- The first condition still missing, or nil.
local function missing(input: VerdictInput): string?
	local scene = ShiftTransitRules.scene(input)
	if scene ~= nil then
		return scene
	end
	local seconds, frames = settleOf(input)
	if input.settledFor < seconds or input.settledFrames < frames then
		return "settling"
	end
	if input.shownFor < ShiftConstants.TRANSIT_MIN_SECONDS then
		return "minimum"
	end
	return nil
end

function ShiftTransitRules.verdict(input: VerdictInput): (ShiftTypes.TransitVerdict, string?)
	local reason = missing(input)
	if reason == nil then
		return "ready", nil
	end
	if input.shownFor >= ShiftConstants.TRANSIT_CLIENT_TIMEOUT then
		return "timeout", reason
	end
	return "waiting", reason
end

-- Where each stage starts on the loading bar: the scene's conditions in the order they are met, the settle (filled by
-- its own progress), then the minimum time up to MINIMUM_END. Full only once ready.
ShiftTransitRules.PROGRESS = table.freeze({
	built = 0.08,
	placed = 0.15,
	streamed = 0.3,
	lighting = 0.45,
	settling = 0.55,
	minimum = 0.92,
	minimumEnd = 0.98,
})

--[=[
	How far this held client is toward its reveal (0..1), for the load screen's bar: the stage it is waiting for
	(PROGRESS), the settle filled by the slower of its time and its frames, the minimum time by how long the slip has
	been up; 1 once ready. It can step back when a condition is lost again (the scene restarts its settle): the bar
	that draws it never does (ShiftTransitViewModel.advance).
]=]
function ShiftTransitRules.progress(input: VerdictInput): number
	local reason = missing(input)
	local stage = ShiftTransitRules.PROGRESS
	if reason == nil then
		return 1
	elseif reason == "office" then
		return if input.hold.built then stage.built else 0
	elseif reason == "placed" then
		return stage.placed
	elseif reason == "streamed" then
		return stage.streamed
	elseif reason == "lighting" then
		return stage.lighting
	elseif reason == "settling" then
		local seconds, frames = settleOf(input)
		local done = math.clamp(math.min(input.settledFor / seconds, input.settledFrames / frames), 0, 1)
		return stage.settling + (stage.minimum - stage.settling) * done
	end
	local done = math.clamp(input.shownFor / ShiftConstants.TRANSIT_MIN_SECONDS, 0, 1)
	return stage.minimum + (stage.minimumEnd - stage.minimum) * done
end

--[=[
	Whether an entrance's cover may lift: `frames` are the frame times (s) since the uncover arrived, oldest first. True
	once the last ENTRANCE_SETTLE_FRAMES were each under ENTRANCE_SETTLE_FRAME_SECONDS, or they total
	ENTRANCE_SETTLE_MAX_SECONDS or more.
]=]
function ShiftTransitRules.entranceSettled(frames: { number }): boolean
	local total, quick = 0, 0
	for _, seconds in frames do
		total += seconds
		quick = if seconds < ShiftConstants.ENTRANCE_SETTLE_FRAME_SECONDS then quick + 1 else 0
	end
	return quick >= ShiftConstants.ENTRANCE_SETTLE_FRAMES or total >= ShiftConstants.ENTRANCE_SETTLE_MAX_SECONDS
end

return ShiftTransitRules
