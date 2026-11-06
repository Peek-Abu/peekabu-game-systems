--!strict
--[=[
	LeaderboardServiceServer: the weekly crew leaderboard (owner 11-05: weekly crew boards only). Where the shift runs,
	each shift that reaches its review records its crew (the members who worked it, RankFormulas.workedIds) with the
	Gloom it removed: the week's OrderedDataStore keeps each crew's best shift (LeaderboardCrewUtils.best, by
	UpdateAsync) and the roster store keeps its names. Where the depot runs, every REFRESH_SECONDS the hub reads the
	week's top TOP crews, looks up their rosters (cached) and publishes the board as the `crewBoard` world entry, which
	the depot's crew board draws. A new week is a new store, so the board starts over on Monday 00:00 UTC by itself.

	Every DataStore call is guarded: in Studio (no API access) or during an outage nothing is recorded and the board
	stays empty or as last read; the game never waits on it.

	Spec-exempt shell (DataStoreService, the Shift signal, StateSync); the keys, the week, the best-of rule and the wire
	format are the specced LeaderboardCrewUtils.

	@class LeaderboardServiceServer
]=]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardConstants)
local LeaderboardTypes = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardTypes)
local LeaderboardCrewUtils = require(ReplicatedStorage.Shared.Features.Leaderboard.Utils.LeaderboardCrewUtils)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

local log = Logger.new("LeaderboardServiceServer")
local counters = { recorded = 0, refreshed = 0, failed = 0 }

-- The first DataStore failure warns; the rest (Studio has no API access: every minute) only go to debug.
local function failed(message: string)
	counters.failed += 1
	if counters.failed == 1 then
		log:warn(message)
	else
		log:debug(message)
	end
end

local stoppers: { () -> () } = {}
-- Rosters already read, by "<week>:<crew key>".
local rosters: { [string]: LeaderboardTypes.Roster } = {}
-- The shift numbers already recorded on this server (a review is reached once per shift).
local recorded: { [number]: true } = {}

-- Records a finished shift's crew and Gloom removed. Yields; every DataStore call is guarded.
local function record(results: ShiftTypes.ShiftResults)
	local worked = RankFormulas.workedIds(results)
	if #worked == 0 or results.cleared <= 0 then
		return
	end
	local members: { { userId: number, name: string } } = {}
	for _, line in results.crew do
		if table.find(worked, line.userId) ~= nil then
			table.insert(members, { userId = line.userId, name = line.name })
		end
	end
	local roster = LeaderboardCrewUtils.roster(members)
	local key = LeaderboardCrewUtils.crewKey(roster.ids)
	local now = os.time()
	local ok, err = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(LeaderboardCrewUtils.storeName(now))
		store:UpdateAsync(key, function(old: unknown): number
			return LeaderboardCrewUtils.best(old, results.cleared)
		end)
		DataStoreService:GetDataStore(LeaderboardConstants.ROSTER_STORE)
			:SetAsync(`{LeaderboardCrewUtils.weekOf(now)}:{key}`, roster)
	end)
	if ok then
		counters.recorded += 1
	else
		failed(`recording the crew's shift failed: {tostring(err)}`)
	end
end

local function rosterOf(week: string, key: string): LeaderboardTypes.Roster?
	local id = `{week}:{key}`
	local cached = rosters[id]
	if cached ~= nil then
		return cached
	end
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore(LeaderboardConstants.ROSTER_STORE):GetAsync(id)
	end)
	local roster = if ok then LeaderboardCrewUtils.decodeRoster(value) else nil
	if roster ~= nil then
		rosters[id] = roster
	end
	return roster
end

-- Reads the week's top crews and publishes the board. Yields.
local function refresh()
	local now = os.time()
	local week = LeaderboardCrewUtils.weekOf(now)
	local entries: { LeaderboardTypes.Entry } = {}
	local ok, err = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(LeaderboardCrewUtils.storeName(now))
		local page = store:GetSortedAsync(false, LeaderboardConstants.TOP):GetCurrentPage()
		for _, item in page do
			local key = item.key
			local score = item.value
			if type(key) == "string" and type(score) == "number" then
				local roster = rosterOf(week, key)
				if roster ~= nil then
					table.insert(entries, { names = roster.names, score = score })
				end
			end
		end
	end)
	if not ok then
		failed(`reading the crew board failed: {tostring(err)}`)
		if StateSyncWorldStore.get(LeaderboardConstants.WORLD_ENTRY) ~= nil then
			return
		end
	end
	counters.refreshed += 1
	StateSyncWorldStore.set(
		LeaderboardConstants.WORLD_ENTRY,
		LeaderboardCrewUtils.encodeBoard({ week = week, endsAt = LeaderboardCrewUtils.weekEnds(now), entries = entries })
	)
end

export type LeaderboardServiceServer = {
	dependencies: { string },
	start: (self: LeaderboardServiceServer) -> (),
	stop: (self: LeaderboardServiceServer) -> (),
	getState: (self: LeaderboardServiceServer) -> { [string]: any },
}

local LeaderboardServiceServer: LeaderboardServiceServer = {
	dependencies = { "QueueServiceServer", "ShiftServiceServer", "StateSyncServiceServer" },

	--[=[
		Records shifts where the shift runs and keeps the board fresh where the depot runs (Studio: both).
	]=]
	start = function(_self)
		if QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then
			local following = ShiftServiceServer.changed:Connect(function(state: ShiftTypes.ShiftState)
				if state.phase ~= "results" or recorded[state.shift] then
					return
				end
				local results = ShiftServiceServer:getResults()
				if results ~= nil then
					recorded[state.shift] = true
					task.spawn(record, results)
				end
			end)
			table.insert(stoppers, function()
				following:Disconnect()
			end)
		end
		if QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
			local running = true
			task.spawn(function()
				while running do
					refresh()
					task.wait(LeaderboardConstants.REFRESH_SECONDS)
				end
			end)
			table.insert(stoppers, function()
				running = false
			end)
		end
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		StateSyncWorldStore.clear(LeaderboardConstants.WORLD_ENTRY)
	end,

	getState = function(_self)
		return { counters = table.clone(counters) }
	end,
}

return LeaderboardServiceServer
