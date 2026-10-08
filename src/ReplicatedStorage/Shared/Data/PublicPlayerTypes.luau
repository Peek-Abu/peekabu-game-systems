--!strict
--[=[
	PublicPlayerTypes: what any client may know about another player. Never private data.

	A PublicPlayer is a flat, game-owned record of small public facts — "is carrying an egg", "is dead",
	a team id, an equipped title. Values are deliberately limited to plain scalars so every entry stays
	cheap to diff and ship. A game that wants a narrow typed view declares it next to the code that
	publishes the fields (the store itself stays string-keyed, the same rationale as `ProfilePath`).

	The map is keyed by the userId as a STRING (`StateSyncConstants.publicEntryKey`): charm-sync ships it
	through a RemoteEvent, and string keys keep it a plain dictionary on the wire.

	@class PublicPlayerTypes
]=]

export type PublicValue = string | number | boolean

export type PublicPlayer = { [string]: PublicValue }

export type PublicPlayerMap = { [string]: PublicPlayer }

return {}
