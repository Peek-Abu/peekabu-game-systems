--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ICondition interface
local Condition = {}
Condition.__index = Condition

function Condition.new()
	local self = setmetatable({}, Condition)
	return self
end

function Condition:check(context: any): boolean
	error("check() must be implemented by concrete condition")
end

-- Logical Conditions
local And = {}
And.__index = And
setmetatable(And, Condition)

function And.new(conditions: { any })
	local self = setmetatable(Condition.new(), And)
	self.conditions = conditions
	return self
end

function And:check(context: any): boolean
	for _, cond in self.conditions do
		if not cond:check(context) then
			return false
		end
	end
	return true
end

local Or = {}
Or.__index = Or
setmetatable(Or, Condition)

function Or.new(conditions: { any })
	local self = setmetatable(Condition.new(), Or)
	self.conditions = conditions
	return self
end

function Or:check(context: any): boolean
	for _, cond in self.conditions do
		if cond:check(context) then
			return true
		end
	end
	return false
end

local Not = {}
Not.__index = Not
setmetatable(Not, Condition)

function Not.new(condition: any)
	local self = setmetatable(Condition.new(), Not)
	self.condition = condition
	return self
end

function Not:check(context: any): boolean
	return not self.condition:check(context)
end

-- Probabilistic Condition
local Prob = {}
Prob.__index = Prob
setmetatable(Prob, Condition)

function Prob.new(chance: number, tag: string?) -- 0 to 100
	local self = setmetatable(Condition.new(), Prob)
	self.chance = chance
	self.tag = tag
	return self
end

function Prob:check(context: any): boolean
	local chance = self.chance

	-- Pull probability modifiers if context and tag are available
	if context and context._modifiers and self.tag then
		local BattleModifiers = require(script.Parent.BattleModifiers)
		chance += BattleModifiers.getChanceBonus(context, self.tag)
	end

	return (math.random() * 100) < chance
end

-- Battler Specific (Context is Battle)
local ForTarget = {}
ForTarget.__index = ForTarget
setmetatable(ForTarget, Condition)

function ForTarget.new(target: any, condition: any)
	local self = setmetatable(Condition.new(), ForTarget)
	self.target = target
	self.condition = condition
	return self
end

function ForTarget:check(context: any): boolean
	local targets = self.target:resolve(context)
	local battler = targets and targets[1] or targets
	return self.condition:check(battler)
end

-- Battler Checks (Context is Battler)
local HasStatus = {}
HasStatus.__index = HasStatus
setmetatable(HasStatus, Condition)

function HasStatus.new(statusEffect: string)
	local self = setmetatable(Condition.new(), HasStatus)
	self.statusEffect = statusEffect
	return self
end

function HasStatus:check(battler: any): boolean
	return table.find(battler.statusEffects, self.statusEffect) ~= nil
end

return {
	And = And,
	Or = Or,
	Not = Not,
	Prob = Prob,
	ForTarget = ForTarget,
	HasStatus = HasStatus,
}
