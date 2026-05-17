--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Action = require(script.Parent.Action)

local ItemAction = {}
ItemAction.__index = ItemAction
setmetatable(ItemAction, Action)

function ItemAction.new(user: any, itemType: string)
	local self = setmetatable(Action.new(), ItemAction)
	self.user = user
	self.itemType = itemType
	self.priority = 6
	return self
end

function ItemAction:execute(battleSession: any)
	print(`{self.user.itemType} used item {self.itemType}!`)
	-- Stub implementation for now
end

return ItemAction
