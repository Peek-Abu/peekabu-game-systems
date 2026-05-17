--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BattleTypes = require(ReplicatedStorage.Shared.Types.BattleTypes)

-- BaseMove interface/abstract class
local BaseMove = {}
BaseMove.__index = BaseMove

function BaseMove.new(name: string)
	local self = setmetatable({}, BaseMove)
	self.name = name
	return self
end

-- Abstract method: must be overridden by concrete moves or decorators
function BaseMove:execute(battle: any, user: any, target: any)
	error("execute() must be implemented by concrete move or decorator")
end

export type BaseMove = typeof(setmetatable({} :: { name: string }, BaseMove))

return BaseMove
