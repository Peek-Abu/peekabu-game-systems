--!strict
local BaseMove = require(script.Parent.BaseMove)

local WithApplicability = {}
WithApplicability.__index = WithApplicability
setmetatable(WithApplicability, BaseMove)

function WithApplicability.new(move: BaseMove.BaseMove, check: (battle: any, target: any) -> boolean)
	local self = setmetatable(BaseMove.new(move.name), WithApplicability)
	self.move = move
	self.check = check
	return self
end

function WithApplicability:execute(battle: any, user: any, target: any)
	if self.check(battle, target) then
		self.move:execute(battle, user, target)
	else
		print(self.name .. " is not applicable to " .. target.itemType)
	end
end

export type WithApplicability = typeof(setmetatable({} :: { move: BaseMove.BaseMove, check: any }, WithApplicability))

return WithApplicability
