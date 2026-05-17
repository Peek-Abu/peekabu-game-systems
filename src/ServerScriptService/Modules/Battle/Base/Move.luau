--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Target = require(ServerScriptService.Modules.Battle.Base.Target)

-- IMove interface
local Move = {}
Move.__index = Move

function Move.new()
	local self = setmetatable({}, Move)
	return self
end

function Move:execute(context: any): ()
	error("execute() must be implemented by concrete move")
end

-- Helper: fire a BattleLog event if a battle context is available
local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

-- Concrete Move
local BaseMove = {}
BaseMove.__index = BaseMove
setmetatable(BaseMove, Move)

function BaseMove.new(config: {
	name: string,
	element: string?,
	target: any?, -- Target class instance (default: Target.Defender)
	cooldown: number?, -- turns between uses (0 = no cooldown)
	attempt: any, -- IAttempt
	reactions: { -- Defender QTE windows (optional). Player picks ONE to attempt.
		{
			type: string, -- "Parry" | "Dodge" | custom
			time: number?, -- when window opens relative to animation start (seconds)
			duration: number?, -- window length (seconds, default 0.5)
			perHit: boolean?, -- if true, QTE opens per-hit in Combo moves
		}
	}?,
	attackerReactions: { -- Attacker QTE windows (optional). Can be multiple (sequence).
		{
			type: string, -- "Timing" | "Mash" | "Rhythm" | custom
			time: number?, -- when window opens relative to animation start (seconds)
			duration: number?, -- window length (seconds, default 0.4)
			bonusMultiplier: number?, -- damage multiplier on success (default 1.25)
		}
	}?,
})
	local self = setmetatable(Move.new(), BaseMove)
	self.name = config.name
	self.element = config.element
	self.target = config.target or Target.Defender.new()
	self.cooldown = config.cooldown or 0
	self.attempt = config.attempt
	self.reactions = config.reactions
	self.attackerReactions = config.attackerReactions
	return self
end

function BaseMove:execute(context: any)
	self.attempt:execute(context)
end

-- Decorators
local WithPrecondition = {}
WithPrecondition.__index = WithPrecondition
setmetatable(WithPrecondition, Move)

function WithPrecondition.new(move: any, condition: any) -- IMove, ICondition
	local self = setmetatable(Move.new(), WithPrecondition)
	self.move = move
	self.condition = condition
	return self
end

function WithPrecondition:execute(context: any)
	if self.condition:check(context) then
		self.move:execute(context)
	else
		fireLog(context, `Move {self.move.name or "Unknown"} failed precondition!`)
	end
end

local WithApplicability = {}
WithApplicability.__index = WithApplicability
setmetatable(WithApplicability, Move)

function WithApplicability.new(move: any, condition: any) -- IMove, ICondition
	local self = setmetatable(Move.new(), WithApplicability)
	self.move = move
	self.condition = condition
	return self
end

function WithApplicability:execute(context: any)
	if self.condition:check(context) then
		self.move:execute(context)
	else
		fireLog(context, `Move {self.move.name or "Unknown"} is not applicable here!`)
	end
end

return {
	BaseMove = BaseMove,
	WithPrecondition = WithPrecondition,
	WithApplicability = WithApplicability,
}
