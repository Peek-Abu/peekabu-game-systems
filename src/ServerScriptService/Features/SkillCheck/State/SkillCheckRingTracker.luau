--!strict
--[=[
	SkillCheckRingTracker: each player's closing rings (the k1 skill check). `step` is told, every beat, whether a player
	is vacuuming a pile, how far along it is and the Night Shift week (nil in Quick shift); once they have been on a pile `firstDelay` seconds it starts a ring:
	a fresh id, an opening `minShift` or more round from their last one (SkillCheckAngleFormulas.nextGap, from the
	injected `random`), as wide as the pile's progress allows (gapWidth: narrower toward the end; both ends narrowed by the week,
	weekScale, when the config has a weekly step) and arriving `travel` seconds later. One ring at a time per player; a ring in flight is judged even if they leave the pile (letting go
	never dodges it). `report` judges a ring by the icon's reported angle (SkillCheckAngleFormulas.inGap with
	`tolerance`), only for that player's ring id and only in its window (SkillCheckReportRules.window: an early report is
	ignored, a late one is a miss); `expire` misses every ring whose window closed with no report. After any verdict the
	next ring waits `between` seconds, even if the player lets go and starts again. All times are on one clock (the
	server's GetServerTimeNow). Plain bookkeeping: it remembers, but touches nothing it does not own.

	@class SkillCheckRingTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillCheckTypes = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckTypes)
local SkillCheckAngleFormulas = require(ReplicatedStorage.Shared.Features.SkillCheck.Utils.SkillCheckAngleFormulas)
local SkillCheckReportRules = require(ServerScriptService.Features.SkillCheck.Rules.SkillCheckReportRules)

export type Config = {
	travel: number,
	firstDelay: number,
	between: number,
	widthStart: number,
	widthEnd: number,
	-- Night Shift's weekly narrowing (SkillCheckAngleFormulas.weekScale); nil: the week never narrows the opening.
	widthWeekStep: number?,
	widthWeekFloor: number?,
	minShift: number,
	tolerance: number,
	early: number,
	late: number,
}

export type SkillCheckRingTracker = {
	step: (
		self: SkillCheckRingTracker,
		userId: number,
		onPile: boolean,
		progress: number,
		now: number,
		week: number?
	) -> SkillCheckTypes.Ring?,
	report: (
		self: SkillCheckRingTracker,
		userId: number,
		id: number,
		angle: number,
		now: number
	) -> (SkillCheckTypes.Verdict?, string?),
	expire: (self: SkillCheckRingTracker, now: number) -> { SkillCheckTypes.Verdict },
	pending: (self: SkillCheckRingTracker, userId: number) -> SkillCheckTypes.Ring?,
	forget: (self: SkillCheckRingTracker, userId: number) -> (),
	clear: (self: SkillCheckRingTracker) -> (),
}

-- One player's rings: whether they are counted as on a pile, when their next ring may start, the earliest a ring may
-- start after the last verdict, their last opening and the ring in flight.
type Player = {
	armed: boolean,
	nextAt: number,
	coolUntil: number,
	lastGap: number?,
	pending: SkillCheckTypes.Ring?,
}

local SkillCheckRingTracker = {}

function SkillCheckRingTracker.new(config: Config, random: () -> number): SkillCheckRingTracker
	local players: { [number]: Player } = {}
	local lastId = 0

	local function playerOf(userId: number): Player
		local state = players[userId]
		if state == nil then
			state = { armed = false, nextAt = math.huge, coolUntil = -math.huge, lastGap = nil, pending = nil }
			players[userId] = state
		end
		return state
	end

	-- Ends `state`'s ring with a verdict at `now`; the next ring waits `between`.
	local function resolve(
		userId: number,
		state: Player,
		ring: SkillCheckTypes.Ring,
		hit: boolean,
		now: number
	): SkillCheckTypes.Verdict
		state.pending = nil
		state.coolUntil = now + config.between
		state.nextAt = state.coolUntil
		return { userId = userId, ring = ring, hit = hit }
	end

	local tracker: SkillCheckRingTracker = {
		step = function(_self, userId, onPile, progress, now, week)
			local state = playerOf(userId)
			if not onPile then
				state.armed = false
				return nil
			end
			if not state.armed then
				state.armed = true
				state.nextAt = math.max(now + config.firstDelay, state.coolUntil)
			end
			if state.pending ~= nil or now < state.nextAt then
				return nil
			end
			lastId += 1
			local gap = SkillCheckAngleFormulas.nextGap(state.lastGap, random(), config.minShift)
			local stepPerWeek, floor = config.widthWeekStep, config.widthWeekFloor
			local scale = if stepPerWeek ~= nil and floor ~= nil
				then SkillCheckAngleFormulas.weekScale(week, stepPerWeek, floor)
				else 1
			local ring: SkillCheckTypes.Ring = {
				id = lastId,
				gap = gap,
				width = SkillCheckAngleFormulas.gapWidth(progress, config.widthStart * scale, config.widthEnd * scale),
				arriveAt = now + config.travel,
				travel = config.travel,
			}
			state.lastGap = gap
			state.pending = ring
			return ring
		end,

		report = function(_self, userId, id, angle, now)
			local state = players[userId]
			local ring = if state ~= nil then state.pending else nil
			if state == nil or ring == nil then
				return nil, "no ring"
			end
			if ring.id ~= id then
				return nil, "wrong ring"
			end
			local window = SkillCheckReportRules.window(now, ring.arriveAt, config.early, config.late)
			if window == "early" then
				return nil, "early"
			end
			local hit = window == "open"
				and SkillCheckAngleFormulas.inGap(angle, ring.gap, ring.width, config.tolerance)
			return resolve(userId, state, ring, hit, now), nil
		end,

		expire = function(_self, now)
			local missed: { SkillCheckTypes.Verdict } = {}
			for userId, state in players do
				local ring = state.pending
				if
					ring ~= nil
					and SkillCheckReportRules.window(now, ring.arriveAt, config.early, config.late) == "late"
				then
					table.insert(missed, resolve(userId, state, ring, false, now))
				end
			end
			table.sort(missed, function(a: SkillCheckTypes.Verdict, b: SkillCheckTypes.Verdict): boolean
				return a.userId < b.userId
			end)
			return missed
		end,

		pending = function(_self, userId)
			local state = players[userId]
			return if state ~= nil then state.pending else nil
		end,

		forget = function(_self, userId)
			players[userId] = nil
		end,

		clear = function(_self)
			table.clear(players)
		end,
	}
	return tracker
end

return SkillCheckRingTracker
