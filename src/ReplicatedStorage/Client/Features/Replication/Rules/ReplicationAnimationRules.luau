--!strict
--[=[
	ReplicationAnimationRules: which puppets animate (character replication R3 spec, "Puppet animation LOD"). The engine gives
	client-built rigs no animation LOD (measured 2026-10-02: `EvaluationThrottled` never true, a 790-stud
	off-screen rig kept animating, ~0.1 ms per rig per frame), so puppets get their own:

	| Tier | When | Behaviour |
	|---|---|---|
	| full | on screen and within `fullStuds` | animate every frame |
	| frozen | off screen, or beyond `fullStuds + hysteresisStuds` | animation paused, pose held; position still updates |

	A frozen puppet unfreezes only once it is back on screen AND within `fullStuds` (the hysteresis band stops a
	puppet pacing at the edge from flickering). "On screen" is the camera viewport grown by `edgeMarginPx` on
	every side and in front of the camera. Each puppet is re-evaluated `rateHz` times a second, staggered.

	Pure: the shell supplies distances and viewport points.

	@class ReplicationAnimationRules
]=]

local ReplicationAnimationRules = {}

export type Tier = "full" | "frozen"

export type Config = {
	fullStuds: number, -- LOD_FULL_STUDS
	hysteresisStuds: number, -- LOD_HYSTERESIS
	rateHz: number, -- LOD_RATE_HZ
	edgeMarginPx: number,
}

local defaultConfig: Config = {
	fullStuds = 250,
	hysteresisStuds = 25,
	rateHz = 4,
	edgeMarginPx = 64,
}
ReplicationAnimationRules.DEFAULT_CONFIG = table.freeze(defaultConfig)

--[=[
	Whether a point the camera projected to `viewport` (pixels X/Y, depth Z, as WorldToViewportPoint returns)
	is on screen: in front of the camera and inside the viewport grown by `marginPx`.
]=]
function ReplicationAnimationRules.isOnScreen(viewport: Vector3, viewportSize: Vector2, marginPx: number): boolean
	return viewport.Z > 0
		and viewport.X >= -marginPx
		and viewport.X <= viewportSize.X + marginPx
		and viewport.Y >= -marginPx
		and viewport.Y <= viewportSize.Y + marginPx
end

--[=[
	The tier a puppet moves to from `current`, at `distance` studs from the camera.
]=]
function ReplicationAnimationRules.decide(current: Tier, distance: number, onScreen: boolean, config: Config): Tier
	if current == "full" then
		if not onScreen or distance > config.fullStuds + config.hysteresisStuds then
			return "frozen"
		end
		return "full"
	end
	if onScreen and distance <= config.fullStuds then
		return "full"
	end
	return "frozen"
end

--[=[
	When a puppet is next evaluated: one period after `now` (seconds). `phase` in [0, 1) staggers a new puppet's
	first check so checks spread across frames.
]=]
function ReplicationAnimationRules.nextCheckAt(now: number, rateHz: number, phase: number?): number
	local period = 1 / rateHz
	return now + period * (if phase ~= nil then phase else 1)
end

return ReplicationAnimationRules
