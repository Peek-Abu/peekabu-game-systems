--!strict
--[=[
	RankServiceServer: the company rank ("Clearance Level", Cleanup Crew; docs/cleanup-crew-rank.md). Cosmetic only:
	a level never changes what a player can do.

	- Storage: the account-wide `rank` slice ({ season, xp, lastAwardedRunId }) when RankConstants.RANK_PERSIST is
	  true; a session-only copy in server memory (RankTracker) when it is false, never written to the profile.
	- Season: on load a rank from another season (RankConstants.RANK_SEASON) resets to level 1 / 0 XP.
	- Award: RankShiftSystem pays each crew member once per shift run when the shift reaches its review (RankFormulas);
	  RankRules.applyAward refuses a run already paid (`lastAwardedRunId`).
	- Display: every client reads a player's XP from their public entry (RankConstants.PUBLIC_XP_FIELD), which works
	  the same in both storage modes and for other players' name tags. The `rank` slice is therefore deliberately NOT
	  in StateSyncSliceRegistry (the same server-side-only precedent as `receipts`).

	Existing profiles need no migration: ProfileStore's Reconcile backfills `account.rank` from the template, whose
	default this module registers (season = RANK_SEASON, 0 XP).

	@class RankServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RankShared = ReplicatedStorage.Shared.Features.Rank
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local RankConstants = require(RankShared.Data.RankConstants)
local RankTypes = require(RankShared.Data.RankTypes)
local RankRules = require(RankShared.Rules.RankRules)
local RankFormulas = require(RankShared.Utils.RankFormulas)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local RankTracker = require(ServerScriptService.Features.Rank.State.RankTracker)
local RankShiftSystem = require(ServerScriptService.Features.Rank.Systems.RankShiftSystem)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type RankState = RankTypes.RankState

local rankSlice = PlayerDataSliceSystem.registerAccount(
	"rank",
	RankRules.fresh(RankConstants.RANK_SEASON),
	function(account)
		return account.rank
	end,
	RankRules.validate
)

local log = Logger.new("RankServiceServer")
local sessionRanks = RankTracker.new()
local persist = RankConstants.RANK_PERSIST
local season = RankConstants.RANK_SEASON
local stoppers: { () -> () } = {}

-- `before`: the XP before the latest award (the XP itself after a load or a reset).
local function publish(userId: number, xp: number, before: number)
	StateSyncPublicPlayerStore.set(userId, {
		[RankConstants.PUBLIC_XP_FIELD] = xp,
		[RankConstants.PUBLIC_PREV_XP_FIELD] = before,
	})
end

local function read(userId: number): RankState?
	if persist then
		return rankSlice.get(userId)
	end
	return sessionRanks:get(userId)
end

-- Runs `fn` on the player's rank in whichever store is live; true when it changed.
local function write(userId: number, fn: (state: RankState) -> boolean): boolean
	if persist then
		if rankSlice.get(userId) == nil then
			return false
		end
		local changed = rankSlice.mutate(userId, fn)
		return changed
	end
	return sessionRanks:update(userId, fn)
end

export type RankServiceServer = {
	dependencies: { string },
	start: (self: RankServiceServer) -> (),
	stop: (self: RankServiceServer) -> (),
	load: (self: RankServiceServer, userId: number) -> boolean,
	get: (self: RankServiceServer, userId: number) -> RankState?,
	progressOf: (self: RankServiceServer, userId: number) -> RankTypes.Progress?,
	awardShift: (
		self: RankServiceServer,
		userId: number,
		runId: string,
		facts: RankTypes.ShiftFacts
	) -> (boolean, RankTypes.Award?),
	reset: (self: RankServiceServer, userId: number) -> boolean,
	forget: (self: RankServiceServer, userId: number) -> (),
	-- Test seams: override RANK_SEASON / RANK_PERSIST for this server; nil restores the constant.
	_setSeason: (self: RankServiceServer, nextSeason: string?) -> (),
	_setPersist: (self: RankServiceServer, nextPersist: boolean?) -> (),
	getState: (self: RankServiceServer) -> { [string]: any },
}

local RankServiceServer: RankServiceServer
RankServiceServer = {
	dependencies = { "PlayerDataServiceServer", "StateSyncServiceServer", "ShiftServiceServer" },

	--[=[
		Loads each player's rank as their profile loads (and for anyone already loaded), forgets session ranks on
		leave, and starts paying shift reviews.
	]=]
	start = function(self)
		local loaded = PlayerDataService.profileLoaded:Connect(function(userId: number)
			self:load(userId)
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player: Player)
			self:forget(player.UserId)
		end)
		for _, player in Players:GetPlayers() do
			if rankSlice.get(player.UserId) ~= nil then
				self:load(player.UserId)
			end
		end
		table.insert(stoppers, function()
			loaded:Disconnect()
			leaving:Disconnect()
		end)
		table.insert(
			stoppers,
			RankShiftSystem.start(
				RankShiftSystem.shiftSource(ShiftServiceServer.changed),
				function(userId: number, runId: string, facts: RankTypes.ShiftFacts)
					local ok, award = self:awardShift(userId, runId, facts)
					log:info(`run {runId}: {userId} +{if award ~= nil then award.total else 0} XP (paid: {ok})`)
				end
			)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		sessionRanks:clear()
	end,

	--[=[
		Readies the player's rank: resets it when it is from another season (or starts a session rank) and publishes
		their XP. False when their profile is not loaded (persisted mode).
	]=]
	load = function(_self, userId)
		if persist then
			if rankSlice.get(userId) == nil then
				return false
			end
			rankSlice.mutate(userId, function(state)
				return RankRules.reconcileSeason(state, season)
			end)
		else
			local current = sessionRanks:get(userId)
			if current == nil or current.season ~= season then
				sessionRanks:set(userId, RankRules.fresh(season))
			end
		end
		local state = read(userId)
		if state == nil then
			return false
		end
		publish(userId, state.xp, state.xp)
		return true
	end,

	get = function(_self, userId)
		return read(userId)
	end,

	progressOf = function(_self, userId)
		local state = read(userId)
		return if state ~= nil then RankFormulas.progress(state.xp) else nil
	end,

	--[=[
		Pays one shift run's XP for `facts` (RankFormulas.award). True when the XP was added; false when the run was
		already paid, the award is zero, or the rank is not loaded. Also returns the award it computed.
	]=]
	awardShift = function(_self, userId, runId, facts)
		local award = RankFormulas.award(facts)
		if award.total <= 0 then
			return false, award
		end
		local before = 0
		local changed = write(userId, function(state)
			before = state.xp
			return RankRules.applyAward(state, runId, award.total)
		end)
		if changed then
			local state = read(userId)
			if state ~= nil then
				publish(userId, state.xp, before)
			end
		end
		return changed, award
	end,

	--[=[
		Resets one player's rank to level 1 / 0 XP in the current season (admin / testing).
	]=]
	reset = function(_self, userId)
		local changed = write(userId, function(state)
			if state.season == season and state.xp == 0 and state.lastAwardedRunId == "" then
				return false
			end
			state.season = season
			state.xp = 0
			state.lastAwardedRunId = ""
			return true
		end)
		if changed then
			publish(userId, 0, 0)
		end
		return changed
	end,

	-- Drops a session rank (the player left). The saved rank is untouched.
	forget = function(_self, userId)
		sessionRanks:forget(userId)
	end,

	_setSeason = function(_self, nextSeason)
		season = nextSeason or RankConstants.RANK_SEASON
	end,

	_setPersist = function(_self, nextPersist)
		if nextPersist == nil then
			persist = RankConstants.RANK_PERSIST
		else
			persist = nextPersist
		end
	end,

	getState = function(_self)
		return { persist = persist, season = season, sessionRanks = sessionRanks:count() }
	end,
}

return RankServiceServer
