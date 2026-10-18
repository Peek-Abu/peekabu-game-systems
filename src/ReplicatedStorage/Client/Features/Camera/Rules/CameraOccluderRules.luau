--!strict
--[=[
	CameraOccluderRules: whether a part the camera's sweep hits stops the camera (CameraOcclusionSystem).

	The engine's rule (Poppercam's `canOcclude`) plus one addition: a part flagged CameraOccluderConstants.ATTRIBUTE
	(an invisible collision proxy that stands for its art) blocks however transparent it is.
	- flagged true: blocks; flagged false: never blocks.
	- otherwise: it must collide and be opaque (Transparency combined with LocalTransparencyModifier below 0.25).
	- a TrussPart never blocks.

	@class CameraOccluderRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)

-- The engine's opacity cut-off (Poppercam): at or above this a part counts as see-through.
local SEE_THROUGH = 0.25

local CameraOccluderRules = {}

function CameraOccluderRules.blocks(part: BasePart): boolean
	if part:IsA("TrussPart") then
		return false
	end
	local flagged = part:GetAttribute(CameraOccluderConstants.ATTRIBUTE)
	if type(flagged) == "boolean" then
		return flagged
	end
	local total = 1 - (1 - part.Transparency) * (1 - part.LocalTransparencyModifier)
	return part.CanCollide and total < SEE_THROUGH
end

return CameraOccluderRules
