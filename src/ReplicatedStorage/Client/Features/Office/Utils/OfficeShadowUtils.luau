--!strict
--[=[
	OfficeShadowUtils: whether the office's small props cast shadows on this client (1,300 of them do, a real cost on a
	phone). MODE switches it: "on" always, "off" never, "auto" off at graphics
	quality 1-3 and on a phone left on Automatic, on otherwise. A small prop is a part whose every side is under
	SIZE_LIMIT studs (keyboards, mugs, lamps), so walls, desks and floors always keep their shadows. Pure.

	@class OfficeShadowUtils
]=]

export type Mode = "auto" | "on" | "off"

-- THE switch, for measuring on a phone and for shipping (annotated so the field keeps its Mode type).
local MODE: Mode = "auto"

local OfficeShadowUtils = {
	MODE = MODE,
	-- Every side under this many studs is a small prop.
	SIZE_LIMIT = 4,
	-- "auto" turns small-prop shadows off at this graphics level and below.
	LOW_QUALITY = 3,
}

function OfficeShadowUtils.smallProp(size: Vector3): boolean
	local limit = OfficeShadowUtils.SIZE_LIMIT
	return size.X < limit and size.Y < limit and size.Z < limit
end

--[=[
	Whether small props cast shadows: `quality` 1-10 (nil = Automatic), `phone` a touch device with no keyboard.
]=]
function OfficeShadowUtils.propShadows(mode: Mode, quality: number?, phone: boolean): boolean
	if mode == "on" then
		return true
	elseif mode == "off" then
		return false
	end
	if quality == nil then
		return not phone
	end
	return quality > OfficeShadowUtils.LOW_QUALITY
end

--[=[
	The graphics level a SavedQualitySetting names (1-10), nil for Automatic.
]=]
function OfficeShadowUtils.qualityOf(setting: Enum.SavedQualitySetting): number?
	local level = string.match(setting.Name, "^QualityLevel(%d+)$")
	return if level ~= nil then tonumber(level) else nil
end

return OfficeShadowUtils
