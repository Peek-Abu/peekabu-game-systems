--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local CustomizationSoulColorRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationSoulColorRegistry)

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	A thin read-facade over `StateSyncClientStore.appearance` (the ACTIVE character's equipped look) and
	`StateSyncClientStore.entitlements` (the ACCOUNT's unlocks — shared by every character). Same shape as the
	other client facades: reactive UI reads the atoms directly via `useAtom`; imperative callers use
	these point-in-time accessors. Equipping/unlocking is server-authoritative
	(CustomizationServiceServer) — the client never writes.

	`isUnlocked` is the read-only mirror of the server's ownership gate, for graying out locked entries
	in a future customization UI. It is NOT a security boundary: the server re-checks on every equip.
]=]
export type CustomizationServiceClient = {
	dependencies: { string },

	getAppearance: (self: CustomizationServiceClient) -> PlayerDataTypes.Appearance,
	getEntitlements: (self: CustomizationServiceClient) -> PlayerDataTypes.Entitlements,
	isUnlocked: (self: CustomizationServiceClient, category: string, id: string) -> boolean,
	getSoulColor: (self: CustomizationServiceClient) -> string?,
	getSoulColorGradient: (
		self: CustomizationServiceClient
	) -> { { position: number, color: { r: number, g: number, b: number } } }?,
}

local CustomizationServiceClient: CustomizationServiceClient = {
	dependencies = {},

	--[=[
		The local player's equipped appearance (empty until the first sync).
		@return PlayerDataTypes.Appearance
	]=]
	getAppearance = function(_self)
		return StateSyncClientStore.appearance()
	end,

	--[=[
		The account's unlocked cosmetics/soul colors (empty until the first sync).
		@return PlayerDataTypes.Entitlements
	]=]
	getEntitlements = function(_self)
		return StateSyncClientStore.entitlements()
	end,

	--[=[
		Whether the local player may equip a cosmetic: free ids are always available, lockable ids only
		once unlocked. Display-only — the server is authoritative (see the class doc).
		@param category string -- The cosmetic's category
		@param id string -- The cosmetic id
		@return boolean
	]=]
	isUnlocked = function(_self, category, id)
		if not CustomizationCosmeticRegistry.isLockable(category, id) then
			return true
		end
		local owned = StateSyncClientStore.entitlements().cosmetics[category]
		return owned ~= nil and owned[id] == true
	end,

	--[=[
		The local character's soul colour id, or nil if it has none. May be multi-hue ("blue-green").
		@return string?
	]=]
	getSoulColor = function(_self)
		return StateSyncClientStore.appearance().soulColor
	end,

	--[=[
		The equipped soul colour resolved into gradient stops, or nil when there is none (or the stored
		id is no longer registered). This is the seam VFX reads to tint an effect — it returns plain
		data, so the caller builds the engine `ColorSequence` from it.
		@return { { position: number, color: { r: number, g: number, b: number } } }?
	]=]
	getSoulColorGradient = function(_self)
		local soulColor = StateSyncClientStore.appearance().soulColor
		if not soulColor then
			return nil
		end
		return CustomizationSoulColorRegistry.gradient(soulColor)
	end,
}

return CustomizationServiceClient
