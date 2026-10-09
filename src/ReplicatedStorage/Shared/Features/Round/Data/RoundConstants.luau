--!strict
--[=[
	RoundConstants: phase names, the default configuration, the built-in outcomes and the world entry
	name.

	@class RoundConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)

local DEFAULT_CONFIG: RoundTypes.RoundConfig = {
	minPlayers = 1,
	countdown = 10,
	duration = nil,
	resultsDuration = 8,
	-- Off by default so the base is inert: a game that never configures rounds stays in the lobby.
	autoStart = false,
	lateJoin = false,
	containerCapacity = 20,
	eligible = nil,
}

local PHASES: { RoundTypes.Phase } = { "lobby", "starting", "running", "results" }

local RoundConstants = {
	PHASES = table.freeze(PHASES),
	DEFAULT_CONFIG = table.freeze(DEFAULT_CONFIG),
	-- The StateSyncWorldStore entry the snapshot is published under.
	WORLD_ENTRY = "round",
	-- Outcomes the machine sets itself; a game's endRound may pass any other string.
	OUTCOME_TIMEOUT = "timeout",
	OUTCOME_ABANDONED = "abandoned",
	OUTCOME_WIPED = "wiped",
	OUTCOME_CANCELLED = "cancelled",
	-- How often the server steps the machine (seconds).
	TICK_INTERVAL = 0.25,
	-- The shared run container every participant may use.
	TEAM_CONTAINER = "team",
}

return table.freeze(RoundConstants)
