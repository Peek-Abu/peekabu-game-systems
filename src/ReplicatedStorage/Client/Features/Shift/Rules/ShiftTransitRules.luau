--!strict
--[=[
	ShiftTransitRules: what this client's transit screen shows, and whether a held client may reveal (ShiftTransitSystem).

	`cover`: the route slip while the client is held (and through its ARRIVED stamp), plain black while the client
	boots (until its first sync, so nothing unlit shows) and during a respawn blink; otherwise nothing.

	`verdict`: a held client is ready once its hold is built and the new office is here (its layout seed seen), its
	character stands within TRANSIT_PLACE_TOLERANCE of its spot, the area around the spot is streamed in, the lighting
	preset is applied and the slip has been up TRANSIT_MIN_SECONDS. Short of that it waits (with the first condition
	still missing), until TRANSIT_CLIENT_TIMEOUT, when it reveals anyway (the reason is logged). Pure.

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

-- The first condition still missing, or nil.
local function missing(input: VerdictInput): string?
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
