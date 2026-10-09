--!strict
--[=[
	InteractionRules: whether a prompt trigger counts. Pure: the shell measures, this decides.

	Order: a missing character, then disabled, then distance, then cooldown — the first failure is the
	reason returned.

	@class InteractionRules
]=]

export type CheckInput = {
	hasCharacter: boolean,
	-- Studs from the player's root to the object.
	distance: number,
	maxDistance: number,
	tolerance: number,
	enabled: boolean,
	-- Seconds left on this player's cooldown for this object (0 = ready).
	cooldownRemaining: number,
}

export type Refusal = "no-character" | "disabled" | "too-far" | "cooldown"

local InteractionRules = {}

function InteractionRules.check(input: CheckInput): (boolean, Refusal?)
	if not input.hasCharacter then
		return false, "no-character"
	end
	if not input.enabled then
		return false, "disabled"
	end
	if input.distance > input.maxDistance + input.tolerance then
		return false, "too-far"
	end
	if input.cooldownRemaining > 0 then
		return false, "cooldown"
	end
	return true, nil
end

return InteractionRules
