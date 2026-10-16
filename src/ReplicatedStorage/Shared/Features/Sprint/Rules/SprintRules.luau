--!strict
--[=[
	SprintRules: whether a player sprints right now (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md
	§3): they ask (the key is held), they are alive and free (not frozen in a catch, not hiding), their hands are empty
	(carrying anything never sprints, pockets are fine) and the bar allows it. Shared: the phone's SPRINT button shows
	by the same hands rule. Pure.

	@class SprintRules
]=]

export type Input = {
	requested: boolean,
	alive: boolean,
	frozen: boolean,
	hidden: boolean,
	carrying: boolean,
	-- SprintStaminaFormulas.canStart for the bar now.
	stamina: boolean,
}

local SprintRules = {}

function SprintRules.canSprint(input: Input): (boolean, string?)
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
	if input.carrying then
		return false, "hands full"
	end
	if not input.stamina then
		return false, "winded"
	end
	return true, nil
end

--[=[
	Whether the phone's SPRINT button is offered: with empty hands, not hiding.
]=]
function SprintRules.offered(carrying: boolean, hidden: boolean): boolean
	return not carrying and not hidden
end

return SprintRules
