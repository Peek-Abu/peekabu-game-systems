--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage.Shared.Modules.ItemDefinitions)

export type GameItems = {}

local GameItems = {}

function GameItems.init()
	ItemDefinitions["iron-sword"] = {
		name = "Iron Blade",
		icon = "rbxassetid://123",
		rarity = "Common",
	}
	ItemDefinitions["phoenix-blade"] = {
		name = "Phoenix Blade",
		icon = "rbxassetid://456",
		rarity = "Legendary",
	}
end

return GameItems
