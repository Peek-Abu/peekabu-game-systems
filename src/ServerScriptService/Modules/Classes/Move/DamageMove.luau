--!strict
local BaseMove = require(script.Parent.BaseMove)

local DamageMove = {}
DamageMove.__index = DamageMove
setmetatable(DamageMove, BaseMove)

function DamageMove.new(name: string, baseDamage: number)
	local self = setmetatable(BaseMove.new(name), DamageMove)
	self.baseDamage = baseDamage
	return self
end

function DamageMove:execute(battle: any, user: any, target: any)
	-- Simple damage formula for now: (user.attack * baseDamage) / target.defense
	local damage = math.floor((user.attack * self.baseDamage) / math.max(1, target.defense))
	print(user.itemType .. " dealt " .. damage .. " damage to " .. target.itemType .. " with " .. self.name)
	target:takeDamage(damage)
end

export type DamageMove = typeof(setmetatable({} :: { baseDamage: number }, DamageMove))

return DamageMove
