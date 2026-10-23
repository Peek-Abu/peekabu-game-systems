--!strict
--[=[
	OfficeSurfaceUtils: what stands on, and what fits under, an office furniture proxy: where a spot stands on a part
	whose art reports its own top, and whether a hider fits under a table proxy. Pure.

	@class OfficeSurfaceUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

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
	Whether a hider fits under table furniture of this proxy size: HUG_FREE_MIN of clear room on every axis.
]=]
function OfficeSurfaceUtils.canHideUnder(size: Vector3): boolean
	local hug = HideConstants.HUG_FREE_MIN
	return size.X >= hug.X and size.Y >= hug.Y and size.Z >= hug.Z
end

return OfficeSurfaceUtils
