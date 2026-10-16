--!strict
--[=[
	OccupantFaceUtils: which painted face the Manager's porcelain mask shows in each mode ("A - Smile Mask",
	characters/manager): the calm customer-service smile on patrol and on break, the noticing face (pupils
	pinpoint and shift) while he investigates or searches, the hunting face (eyes wide, smile wider) while he
	chases or catches. The faces are SurfaceAppearances in his template's `Faces` folder (OccupantAssets.FACES);
	OccupantRigSystem puts the chosen one on his FacePlate. Pure.

	@class OccupantFaceUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

local OccupantFaceUtils = {}

function OccupantFaceUtils.faceFor(mode: OccupantTypes.Mode): OccupantAssets.Face
	if mode == "investigate" or mode == "search" then
		return "Noticing"
	elseif mode == "chase" or mode == "catch" then
		return "Hunting"
	end
	return "Calm"
end

return OccupantFaceUtils
