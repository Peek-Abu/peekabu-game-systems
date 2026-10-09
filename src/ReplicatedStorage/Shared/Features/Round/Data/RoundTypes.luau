--!strict
--[=[
	RoundTypes: the round / match lifecycle's shapes (design:
	docs/superpowers/specs/2026-10-09-round-design.md).

	@class RoundTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

export type Phase = "lobby" | "starting" | "running" | "results"

--[=[
	How a game runs its matches. Every field has a default (RoundConstants.DEFAULT_CONFIG); `configure`
	takes a partial table.
	- minPlayers: players present before a countdown may start, and to keep it going.
	- countdown: seconds in `starting`.
	- duration: seconds in `running`; nil = until the game calls endRound (or the run empties).
	- resultsDuration: seconds in `results`.
	- autoStart: start a countdown on its own once minPlayers are present; false (the default, so a game that
	  never uses rounds stays in the lobby) = only startCountdown() / startNow().
	- lateJoin: a player who joins during `running` joins the run (otherwise they watch).
	- containerCapacity: entries per run container.
	- eligible: who joins a run when it starts; nil = everyone present.
]=]
export type RoundConfig = {
	minPlayers: number,
	countdown: number,
	duration: number?,
	resultsDuration: number,
	autoStart: boolean,
	lateJoin: boolean,
	containerCapacity: number,
	eligible: ((player: Player) -> boolean)?,
}

export type RoundConfigUpdate = {
	minPlayers: number?,
	countdown: number?,
	duration: number?,
	resultsDuration: number?,
	autoStart: boolean?,
	lateJoin: boolean?,
	containerCapacity: number?,
	eligible: ((player: Player) -> boolean)?,
}

--[=[
	The machine's own state. `endsAt` is in server time (`workspace:GetServerTimeNow()`) for a timed
	phase; `round` counts runs started on this server; `outcome` is set in `results`.
]=]
export type RoundState = {
	phase: Phase,
	round: number,
	endsAt: number?,
	outcome: string?,
}

--[=[
	The headcounts the machine needs on each step: players present, run participants still present, and
	of those, how many are not eliminated.
]=]
export type RoundCounts = {
	present: number,
	participants: number,
	alive: number,
}

--[=[
	What every client sees (the `round` world entry). Player maps are keyed by the userId as a string.
]=]
export type RoundSnapshot = {
	phase: Phase,
	round: number,
	endsAt: number?,
	outcome: string?,
	participants: { number },
	eliminated: { number },
	team: { [string]: number },
	targets: { [string]: number },
	scores: { [string]: { [string]: number } },
	containers: { [string]: { PlayerDataTypes.InventoryEntry } },
}

return {}
