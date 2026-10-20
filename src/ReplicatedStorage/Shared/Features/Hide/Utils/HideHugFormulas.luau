--!strict
--[=[
	HideHugFormulas: the owner's knee-hug hide pose as joint Transforms, the same on every client. `pose` turns
	HideConstants.HUG_POSE (degrees, XYZ, by Motor6D name) into a CFrame per joint. Pure.

	@class HideHugFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

local HideHugFormulas = {}

--[=[
	The hug pose's Transform for each joint it moves, by Motor6D name.
]=]
function HideHugFormulas.pose(): { [string]: CFrame }
	local transforms: { [string]: CFrame } = {}
	for _, entry in HideConstants.HUG_POSE do
		local r = entry.rotation
		transforms[entry.joint] = CFrame.new(entry.offset)
			* CFrame.fromEulerAnglesXYZ(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end
	return transforms
end

return HideHugFormulas
