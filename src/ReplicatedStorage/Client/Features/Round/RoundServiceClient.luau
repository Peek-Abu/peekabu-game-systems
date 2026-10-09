--!strict
--[=[
	RoundServiceClient: the round as the local client sees it (design:
	docs/superpowers/specs/2026-10-09-round-design.md). A read facade over the `round` StateSync world
	entry: `snapshot` is a Charm computed atom (React reads it with `useAtom`), decoded by RoundSnapshotUtils;
	`phaseChanged` fires when the phase or the round number changes. The client never writes the round.

	Spec-exempt shell (Charm, the local player); decoding is the specced RoundSnapshotUtils.

	@class RoundServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local RoundConstants = require(ReplicatedStorage.Shared.Features.Round.Data.RoundConstants)
local RoundTypes = require(ReplicatedStorage.Shared.Features.Round.Data.RoundTypes)
local RoundSnapshotUtils = require(ReplicatedStorage.Shared.Features.Round.Utils.RoundSnapshotUtils)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

type RoundSnapshot = RoundTypes.RoundSnapshot

local snapshot = Charm.computed(function(): RoundSnapshot?
	return RoundSnapshotUtils.decode(StateSyncClientStore.world()[RoundConstants.WORLD_ENTRY])
end)

local phaseChanged: SignalTyped.Signal<RoundSnapshot> = SignalTyped.new()
local unsubscribe: (() -> ())? = nil

export type RoundServiceClient = {
	dependencies: { string },
	snapshot: () -> RoundSnapshot?,
	phaseChanged: SignalTyped.Signal<RoundSnapshot>,

	start: (self: RoundServiceClient) -> (),
	stop: (self: RoundServiceClient) -> (),
	get: (self: RoundServiceClient) -> RoundSnapshot?,
	timeLeft: (self: RoundServiceClient) -> number?,
	isParticipant: (self: RoundServiceClient, userId: number?) -> boolean,
	isEliminated: (self: RoundServiceClient, userId: number?) -> boolean,
	getState: (self: RoundServiceClient) -> { [string]: any },
}

local RoundServiceClient: RoundServiceClient = {
	dependencies = { "StateSyncServiceClient" },
	snapshot = snapshot,
	phaseChanged = phaseChanged,

	start = function(_self)
		local lastPhase: string? = nil
		local lastRound: number? = nil
		unsubscribe = Charm.subscribe(snapshot, function(current: RoundSnapshot?)
			if current == nil then
				return
			end
			if current.phase ~= lastPhase or current.round ~= lastRound then
				lastPhase = current.phase
				lastRound = current.round
				phaseChanged:Fire(current)
			end
		end)
	end,

	stop = function(_self)
		local stopListening = unsubscribe
		if stopListening ~= nil then
			stopListening()
			unsubscribe = nil
		end
	end,

	--[=[
		The current round, or nil before the first sync.
	]=]
	get = function(_self)
		return snapshot()
	end,

	--[=[
		Seconds until the current phase ends (never negative), or nil for an untimed phase.
	]=]
	timeLeft = function(_self)
		local current = snapshot()
		local endsAt = if current ~= nil then current.endsAt else nil
		if endsAt == nil then
			return nil
		end
		return math.max(0, endsAt - workspace:GetServerTimeNow())
	end,

	--[=[
		Whether a player (default: the local player) is in the current run.
	]=]
	isParticipant = function(_self, userId)
		local current = snapshot()
		return current ~= nil and table.find(current.participants, userId or Players.LocalPlayer.UserId) ~= nil
	end,

	isEliminated = function(_self, userId)
		local current = snapshot()
		return current ~= nil and table.find(current.eliminated, userId or Players.LocalPlayer.UserId) ~= nil
	end,

	getState = function(_self)
		local current = snapshot()
		return {
			phase = if current ~= nil then current.phase else "unsynced",
			round = if current ~= nil then current.round else nil,
			participants = if current ~= nil then #current.participants else 0,
		}
	end,
}

return RoundServiceClient
