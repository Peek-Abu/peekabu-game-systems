--!strict
--[=[
	RoundRunTracker: the state that lives for one run and is never saved — who is in it, who has been
	eliminated, the team's shared counters and their targets, per-player scores, and run containers
	(design: docs/superpowers/specs/2026-10-09-round-design.md). `reset` starts the next run from nothing.

	`snapshot` builds the fresh, plain-data RoundSnapshot every client syncs.

	@class RoundRunTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)

type InventoryEntry = PlayerDataTypes.InventoryEntry

export type RoundRunTracker = {
	reset: (self: RoundRunTracker, participants: { number }, round: number?) -> (),
	addParticipant: (self: RoundRunTracker, userId: number) -> boolean,
	removeParticipant: (self: RoundRunTracker, userId: number) -> (),
	isParticipant: (self: RoundRunTracker, userId: number) -> boolean,
	eliminate: (self: RoundRunTracker, userId: number) -> boolean,
	revive: (self: RoundRunTracker, userId: number) -> boolean,
	isEliminated: (self: RoundRunTracker, userId: number) -> boolean,
	counts: (self: RoundRunTracker, present: number) -> RoundTypes.RoundCounts,
	addTeam: (self: RoundRunTracker, counter: string, amount: number) -> number,
	spendTeam: (self: RoundRunTracker, counter: string, amount: number) -> boolean,
	teamValue: (self: RoundRunTracker, counter: string) -> number,
	setTarget: (self: RoundRunTracker, counter: string, target: number?) -> (),
	targetMet: (self: RoundRunTracker, counter: string) -> boolean,
	addScore: (self: RoundRunTracker, userId: number, counter: string, amount: number) -> number,
	scoreOf: (self: RoundRunTracker, userId: number, counter: string) -> number,
	container: (self: RoundRunTracker, name: string) -> { InventoryEntry },
	nextUid: (self: RoundRunTracker) -> string,
	snapshot: (self: RoundRunTracker, state: RoundTypes.RoundState) -> RoundTypes.RoundSnapshot,
}

local function assertFinite(amount: number)
	assert(amount == amount and amount ~= math.huge and amount ~= -math.huge, "amount must be a finite number")
end

local function sortedKeys(set: { [number]: true }): { number }
	local list: { number } = {}
	for userId in set do
		table.insert(list, userId)
	end
	table.sort(list)
	return list
end

local function copyEntry(entry: InventoryEntry): InventoryEntry
	local copy = table.clone(entry)
	-- A unique entry's attrs is the one nested table an entry can hold.
	local asUnique = copy :: PlayerDataTypes.UniqueEntry -- nil-checked attrs below; a stack has none
	local attrs = asUnique.attrs
	if attrs ~= nil then
		asUnique.attrs = table.clone(attrs)
	end
	return copy
end

local RoundRunTracker = {}

function RoundRunTracker.new(): RoundRunTracker
	local participants: { [number]: true } = {}
	local eliminated: { [number]: true } = {}
	local team: { [string]: number } = {}
	local targets: { [string]: number } = {}
	local scores: { [number]: { [string]: number } } = {}
	local containers: { [string]: { InventoryEntry } } = {}
	local round = 0
	local uidCounter = 0

	local tracker: RoundRunTracker = {
		reset = function(_self, list, roundNumber)
			table.clear(participants)
			table.clear(eliminated)
			table.clear(team)
			table.clear(targets)
			table.clear(scores)
			table.clear(containers)
			uidCounter = 0
			round = roundNumber or round
			for _, userId in list do
				participants[userId] = true
			end
		end,

		addParticipant = function(_self, userId)
			if participants[userId] then
				return false
			end
			participants[userId] = true
			return true
		end,

		removeParticipant = function(_self, userId)
			participants[userId] = nil
			eliminated[userId] = nil
		end,

		isParticipant = function(_self, userId)
			return participants[userId] == true
		end,

		eliminate = function(_self, userId)
			if not participants[userId] or eliminated[userId] then
				return false
			end
			eliminated[userId] = true
			return true
		end,

		revive = function(_self, userId)
			if not eliminated[userId] then
				return false
			end
			eliminated[userId] = nil
			return true
		end,

		isEliminated = function(_self, userId)
			return eliminated[userId] == true
		end,

		counts = function(_self, present)
			local total = 0
			local alive = 0
			for userId in participants do
				total += 1
				if not eliminated[userId] then
					alive += 1
				end
			end
			return { present = present, participants = total, alive = alive }
		end,

		addTeam = function(_self, counter, amount)
			assertFinite(amount)
			local value = (team[counter] or 0) + amount
			team[counter] = value
			return value
		end,

		spendTeam = function(_self, counter, amount)
			assertFinite(amount)
			local current = team[counter] or 0
			if amount < 0 or current < amount then
				return false
			end
			team[counter] = current - amount
			return true
		end,

		teamValue = function(_self, counter)
			return team[counter] or 0
		end,

		setTarget = function(_self, counter, target)
			if target == nil then
				targets[counter] = nil
			else
				assertFinite(target)
				targets[counter] = target
			end
		end,

		targetMet = function(_self, counter)
			local target = targets[counter]
			return target ~= nil and (team[counter] or 0) >= target
		end,

		addScore = function(_self, userId, counter, amount)
			assertFinite(amount)
			local playerScores = scores[userId]
			if playerScores == nil then
				playerScores = {}
				scores[userId] = playerScores
			end
			local value = (playerScores[counter] or 0) + amount
			playerScores[counter] = value
			return value
		end,

		scoreOf = function(_self, userId, counter)
			local playerScores = scores[userId]
			return if playerScores ~= nil then playerScores[counter] or 0 else 0
		end,

		container = function(_self, name)
			local items = containers[name]
			if items == nil then
				items = {}
				containers[name] = items
			end
			return items
		end,

		nextUid = function(_self)
			uidCounter += 1
			return `r{round}-{uidCounter}`
		end,

		snapshot = function(_self, state)
			local scoreCopy: { [string]: { [string]: number } } = {}
			for userId, playerScores in scores do
				scoreCopy[tostring(userId)] = table.clone(playerScores)
			end
			local containerCopy: { [string]: { InventoryEntry } } = {}
			for name, items in containers do
				local entries: { InventoryEntry } = {}
				for _, entry in items do
					table.insert(entries, copyEntry(entry))
				end
				containerCopy[name] = entries
			end
			return {
				phase = state.phase,
				round = state.round,
				endsAt = state.endsAt,
				outcome = state.outcome,
				participants = sortedKeys(participants),
				eliminated = sortedKeys(eliminated),
				team = table.clone(team),
				targets = table.clone(targets),
				scores = scoreCopy,
				containers = containerCopy,
			}
		end,
	}
	return tracker
end

return RoundRunTracker
