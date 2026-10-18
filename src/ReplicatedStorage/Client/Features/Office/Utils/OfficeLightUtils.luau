--!strict
--[=[
	OfficeLightUtils: the broken fluorescents (Cleanup Crew spec §7 "dim, buzzing fluorescents (some flickering)").
	A light is broken by a stable hash of where it hangs (lights never move), so every client and every shift
	agrees; only broken lights within a radius of the camera are animated; a broken light is full most of the time
	and blinks dim when its noise dips (a slow, irregular blink, distinct from the fast flicker that means Harlow is
	near). Pure.

	@class OfficeLightUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAtmosphereConstants = require(ReplicatedStorage.Client.Features.Office.Data.OfficeAtmosphereConstants)

local OfficeLightUtils = {}

--[=[
	A stable 0..1 value for a light's position.
]=]
function OfficeLightUtils.hash(position: Vector3): number
	local value = math.sin(position.X * 12.9898 + position.Z * 78.233) * 43758.5453
	return value - math.floor(value)
end

function OfficeLightUtils.broken(position: Vector3, fraction: number): boolean
	return OfficeLightUtils.hash(position) < fraction
end

--[=[
	The indices of the broken lights within `radius` of `center`, in order.
]=]
function OfficeLightUtils.nearbyBroken(
	positions: { Vector3 },
	center: Vector3,
	radius: number,
	fraction: number
): { number }
	local list: { number } = {}
	for index, position in positions do
		if (position - center).Magnitude <= radius and OfficeLightUtils.broken(position, fraction) then
			table.insert(list, index)
		end
	end
	return list
end

--[=[
	A broken light's brightness factor at `now`: 1, or BROKEN_DIM while its noise is below BROKEN_THRESHOLD.
]=]
function OfficeLightUtils.glow(now: number, seed: number): number
	local noise = math.noise(now * OfficeAtmosphereConstants.BROKEN_RATE, seed * 7.31)
	if noise < OfficeAtmosphereConstants.BROKEN_THRESHOLD then
		return OfficeAtmosphereConstants.BROKEN_DIM
	end
	return 1
end

--[=[
	Whether a broken tube's blink starting at `now` zaps: only the first blink of a burst (the tube's previous blink
	began at least ZAP_BURST_GAP ago), at least ZAP_TUBE_GAP after this tube's last zap, and at least ZAP_GLOBAL_GAP
	after any tube's last zap, so a room of blinking tubes is an occasional accent, not a stream. `nil` is "never".
]=]
function OfficeLightUtils.zaps(now: number, lastBlink: number?, lastTubeZap: number?, lastAnyZap: number?): boolean
	if lastBlink ~= nil and now - lastBlink < OfficeAtmosphereConstants.ZAP_BURST_GAP then
		return false
	end
	if lastTubeZap ~= nil and now - lastTubeZap < OfficeAtmosphereConstants.ZAP_TUBE_GAP then
		return false
	end
	if lastAnyZap ~= nil and now - lastAnyZap < OfficeAtmosphereConstants.ZAP_GLOBAL_GAP then
		return false
	end
	return true
end

return OfficeLightUtils
