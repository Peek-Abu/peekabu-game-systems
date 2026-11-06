--!strict
--[=[
	SprintSpeedCheckRules: the movement anti-cheat's speed check. Each tick the server measures a body's ground speed
	from its own replicated positions (vertical movement never counts: falling is fine) against the walk the server
	set (Humanoid.WalkSpeed, which already holds every sprint, boost, drag and carry slow). Only a run kept over the
	limit (TOLERANCE x the walk + SLACK) for STREAK_SECONDS in a row is a cheat: the verdict "rubberband" sends the body
	back to where that run began. A short burst (a bump, a slope, a replication hiccup) is forgiven the moment the
	speed drops back. One step longer than JUMP_STUDS is a "jump" (the server's own teleports: entrances, the truck, a
	respawn) and never counts. Nothing is checked while `exempt` (ragdolled, anchored, seated, hiding). Pure.

	@class SprintSpeedCheckRules
]=]

export type State = {
	-- Seconds the body has stayed over the limit, and where that run began.
	streak: number,
	anchor: Vector3?,
}

export type Sample = {
	dt: number,
	last: Vector3,
	position: Vector3,
	-- The walk the server set (studs/s).
	limit: number,
	exempt: boolean,
}

export type Verdict = "ok" | "jump" | "rubberband"

local SprintSpeedCheckRules = {
	-- The limit: TOLERANCE x the walk + SLACK studs/s (a lag catch-up, a downhill run).
	TOLERANCE = 1.5,
	SLACK = 8,
	-- How long a run over the limit may last before the body is sent back.
	STREAK_SECONDS = 1.5,
	-- One step longer than this is a teleport, not a run.
	JUMP_STUDS = 40,
}

function SprintSpeedCheckRules.fresh(): State
	return { streak = 0, anchor = nil }
end

local function clear(state: State)
	state.streak = 0
	state.anchor = nil
end

--[=[
	Updates `state` with one tick's movement. Returns the verdict and, for "rubberband", where to send the body.
]=]
function SprintSpeedCheckRules.step(state: State, sample: Sample): (Verdict, Vector3?)
	if sample.exempt or sample.dt <= 0 then
		clear(state)
		return "ok", nil
	end
	local delta = sample.position - sample.last
	local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if distance > SprintSpeedCheckRules.JUMP_STUDS then
		clear(state)
		return "jump", nil
	end
	local allowed = sample.limit * SprintSpeedCheckRules.TOLERANCE + SprintSpeedCheckRules.SLACK
	if distance / sample.dt <= allowed then
		clear(state)
		return "ok", nil
	end
	if state.anchor == nil then
		state.anchor = sample.last
	end
	state.streak += sample.dt
	if state.streak >= SprintSpeedCheckRules.STREAK_SECONDS - 1e-6 then
		local anchor = state.anchor
		clear(state)
		return "rubberband", anchor
	end
	return "ok", nil
end

return SprintSpeedCheckRules
