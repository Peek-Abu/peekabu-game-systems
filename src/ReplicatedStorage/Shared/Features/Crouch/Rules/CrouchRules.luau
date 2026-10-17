--!strict
--[=[
	CrouchRules: whether a player crouches right now: they ask, they are alive and free (not frozen in a catch, not
	hiding), they are not sprinting (a sprint ends the crouch: SprintServiceServer:wantsToSprint), and their hands are
	empty or hold a small item, the same sizes a hiding spot takes (HideConstants.POCKETABLE_SIZES). Shared: the phone's
	CROUCH button shows by the same rule. Pure.

	@class CrouchRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

export type Input = {
	requested: boolean,
	alive: boolean,
	frozen: boolean,
	hidden: boolean,
	-- Sprinting, or asking to sprint with the stamina to start.
	sprinting: boolean,
	-- The cargo size of the hands item (nil empty-handed; "unknown" for a held thing that is not cargo).
	heldSize: string?,
}

local CrouchRules = {}

function CrouchRules.canCrouch(input: Input): (boolean, string?)
	if not input.requested then
		return false, "not asked"
	end
	if not input.alive then
		return false, "not alive"
	end
	if input.frozen then
		return false, "frozen"
	end
	if input.hidden then
		return false, "hidden"
	end
	if input.sprinting then
		return false, "sprinting"
	end
	local held = input.heldSize
	if held ~= nil and HideConstants.POCKETABLE_SIZES[held] ~= true then
		return false, "hands full"
	end
	return true, nil
end

--[=[
	Whether the phone's CROUCH button is offered: whenever the player is not hiding.
]=]
function CrouchRules.offered(hidden: boolean): boolean
	return not hidden
end

return CrouchRules
