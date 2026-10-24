--!strict
--[=[
	OfficeAnomalyUtils: the pure answers behind the exterior anomalies (OfficeAnomalySystem plays them): which ids the
	office model publishes, the silhouette's seen-then-gone state machine, the lobby doors' cycle (when, how far
	open, where a leaf sits), the welcome screen's line at a time, and the booth TV's flicker.

	@class OfficeAnomalyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeSeedUtils = require(ReplicatedStorage.Shared.Features.Office.Utils.OfficeSeedUtils)

export type SilhouettePhase = "hidden" | "visible" | "seen" | "gone"
export type SilhouetteState = {
	phase: SilhouettePhase,
	-- When the current unbroken stretch in view began (visible only).
	inViewSince: number?,
}
export type DoorPhase = "opening" | "open" | "closing" | "closed"
-- The lobby doors' clock: how many cycles have run, when the next is due (nil: none scheduled, waiting for a player
-- to come near) and when the running one began.
export type DoorTimer = {
	cycle: number,
	nextAt: number?,
	startedAt: number?,
}
-- What the system does to one slot this frame.
export type SlotAction = "apply" | "reset" | "reapply" | "refresh" | "keep" | "none"

local DOOR_OPEN = 0.6
local DOOR_HOLD = 2
local DOOR_CLOSE = 0.6
local DOOR_EVERY_MIN = 20
local DOOR_EVERY_MAX = 40
local WELCOME_CYCLE = 6
local WELCOME_WRONG = 1.2
local TV_MIN = 0.6
local TV_MAX = 1.2
local TV_RATE = 8

local KNOWN: { [string]: boolean } = {}
for _, id in OfficeAnomalyConstants.IDS do
	KNOWN[id] = true
end

local OfficeAnomalyUtils = {
	-- Seconds in view before the silhouette counts as seen.
	SILHOUETTE_SEEN_AFTER = 0.5,
	-- Farther than this it is never "in view".
	SILHOUETTE_RANGE = 400,
	-- A player this close sets the lobby doors cycling.
	DOOR_NEAR = 60,
	-- One whole door cycle (open, hold, close).
	DOOR_CYCLE = DOOR_OPEN + DOOR_HOLD + DOOR_CLOSE,
}

--[=[
	The published ids (the office model's comma-joined attribute) as a set; unknown ids and non-strings give nothing.
]=]
function OfficeAnomalyUtils.parse(value: unknown): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(value) ~= "string" then
		return set
	end
	for _, id in string.split(value, ",") do
		if KNOWN[id] then
			set[id] = true
		end
	end
	return set
end

--[=[
	One step of the silhouette: hidden stays hidden (apply makes it visible); visible becomes seen after
	`visibleFor` unbroken seconds in view (`inView`: on screen, in range and not occluded); seen becomes gone only the
	first time it is off screen (`onScreen` false) — occluded or far but still on screen it stays; gone is final.
]=]
function OfficeAnomalyUtils.silhouette(
	state: SilhouetteState,
	onScreen: boolean,
	inView: boolean,
	visibleFor: number,
	now: number
): SilhouetteState
	local phase = state.phase
	if phase == "visible" then
		if not (onScreen and inView) then
			return { phase = "visible" }
		end
		local since = state.inViewSince or now
		if now - since >= visibleFor - 1e-9 then
			return { phase = "seen" }
		end
		return { phase = "visible", inViewSince = since }
	elseif phase == "seen" then
		return if onScreen then state else { phase = "gone" }
	end
	return state
end

--[=[
	Whether the figure is drawn in this state.
]=]
function OfficeAnomalyUtils.silhouetteShown(state: SilhouetteState): boolean
	return state.phase == "visible" or state.phase == "seen"
end

--[=[
	The doors `elapsed` seconds into a cycle: the phase and how far open (0 closed, 1 fully open).
]=]
function OfficeAnomalyUtils.doorAt(elapsed: number): (DoorPhase, number)
	if elapsed < 0 then
		return "closed", 0
	elseif elapsed < DOOR_OPEN then
		return "opening", elapsed / DOOR_OPEN
	elseif elapsed < DOOR_OPEN + DOOR_HOLD then
		return "open", 1
	elseif elapsed < DOOR_OPEN + DOOR_HOLD + DOOR_CLOSE then
		return "closing", 1 - (elapsed - DOOR_OPEN - DOOR_HOLD) / DOOR_CLOSE
	end
	return "closed", 0
end

--[=[
	One step of the lobby doors' clock. A cycle never starts the moment a player comes near: with nothing scheduled,
	a player near schedules one doorEvery (20-40 s) later; when it comes due it runs only if a player is near then
	(and the next is scheduled from its start), otherwise nothing is scheduled until a player is near again. A running
	cycle (DOOR_CYCLE s) always finishes.
]=]
function OfficeAnomalyUtils.doorStep(timer: DoorTimer, seed: number, near: boolean, now: number): DoorTimer
	local startedAt = timer.startedAt
	if startedAt ~= nil and now - startedAt < OfficeAnomalyUtils.DOOR_CYCLE then
		return timer
	end
	local nextAt = timer.nextAt
	if nextAt == nil then
		if near then
			return { cycle = timer.cycle, nextAt = now + OfficeAnomalyUtils.doorEvery(seed, timer.cycle + 1) }
		end
		return { cycle = timer.cycle }
	end
	if now < nextAt then
		return { cycle = timer.cycle, nextAt = nextAt }
	end
	if near then
		local cycle = timer.cycle + 1
		return { cycle = cycle, nextAt = now + OfficeAnomalyUtils.doorEvery(seed, cycle + 1), startedAt = now }
	end
	return { cycle = timer.cycle }
end

--[=[
	How open the doors are under `timer` at `now` (0 closed .. 1 open).
]=]
function OfficeAnomalyUtils.doorOpen(timer: DoorTimer, now: number): number
	local startedAt = timer.startedAt
	if startedAt == nil then
		return 0
	end
	local _, open = OfficeAnomalyUtils.doorAt(now - startedAt)
	return open
end

--[=[
	What to do with one slot this frame. `id` is the slot's anomaly id (nil: not a slot), `appliedSeed` the run it is
	applied for (nil: not applied), `restreamed` whether a part streamed into it since it was applied.
	apply (listed, not applied), reset (applied, no longer listed), reapply (applied for another run), refresh
	(applied, a part streamed in), keep (applied, nothing changed), none (not listed, not applied).
]=]
function OfficeAnomalyUtils.slotAction(
	id: string?,
	published: { [string]: boolean },
	seed: number,
	appliedSeed: number?,
	restreamed: boolean
): SlotAction
	local wanted = id ~= nil and published[id] == true
	if appliedSeed == nil then
		return if wanted then "apply" else "none"
	elseif not wanted then
		return "reset"
	elseif appliedSeed ~= seed then
		return "reapply"
	elseif restreamed then
		return "refresh"
	end
	return "keep"
end

--[=[
	Seconds from the start of cycle `cycle` to the next one (20-40, hash-timed per run and cycle).
]=]
function OfficeAnomalyUtils.doorEvery(seed: number, cycle: number): number
	return DOOR_EVERY_MIN + (DOOR_EVERY_MAX - DOOR_EVERY_MIN) * OfficeSeedUtils.hash01(seed, `autoDoors:{cycle}`)
end

--[=[
	A leaf's CFrame `open` (0..1) of the way to open: it slides `slide` studs along its right vector, `side` (±1) away
	from the door centre.
]=]
function OfficeAnomalyUtils.leafAt(closed: CFrame, side: number, slide: number, open: number): CFrame
	if open <= 0 then
		return closed
	end
	return closed + closed.RightVector * side * slide * open
end

--[=[
	The run's wrong welcome line (every machine picks the same one for the seed).
]=]
function OfficeAnomalyUtils.wrongLine(seed: number): string
	return OfficeSeedUtils.pick(seed, "welcome", OfficeAnomalyConstants.WRONG_WORDS)
end

--[=[
	The welcome screen `t` seconds after the anomaly began: the welcome text, and the wrong line in the last 1.2 s of
	every 6 s.
]=]
function OfficeAnomalyUtils.welcomeText(t: number, wrong: string): string
	local into = t % WELCOME_CYCLE
	if into >= WELCOME_CYCLE - WELCOME_WRONG - 1e-9 then
		return wrong
	end
	return OfficeAnomalyConstants.WELCOME_TEXT
end

--[=[
	The booth TV's SurfaceLight brightness at time `t` (0.6-1.2, smooth noise at about 8 Hz).
]=]
function OfficeAnomalyUtils.tvBrightness(t: number): number
	local noise = math.clamp(math.noise(t * TV_RATE, 0.37) + 0.5, 0, 1)
	return TV_MIN + (TV_MAX - TV_MIN) * noise
end

return OfficeAnomalyUtils
