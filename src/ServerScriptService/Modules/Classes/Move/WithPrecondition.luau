--!strict
local BaseMove = require(script.Parent.BaseMove)

local WithPrecondition = {}
WithPrecondition.__index = WithPrecondition
setmetatable(WithPrecondition, BaseMove)

function WithPrecondition.new(move: BaseMove.BaseMove, precondition: (battle: any, user: any) -> boolean)
	local self = setmetatable(BaseMove.new(move.name), WithPrecondition)
	self.move = move
	self.precondition = precondition
	return self
end

function WithPrecondition:execute(battle: any, user: any, target: any)
	if self.precondition(battle, user) then
		self.move:execute(battle, user, target)
	else
		print(user.itemType .. " cannot use " .. self.name .. " due to precondition failure!")
	end
end

export type WithPrecondition = typeof(setmetatable({} :: { move: BaseMove.BaseMove, precondition: any }, WithPrecondition))

return WithPrecondition
