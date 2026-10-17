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
	reveals anyway (the reason is logged). Pure.

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

-- The first condition still missing, or nil.
local function missing(input: VerdictInput): string?
	local scene = ShiftTransitRules.scene(input)
	if scene ~= nil then
		return scene
	end
	local seconds = if input.cold
		then ShiftConstants.TRANSIT_COLD_SETTLE_SECONDS
		else ShiftConstants.TRANSIT_SETTLE_SECONDS
	local frames = if input.cold
		then ShiftConstants.TRANSIT_COLD_SETTLE_FRAMES
		else ShiftConstants.TRANSIT_SETTLE_FRAMES
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

return ShiftTransitRules
