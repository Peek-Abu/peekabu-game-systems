--!strict
--[=[
	AbilityTypes: the employee abilities (docs/superpowers/specs/2026-10-29-employee-abilities-design.md).

	@class AbilityTypes
]=]

export type AbilityId = "letsGo" | "spotIt" | "pottedPlant"

-- Animation registry keys (AnimationAbilityRegistry) an ability plays; all optional (a clip still to come plays
-- nothing, the effect never waits for it). `full` / `upper`: standing still / moving; `enter` / `hold` / `exit`: a
-- held pose (the plant).
export type AbilityClips = {
	full: string?,
	upper: string?,
	enter: string?,
	hold: string?,
	exit: string?,
}

export type AbilityDef = {
	id: AbilityId,
	-- The employee (EmployeeRegistry name) whose ability this is.
	employee: string,
	-- Seconds from a use until it is ready again.
	cooldown: number,
	-- Seconds the effect lasts (the plant: at most).
	duration: number,
	-- Studs around the user an effect reaches (Let's Go!'s crew).
	radius: number?,
	-- The speed scale (Let's Go!).
	scale: number?,
	clips: AbilityClips,
}

-- Why a use is refused (AbilityRules.canUse), in the order it checks.
export type Reason =
	"noAbility"
	| "notRunning"
	| "notPlaying"
	| "dead"
	| "caught"
	| "hidden"
	| "cooldown"
	| "airborne"
	| "holding"
	| "nothing"

-- Why a running plant ends (AbilityRules.plantEnds).
export type EndReason = "moved" | "jumped" | "acted" | "timeout" | "dead" | "caught" | "cancelled"

return {}
