--!strict

local Action = {}
Action.__index = Action

function Action.new()
	local self = setmetatable({}, Action)
	return self
end

function Action:execute(battleSession: any): ()
	error("execute() must be implemented by concrete action")
end

function Action:getPriority(): number
	return (self :: any).priority or 0
end

return Action
