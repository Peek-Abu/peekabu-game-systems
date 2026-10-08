--!strict
--[=[
	ReplicationFallRules: whether an accepted body position counts as "fell off the map", the check behind the server's
	respawn-on-fall answer. The accepted position comes off the wire, which clamps Y at the codec floor, so a
	place whose FallenPartsDestroyHeight sits below the floor would otherwise refuse every fall.

	`decide` adds the stranded answer: an owner whose rig is gone keeps asking, and if the server last saw the
	body above the plane (a client teleport below it, or a hitch that skipped the falling samples) the
	requests are refused until they have spanned `STRANDED_MS`, then the body respawns at a spawn point.
	Asking while still alive only gets a fresh spawn — no reward; the anti-cheat phase may tighten it.

	@class ReplicationFallRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)

local ReplicationFallRules = {}

-- Studs above the plane within which a position still counts as having fallen (the client's destroy is
-- local, and the last accepted sample trails it).
ReplicationFallRules.MARGIN = 100

function ReplicationFallRules.hasFallen(positionY: number, destroyHeight: number): boolean
	return positionY <= math.max(destroyHeight, ReplicationRecordCodec.Y_FLOOR) + ReplicationFallRules.MARGIN
end

-- How long refused respawn requests must keep coming before a bodiless owner is respawned anyway.
ReplicationFallRules.STRANDED_MS = 3000

-- A bodiless owner retries every second (2 per 5 s pass the rate limit); a longer silence ends the run.
ReplicationFallRules.RUN_GAP_MS = 6000

-- When the current run of refused requests began, given the previous run start and last refusal.
function ReplicationFallRules.runStart(since: number?, lastRefusedMs: number?, nowMs: number): number
	if since == nil or lastRefusedMs == nil or nowMs - lastRefusedMs > ReplicationFallRules.RUN_GAP_MS then
		return nowMs
	end
	return since
end

export type Verdict = "fell" | "stranded" | "refuse"

-- `refusedSinceMs` is when the current run of refused requests began (nil: none yet).
function ReplicationFallRules.decide(
	positionY: number,
	destroyHeight: number,
	refusedSinceMs: number?,
	nowMs: number
): Verdict
	if ReplicationFallRules.hasFallen(positionY, destroyHeight) then
		return "fell"
	end
	if refusedSinceMs ~= nil and nowMs - refusedSinceMs >= ReplicationFallRules.STRANDED_MS then
		return "stranded"
	end
	return "refuse"
end

-- Each owner's current run of refused requests (when it began, when the last one came), by userId.
export type Runs = { since: { [number]: number }, last: { [number]: number } }

function ReplicationFallRules.newRuns(): Runs
	return { since = {}, last = {} }
end

-- The answer to one respawn request; a refusal is recorded as part of the owner's current run.
function ReplicationFallRules.answer(
	runs: Runs,
	userId: number,
	positionY: number,
	destroyHeight: number,
	nowMs: number
): Verdict
	local since = ReplicationFallRules.runStart(runs.since[userId], runs.last[userId], nowMs)
	-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
	local verdict: Verdict = ReplicationFallRules.decide(positionY, destroyHeight, since, nowMs)
	if verdict == "refuse" then
		runs.since[userId] = since
		runs.last[userId] = nowMs
	end
	return verdict
end

-- Forget an owner's run (an accepted sample, a spawn, a leave).
function ReplicationFallRules.clear(runs: Runs, userId: number)
	runs.since[userId] = nil
	runs.last[userId] = nil
end

return ReplicationFallRules
