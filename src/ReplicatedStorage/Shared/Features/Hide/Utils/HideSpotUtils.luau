--!strict
--[=[
	HideSpotUtils: where a hiding spot puts things, from its furniture's frame and size (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). The furniture's front is its local -Z (the desk's knee-hole, the
	locker's door, the cabinet's drawers), standing on the floor under its centre.

	- `hide`: the hiding root, facing out of the front. Under a desk or table the body is sunk until the head's top
	  (HEAD_ABOVE_ROOT over the root) clears the underside by UNDER_CLEARANCE; inside, it stands, sunk only when the
	  piece is shorter than the body (a filing cabinet).
	- `peek`: the camera, looking out of the front: low by the front edge under furniture, near the top inside.
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

function HideSpotUtils.frames(
	kind: HideTypes.SpotKind,
	furniture: CFrame,
	size: Vector3,
	standHeight: number
): HideTypes.SpotFrames
	-- The floor under the furniture's centre, turned like it (its LookVector is the front, local -Z).
	local floor = furniture * CFrame.new(0, -size.Y / 2, 0)
	local ceiling = size.Y - HideConstants.UNDER_CLEARANCE
	local sink = math.max(0, standHeight + HideConstants.HEAD_ABOVE_ROOT - ceiling)
	local rootY = standHeight - sink
	local hide = floor * CFrame.new(0, rootY, if kind == "under" then -size.Z * 0.1 else 0)
	local eye = if kind == "under" then HideConstants.UNDER_EYE else size.Y - HideConstants.INSIDE_EYE_FROM_TOP
	local front = -size.Z / 2
	local peek = floor * CFrame.new(0, eye, if kind == "under" then front + 0.15 else front + 0.25)
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
