--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TitleShared = ReplicatedStorage.Shared.Features.Title
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local TitleEvents = require(TitleShared.Net.TitleEvents)
local TitleRegistry = require(TitleShared.Data.TitleRegistry)
local TitleRequestRules = require(TitleShared.Rules.TitleRequestRules)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `StateSyncClientStore.titles` / `StateSyncClientStore.equippedTitle`, the one client
	source of truth (populated by charm-sync). Reactive UI reads the atoms directly via `useAtom`;
	imperative callers use these point-in-time accessors. The single WRITE is a fire-and-forget
	equip REQUEST — the server is authoritative, and the outcome arrives as a charm-sync delta.
]=]
export type TitleServiceClient = {
	dependencies: { string },

	getEarned: (self: TitleServiceClient) -> PlayerDataTypes.Titles,
	getEquippedTitle: (self: TitleServiceClient) -> string?,
	hasTitle: (self: TitleServiceClient, titleId: string) -> boolean,
	requestEquip: (self: TitleServiceClient, titleId: string) -> (),
}

local function assertNonEmptyTitleId(titleId: string)
	assert(type(titleId) == "string" and titleId ~= "", `invalid title id: {tostring(titleId)}`)
end

local TitleServiceClient: TitleServiceClient = {
	dependencies = {},

	--[=[
		The local player's earned-title set (empty until the first sync — StateSyncClientStore.titles is
		non-optional, defaulted to `{ earned = {} }`).
		@return PlayerDataTypes.Titles
	]=]
	getEarned = function(_self)
		return StateSyncClientStore.titles()
	end,

	--[=[
		The title the local player's active character wears (StateSyncClientStore.equippedTitle is
		non-optional, defaulted to `{}`, so `.equipped` alone carries the unsynced/unworn case).
		@return string? -- nil when wearing nothing or unsynced
	]=]
	getEquippedTitle = function(_self)
		return StateSyncClientStore.equippedTitle().equipped
	end,

	--[=[
		Whether the local player has earned the title.
		@param titleId string -- A non-empty title id
		@return boolean -- false before first sync
	]=]
	hasTitle = function(self, titleId)
		assertNonEmptyTitleId(titleId)
		return self:getEarned().earned[titleId] == true
	end,

	--[=[
		Requests the server equip the given earned title. Fire-and-forget: refusals (not earned,
		rate limit) are dropped silently by design — RequestHandler's contract — and the atoms are
		the truth of what actually happened.
		@param titleId string -- A non-empty title id
	]=]
	requestEquip = function(_self, titleId)
		assertNonEmptyTitleId(titleId)
		if not TitleRegistry.isValidTitleId(titleId) then
			return
		end
		if not _self:hasTitle(titleId) then
			return
		end
		TitleEvents.packets.EquipRequest.send(TitleRequestRules.buildEquip(titleId))
	end,
}

return TitleServiceClient
