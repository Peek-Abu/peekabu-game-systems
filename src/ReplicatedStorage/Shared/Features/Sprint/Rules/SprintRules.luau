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
	-- Crouched (the character's Crouching attribute). The crouch ends when a sprint is asked for
	-- (CrouchServiceServer), so this only holds the sprint back for the tick that stands the player up: a sprint
	-- never starts from the crouch's speed.
	crouching: boolean,
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
	if input.crouching then
		return false, "crouching"
	end
	if not input.stamina then
		return false, "winded"
	end
	return true, nil
end

--[=[
	Whether the phone's SPRINT button is offered: whenever the player is not hiding, unless the move stick runs
	(`stickRun`, SprintConstants.STICK_RUN.enabled): a far push is the run then, and the button goes.
]=]
function SprintRules.offered(hidden: boolean, stickRun: boolean): boolean
	return not hidden and not stickRun
end

export type StickRun = {
	enabled: boolean,
	-- How far (0-1) the touch stick is pushed to start running, and how far it falls back before the run stops.
	threshold: number,
	release: number,
}

--[=[
	Whether the touch move stick asks for a sprint (phone Layout 2, owner pick 11-15): pushed at least `threshold` of
	the way out to start, held until it falls under `release` (`held`: it asks now), so the run does not flicker at the
	edge. Never from a crouch (`crouching`): a sprint stands the player up (CrouchServiceServer), and a far push while
	sneaking must keep sneaking; CROUCH is tapped to stand first.
]=]
function SprintRules.stickRun(magnitude: number, crouching: boolean, held: boolean, settings: StickRun): boolean
	if not settings.enabled or crouching then
		return false
	end
	return magnitude >= (if held then settings.release else settings.threshold)
end

return SprintRules
