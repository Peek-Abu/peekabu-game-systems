--!strict
--[=[
	HideSpotUtils: where a hiding spot puts things, from its furniture's frame and size (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). The spot's front is its frame's local -Z (the desk's knee-hole, or
	whichever side of a table faces the room: `spotFrame`), standing on the floor under its centre.

	- `hide`: the hiding root. It stands where a standing root would (`standHeight` over the floor; the tucked pose,
	  HidePoseFormulas, folds the body down onto the floor), placed and turned by the furniture's tuck (HideConstants:
	  across a desk's knee-hole, along a table), so the huddled body lies under the top.
	- `peek`: the camera, low by the front edge, looking out of the front.
	- `prompt`: the prompt's offset on the front face (furniture space).
	- `exits`: where the body may come out, in order: in front, behind, then either side.

	`standHeight` is the character's root height over its feet (HipHeight plus half the root). Pure.

	@class HideSpotUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)

local HideSpotUtils = {}

--[=[
	The kind of spot a piece of furniture offers, or nil when it offers none.
]=]
function HideSpotUtils.spotOf(furniture: string): HideTypes.SpotKind?
	local def = HideConstants.FURNITURE[furniture]
	return if def ~= nil then def.spot else nil
end

--[=[
	The spot's own frame: the furniture's, turned half round when its back (+Z) has more open floor than its front
	(-Z) by more than OPEN_MARGIN studs and the furniture may turn (a table, never a desk) (`frontClear` / `backClear`: how far the floor is clear each way), so the peek
	and the way in and out face the room, not a wall.
]=]
function HideSpotUtils.spotFrame(noun: string, furniture: CFrame, frontClear: number, backClear: number): CFrame
	local def = HideConstants.FURNITURE[noun]
	if def ~= nil and def.turnable and backClear > frontClear + HideConstants.OPEN_MARGIN then
		return furniture * CFrame.Angles(0, math.pi, 0)
	end
	return furniture
end

function HideSpotUtils.frames(noun: string, furniture: CFrame, size: Vector3, standHeight: number): HideTypes.SpotFrames
	-- The floor under the furniture's centre, turned like it (its LookVector is the front, local -Z).
	local floor = furniture * CFrame.new(0, -size.Y / 2, 0)
	local def = HideConstants.FURNITURE[noun]
	local tuck: HideConstants.Tuck = if def ~= nil then def.tuck else { along = 0, back = 0, yaw = 0 }
	local hide = floor * CFrame.new(tuck.along, standHeight, tuck.back) * CFrame.Angles(0, math.rad(tuck.yaw), 0)
	local front = -size.Z / 2
	local peek = floor * CFrame.new(0, HideConstants.UNDER_EYE, front + 0.15)
	local promptY = math.min(size.Y / 2, 2.5) - size.Y / 2
	local outZ = size.Z / 2 + HideConstants.EXIT_GAP
	local outX = size.X / 2 + HideConstants.EXIT_GAP
	local exits = {
		floor * CFrame.new(0, standHeight, -outZ),
		floor * CFrame.new(0, standHeight, outZ) * CFrame.Angles(0, math.pi, 0),
		floor * CFrame.new(-outX, standHeight, 0) * CFrame.Angles(0, math.pi / 2, 0),
		floor * CFrame.new(outX, standHeight, 0) * CFrame.Angles(0, -math.pi / 2, 0),
	}
	return {
		hide = hide,
		peek = peek,
		prompt = Vector3.new(0, promptY, front - 0.3),
		exits = exits,
	}
end

return HideSpotUtils
