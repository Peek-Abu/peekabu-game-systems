--!strict
--[=[
	RankServiceClient: the company rank on this client (Cleanup Crew "Clearance Level"). Reads any player's published
	rank (their public entry; RankViewModel.rankOf). The server decides every rank; this only reads. A character
	shows its rank on its lanyard's ID card (the server's EmployeeGearSystem.badge), and the engine draws the name.

	@class RankServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

export type RankServiceClient = {
	dependencies: { string },
	rankOf: (self: RankServiceClient, userId: number) -> RankViewModel.Rank?,
}

local RankServiceClient: RankServiceClient = {
	dependencies = { "StateSyncServiceClient" },

	--[=[
		A player's published XP (and the XP before their latest award), or nil until the server publishes it.
	]=]
	rankOf = function(_self, userId)
		return RankViewModel.rankOf(StateSyncClientStore.publicPlayers(), userId)
	end,
}

return RankServiceClient
