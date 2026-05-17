--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Action = require(script.Parent.Action)

local SwitchAction = {}
SwitchAction.__index = SwitchAction
setmetatable(SwitchAction, Action)

function SwitchAction.new(user: any, targetSlot: any)
	local self = setmetatable(Action.new(), SwitchAction)
	self.user = user
	self.targetSlot = targetSlot
	self.priority = 6
	return self
end

function SwitchAction:execute(battleSession: any)
	print(`Switching {self.user.itemType} to slot {self.targetSlot}...`)
	-- Stub implementation for now
end

return SwitchAction
