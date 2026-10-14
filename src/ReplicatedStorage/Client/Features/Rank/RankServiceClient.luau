--!strict
--[=[
	RankServiceClient: the company rank on this client (Cleanup Crew "Clearance Level"). Starts the overhead badges
	(RankTagSystem) and reads any player's published rank (their public entry; RankViewModel.rankOf). The server
	decides every rank; this only reads and draws.

	@class RankServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local RankTagSystem = require(ReplicatedStorage.Client.Features.Rank.Systems.RankTagSystem)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

export type RankServiceClient = {
	dependencies: { string },
	start: (self: RankServiceClient) -> (),
	stop: (self: RankServiceClient) -> (),
	rankOf: (self: RankServiceClient, userId: number) -> RankViewModel.Rank?,
	getState: (self: RankServiceClient) -> { [string]: any },
}

local RankServiceClient: RankServiceClient = {
	dependencies = { "StateSyncServiceClient" },

	start = function(_self)
		RankTagSystem.start()
	end,

	stop = function(_self)
		RankTagSystem.stop()
	end,

	--[=[
		A player's published XP (and the XP before their latest award), or nil until the server publishes it.
	]=]
	rankOf = function(_self, userId)
		return RankViewModel.rankOf(StateSyncClientStore.publicPlayers(), userId)
	end,

	getState = function(_self)
		return RankTagSystem.getState()
	end,
}

return RankServiceClient
