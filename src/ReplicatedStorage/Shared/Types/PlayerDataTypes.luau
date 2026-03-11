--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)

export type CurrencyType = CurrencyConstants.CurrencyType

export type InventoryItem = {
	itemType: string, -- the internal definition key
	quantity: number?, -- only for stackable items
	instanceId: string?, -- optional, for unique/modified
}

-- Item definitions example:
export type ItemDefinition = {
	name: string,
	rarity: string,
	icon: string,
}

-- Currency uses CurrencyType as keys
export type Currency = {
	[CurrencyType]: number,
}

export type PlayerProfile = {
	_schemaVersion: number?, -- Managed by PlayerDataMigrations; absent on client-built profiles
	currency: Currency,
	inventory: { InventoryItem },
	-- Extend with other fields/services here
}

-- Dynamically registered strings
export type ProfilePath = string

export type ExpandedInventoryItem = InventoryItem & ItemDefinition

export type PlayerDataServiceConfigs = {
	useMock: boolean,
	storeName: string,
	template: PlayerProfile,
}

-- This module is types-only at runtime — every export above is an `export type`. Consumers
-- `require()` it purely for type annotations (e.g. `PlayerDataTypes.Currency`), never for a value.
return {}
