--!strict
--[=[
	LeaderboardCrewUtils: the weekly crew board's plain pieces. A crew is keyed by a short hash of its sorted user ids
	(`crewKey`, so the same crew in any order is one row and the key fits an OrderedDataStore); a week by its Monday
	(TimecardCalendarFormulas' week, UTC). A crew keeps its best shift of the week (`best`). The roster (ids and display
	names) and the published board cross a DataStore or the wire as plain data, so both decoders check every field.
	Pure.

	@class LeaderboardCrewUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardConstants)
local LeaderboardTypes = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardTypes)
local TimecardCalendarFormulas = require(ReplicatedStorage.Shared.Features.Timecard.Utils.TimecardCalendarFormulas)

type WorldValue = WorldTypes.WorldValue
type WorldTable = WorldTypes.WorldTable
type Roster = LeaderboardTypes.Roster
type Entry = LeaderboardTypes.Entry
type Board = LeaderboardTypes.Board

local LeaderboardCrewUtils = {}

local function sortedIds(ids: { number }): { number }
	local sorted = table.clone(ids)
	table.sort(sorted)
	return sorted
end

-- Two independent 32-bit FNV-1a style hashes of the text, as 8 hex digits each.
local function hash(text: string, seed: number): string
	local h = seed
	for index = 1, #text do
		h = bit32.bxor(h, string.byte(text, index))
		-- h * 16777619 mod 2^32, exactly: 16777619 = 2^24 + 403 (a plain product would pass 2^53).
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return string.format("%08x", h)
end

--[=[
	The crew's key: 16 hex characters from its sorted user ids.
]=]
function LeaderboardCrewUtils.crewKey(ids: { number }): string
	local parts: { string } = {}
	for _, id in sortedIds(ids) do
		table.insert(parts, string.format("%d", id))
	end
	local text = table.concat(parts, ",")
	return string.sub(hash(text, 2166136261) .. hash(text, 3735928559), 1, LeaderboardConstants.KEY_LENGTH)
end

-- The week `now` falls in, by its Monday ("2026-11-02").
function LeaderboardCrewUtils.weekOf(now: number): string
	return TimecardCalendarFormulas.weekKey(now)
end

-- The OrderedDataStore of `now`'s week.
function LeaderboardCrewUtils.storeName(now: number): string
	return LeaderboardConstants.STORE_PREFIX .. LeaderboardCrewUtils.weekOf(now)
end

-- When `now`'s week ends (the next Monday 00:00 UTC).
function LeaderboardCrewUtils.weekEnds(now: number): number
	return TimecardCalendarFormulas.weekEnd(now)
end

--[=[
	A crew's roster from its members (user id and name), sorted by id, names cut to MAX_NAME, at most MAX_CREW.
]=]
function LeaderboardCrewUtils.roster(members: { { userId: number, name: string } }): Roster
	local list = table.clone(members)
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	local ids: { number } = {}
	local names: { string } = {}
	for index, member in list do
		if index > LeaderboardConstants.MAX_CREW then
			break
		end
		table.insert(ids, member.userId)
		table.insert(names, string.sub(member.name, 1, LeaderboardConstants.MAX_NAME))
	end
	return { ids = ids, names = names }
end

local function stringList(value: WorldValue?): { string }?
	local result: { string } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for index = 1, LeaderboardConstants.MAX_CREW + 1 do
		local item = value[index]
		if item == nil then
			break
		end
		if index > LeaderboardConstants.MAX_CREW or type(item) ~= "string" then
			return nil
		end
		table.insert(result, string.sub(item, 1, LeaderboardConstants.MAX_NAME))
	end
	return result
end

--[=[
	A roster read back from the DataStore, or nil when it is not one.
]=]
function LeaderboardCrewUtils.decodeRoster(value: WorldValue?): Roster?
	if type(value) ~= "table" then
		return nil
	end
	local rawIds = value.ids
	if type(rawIds) ~= "table" then
		return nil
	end
	local ids: { number } = {}
	for index = 1, LeaderboardConstants.MAX_CREW + 1 do
		local item = rawIds[index]
		if item == nil then
			break
		end
		if index > LeaderboardConstants.MAX_CREW or type(item) ~= "number" then
			return nil
		end
		table.insert(ids, item)
	end
	local names = stringList(value.names)
	if names == nil or #names ~= #ids or #ids == 0 then
		return nil
	end
	return { ids = ids, names = names }
end

--[=[
	A crew's score after a shift scoring `score` (whole Gloom): the better of it and the stored one.
]=]
function LeaderboardCrewUtils.best(stored: unknown, score: number): number
	local new = math.max(0, math.floor(score))
	return if type(stored) == "number" then math.max(stored, new) else new
end

--[=[
	The board as plain data for the `crewBoard` world entry.
]=]
function LeaderboardCrewUtils.encodeBoard(board: Board): WorldTable
	local entries: WorldTable = {}
	for index, entry in board.entries do
		local names: WorldTable = table.clone(entry.names)
		local row: WorldTable = { names = names, score = entry.score }
		entries[index] = row
	end
	return { week = board.week, endsAt = board.endsAt, entries = entries }
end

--[=[
	The `crewBoard` world entry back as a board, or nil when it is malformed (the client's trust boundary).
]=]
function LeaderboardCrewUtils.decodeBoard(value: WorldValue?): Board?
	if type(value) ~= "table" then
		return nil
	end
	local week = value.week
	local endsAt = value.endsAt
	if type(week) ~= "string" or type(endsAt) ~= "number" then
		return nil
	end
	local entries: { Entry } = {}
	local raw = value.entries
	if raw ~= nil then
		if type(raw) ~= "table" then
			return nil
		end
		for index = 1, LeaderboardConstants.TOP + 1 do
			local item = raw[index]
			if item == nil then
				break
			end
			if index > LeaderboardConstants.TOP or type(item) ~= "table" then
				return nil
			end
			local names = stringList(item.names)
			local score = item.score
			if names == nil or type(score) ~= "number" then
				return nil
			end
			table.insert(entries, { names = names, score = score })
		end
	end
	return { week = week, endsAt = endsAt, entries = entries }
end

return LeaderboardCrewUtils
