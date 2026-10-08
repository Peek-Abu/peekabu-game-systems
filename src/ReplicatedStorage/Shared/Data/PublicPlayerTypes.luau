--!strict
--[=[
	PublicPlayerTypes: what any client may know about another player (spec Verdict, "Other players' public
	data rides charm-sync"; plan R2 Task 8). Never private data. R2 carried health; R4 adds the player's
	active appearance and its version. The equipped title and nameplates are NOT in R4.

	The map is keyed by the userId as a STRING (`StateSyncConstants.publicEntryKey`): charm-sync ships it through a
	RemoteEvent, and string keys keep it a plain dictionary on the wire.

	@class PublicPlayerTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

export type PublicPlayer = {
	health: number,
	maxHealth: number,
	appearance: PlayerDataTypes.Appearance,
	appearanceVersion: number,
}

export type PublicPlayerMap = { [string]: PublicPlayer }

return {}
