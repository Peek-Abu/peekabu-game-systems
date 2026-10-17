--!strict
--[=[
	OccupantFaceUtils: which painted face the Manager's porcelain mask shows in each mode ("A - Smile Mask",
	characters/manager): the calm customer-service smile on patrol and on break, the noticing face (pupils
	pinpoint and shift) while he investigates, searches or turns his head to something (alert), the hunting face (eyes wide, smile wider) while he
	chases or catches. At a desk he smiles calmly; in the ambush he smiles AMBUSH_SMILE seconds, then notices; tipping
	his head down under a desk he stays calm TIP_CALM seconds, then hunts; staring at a spot he notices, and hunts as he
	bends to look. The faces are SurfaceAppearances in his template's `Faces` folder (OccupantAssets.FACES);
	OccupantRigSystem puts the chosen one on his FacePlate. Pure.

	@class OccupantFaceUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

local OccupantFaceUtils = {}

--[=[
	The face for `mode`, `phase` (inside work / stare) and `elapsed` seconds into that phase.
]=]
function OccupantFaceUtils.faceFor(
	mode: OccupantTypes.Mode,
	phase: OccupantTypes.Phase?,
	elapsed: number?
): OccupantAssets.Face
	local seconds = elapsed or 0
	if mode == "work" then
		if phase == "ambush" then
			return if seconds < OccupantConstants.AMBUSH_SMILE then "Calm" else "Noticing"
		elseif phase == "tip" then
			return if seconds < OccupantConstants.TIP_CALM then "Calm" else "Hunting"
		elseif phase == "tipHold" then
			return "Hunting"
		end
		return "Calm"
	elseif mode == "stare" then
		return if phase == "check" or phase == "open" then "Hunting" else "Noticing"
	elseif mode == "alert" and (phase == "slowTurn" or phase == "staring") then
		-- A slow turn and the stare (behaviours design §11.2): the customer-service smile comes round last.
		return "Calm"
	elseif mode == "investigate" or mode == "search" or mode == "alert" then
		return "Noticing"
	elseif mode == "chase" or mode == "catch" then
		return "Hunting"
	end
	return "Calm"
end

return OccupantFaceUtils
