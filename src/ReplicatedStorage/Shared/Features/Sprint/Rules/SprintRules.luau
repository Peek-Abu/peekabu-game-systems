--!strict
--[=[
	SprintRules: whether a player sprints right now (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md
	§3): they ask (the key is held), they are alive and free (not frozen in a catch, not hiding) and the bar allows it.
	Carrying is allowed: the load slows the sprint as it slows the walk (SprintSpeedFormulas). Shared: the phone's
	SPRINT button shows by the same rule. Pure.

	@class SprintRules
]=]

export type Input = {
	requested: boolean,
	alive: boolean,
	frozen: boolean,
	hidden: boolean,
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
	if not input.stamina then
		return false, "winded"
	end
	return true, nil
end

--[=[
	Whether the phone's SPRINT button is offered: whenever the player is not hiding.
]=]
function SprintRules.offered(hidden: boolean): boolean
	return not hidden
end

return SprintRules
