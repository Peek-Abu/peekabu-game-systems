--!strict
--[=[
	AbilityClipUtils: which of an ability's clips to play over its effect (owner, 2026-11-03: the clips looked wrong
	while running, walking or holding the vacuum). A full-body clip owns the legs, so it only plays standing still; on
	the move the upper-body cut plays (its legs are left to the walk or run), or nothing when there is none. With busy
	hands (the vacuum's wand out, something carried) the arms are held by their IK grip, which a clip would fight, so
	nothing plays. `keeps` says whether a clip already playing may go on as its user starts moving or takes something
	in hand. The effect never depends on any of this. Pure.

	@class AbilityClipUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityTypes = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityTypes)

export type ClipKind = "full" | "upper"

local AbilityClipUtils = {}

--[=[
	The clip key to play and its kind, or nil to play nothing.
]=]
function AbilityClipUtils.pick(
	clips: AbilityTypes.AbilityClips,
	moving: boolean,
	handsBusy: boolean
): (string?, ClipKind?)
	if handsBusy then
		return nil, nil
	end
	local full, upper = clips.full, clips.upper
	if not moving and full ~= nil then
		return full, "full"
	elseif upper ~= nil then
		return upper, "upper"
	end
	return nil, nil
end

--[=[
	Whether a playing clip of `kind` may go on now.
]=]
function AbilityClipUtils.keeps(kind: ClipKind, moving: boolean, handsBusy: boolean): boolean
	if handsBusy then
		return false
	end
	return kind == "upper" or not moving
end

return AbilityClipUtils
