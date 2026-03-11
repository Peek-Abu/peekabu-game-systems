--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)
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

-- Build CurrencyStruct dynamically from CurrencyConstants
local CurrencyStruct = {}
for _, currencyType in CurrencyConstants.getValidCurrencies() do
	CurrencyStruct[currencyType] = ByteNet.uint32
end

return {
	InventoryItemStruct = {
		itemType = ByteNet.string,
		quantity = ByteNet.optional(ByteNet.uint32),
		instanceId = ByteNet.optional(ByteNet.string),
	},
	CurrencyStruct = CurrencyStruct,
}
