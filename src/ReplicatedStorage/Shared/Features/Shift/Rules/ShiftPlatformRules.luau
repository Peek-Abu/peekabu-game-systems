--!strict
--[=[
	ShiftPlatformRules: the device a client reports for analytics (Cleanup Crew spec §6.4: "The client-reported
	platform (for analytics) is accepted only from a fixed enum"). The client `detect`s its platform from engine
	signals and sends its `code`; the server `parse`s the code and accepts only 1..4. Nothing gameplay-related ever
	reads the platform. Pure.

	@class ShiftPlatformRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type Platform = ShiftTypes.Platform

-- What the client can see about its device.
export type Signals = {
	touch: boolean,
	keyboard: boolean,
	gamepad: boolean,
	tenFoot: boolean,
	-- The viewport's shorter side in pixels.
	shortSide: number,
}

-- The fixed enum: a platform's code is its index ("unknown" has none and is never sent).
local BY_CODE: { Platform } = { "pc", "phone", "tablet", "console" }

local ShiftPlatformRules = {}

-- A touch-only screen whose short side is below this is a phone; otherwise a tablet.
ShiftPlatformRules.PHONE_SHORT_SIDE = 600

function ShiftPlatformRules.detect(signals: Signals): Platform
	if signals.tenFoot then
		return "console"
	end
	if signals.touch and not signals.keyboard then
		return if signals.shortSide < ShiftPlatformRules.PHONE_SHORT_SIDE then "phone" else "tablet"
	end
	if signals.keyboard then
		return "pc"
	end
	if signals.gamepad then
		return "console"
	end
	return "unknown"
end

function ShiftPlatformRules.code(platform: Platform): number
	return table.find(BY_CODE, platform) or 0
end

--[=[
	The platform for a reported code, or nil for anything outside the fixed enum.
]=]
function ShiftPlatformRules.parse(raw: unknown): Platform?
	if type(raw) ~= "number" then
		return nil
	end
	if raw % 1 ~= 0 or raw < 1 or raw > #BY_CODE then
		return nil
	end
	return BY_CODE[raw]
end

return ShiftPlatformRules
