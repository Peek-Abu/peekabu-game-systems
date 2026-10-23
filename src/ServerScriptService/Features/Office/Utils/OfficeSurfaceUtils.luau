--!strict
--[=[
	OfficeSurfaceUtils: what stands on, and what fits under, an office furniture proxy: where a spot stands on a part
	whose art reports its own top, and whether a hider fits in the free space under a desk or table proxy. Pure.

	@class OfficeSurfaceUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideHugFormulas = require(ReplicatedStorage.Shared.Features.Hide.Utils.HideHugFormulas)

local OfficeSurfaceUtils = {}

--[=[
	Where a spot stands on a furniture part whose art reports a support height (`support`, up from the part's bottom:
	ArtVisualSystem's ArtSupportSurfaceY, set when the art's top is not the proxy's): the part's frame moved to that
	height. Nil when the part reports none (the spot uses the marker's surface top).
]=]
function OfficeSurfaceUtils.surfaceOnPart(frame: CFrame, size: Vector3, support: unknown): CFrame?
	if type(support) ~= "number" then
		return nil
	end
	return frame * CFrame.new(0, support - size.Y / 2, 0)
end

--[=[
	Whether a hider fits under furniture of `kind` with this proxy size: HUG_FREE_MIN of clear room on every axis of
	the free box under it (HideHugFormulas.freeSize of FURNITURE[kind].free: between the legs, under the top and brace),
	not of its outer size. A kind with no free box (the cabinet: hidden inside, not under) always fits.
]=]
function OfficeSurfaceUtils.canHideUnder(kind: HideConstants.FurnitureKind, size: Vector3): boolean
	local free = HideConstants.FURNITURE[kind].free
	if free == nil then
		return true
	end
	local room = HideHugFormulas.freeSize(free, size)
	local hug = HideConstants.HUG_FREE_MIN
	return room.X >= hug.X and room.Y >= hug.Y and room.Z >= hug.Z
end

return OfficeSurfaceUtils
