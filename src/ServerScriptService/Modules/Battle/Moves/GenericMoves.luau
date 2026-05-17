--!strict
--[=[
	Generic Moves - Basic moves available to all characters
	
	@class GenericMoves
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Target = require(ServerScriptService.Modules.Battle.Base.Target)
local Number = require(ReplicatedStorage.Shared.Classes.Number)
local MoveData = require(ReplicatedStorage.Shared.Data.MoveData)
local Condition = require(ServerScriptService.Modules.Battle.Base.Condition)
local Effect = require(ServerScriptService.Modules.Battle.Base.Effect)
local Attempt = require(ServerScriptService.Modules.Battle.Base.Attempt)
local Move = require(ServerScriptService.Modules.Battle.Base.Move)

local GenericMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function GenericMoves.getTackle()
	local attempt = Attempt.SingleAttempt.new({
		animation = "TackleAnimation",
		accuracy = Condition.Prob.new(95),
		onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(40)),
	})
	return Move.BaseMove.new({
		name = MoveData.Tackle.name,
		element = MoveData.Tackle.element,
		attempt = attempt,
	})
end

function GenericMoves.getStrike()
	local attempt = Attempt.SingleAttempt.new({
		animation = "StrikeAnimation",
		accuracy = Condition.Prob.new(MoveData.Tackle.accuracy),
		onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Tackle.power)),
	})
	return Move.BaseMove.new({
		name = MoveData.Strike.name,
		element = MoveData.Strike.element,
		attempt = attempt,
	})
end

function GenericMoves.getThunderbolt()
	local attempt = Attempt.SingleAttempt.new({
		animation = "ThunderboltAnimation",
		accuracy = Condition.Prob.new(MoveData.Thunderbolt.accuracy),
		onHit = Effect.Sequence.new({
			Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Thunderbolt.power)),
			Effect.ConditionEffect.new(
				Condition.Prob.new(MoveData.Thunderbolt.params.paralysisChance),
				Effect.Paralysis.new(Target.Defender.new())
			)
		}),
	})
	return Move.BaseMove.new({
		name = MoveData.Thunderbolt.name,
		element = MoveData.Thunderbolt.element,
		attempt = attempt,
	})
end

function GenericMoves.getProtect()
	local attempt = Attempt.SingleAttempt.new({
		animation = "ProtectAnimation",
		accuracy = Condition.Prob.new(MoveData.Thunderbolt.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			local battler = context.attacker
			battler._protectActive = true
			fireLog(context, `{battler.itemType} is protected!`, "buff")
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.Protect.name,
		element = MoveData.Protect.element,
		attempt = attempt,
	})
end

function GenericMoves.getBodySlam()
	local attempt = Attempt.SingleAttempt.new({
		animation = "BodySlamAnimation",
		accuracy = Condition.Prob.new(MoveData.BodySlam.accuracy),
		onHit = Effect.Sequence.new({
			Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.BodySlam.power)),
			Effect.ConditionEffect.new(
				Condition.Prob.new(MoveData.BodySlam.params.paralysisChance),
				Effect.Paralysis.new(Target.Defender.new())
			)
		}),
	})
	return Move.BaseMove.new({
		name = MoveData.BodySlam.name,
		element = MoveData.BodySlam.element,
		attempt = attempt,
	})
end

function GenericMoves.getTripleKick()
	local attempt = Attempt.Cascade.new({
		Attempt.SingleAttempt.new({
			animation = "KickAnimation",
			accuracy = Condition.Prob.new(MoveData.TripleKick.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.TripleKick.power)),
		}),
		Attempt.SingleAttempt.new({
			animation = "KickAnimation",
			accuracy = Condition.Prob.new(MoveData.TripleKick.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.TripleKick.power)),
		}),
		Attempt.SingleAttempt.new({
			animation = "KickAnimation",
			accuracy = Condition.Prob.new(MoveData.TripleKick.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.TripleKick.power)),
		}),
	})
	return Move.BaseMove.new({
		name = MoveData.TripleKick.name,
		element = MoveData.TripleKick.element,
		attempt = attempt,
	})
end

function GenericMoves.getJumpKick()
	local attempt = Attempt.SingleAttempt.new({
		animation = "JumpKickAnimation",
		accuracy = Condition.Prob.new(MoveData.JumpKick.accuracy),
		onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.JumpKick.power)),
		onMiss = Effect.DirectDamage.new(Target.Attacker.new(), Number.Exactly.new(MoveData.JumpKick.power)),
	})
	return Move.BaseMove.new({
		name = MoveData.JumpKick.name,
		element = MoveData.JumpKick.element,
		attempt = attempt,
	})
end

function GenericMoves.getFuryAttack()
	local attempt = Attempt.Combo.new({
		animation = "TackleAnimation",
		accuracy = Condition.Prob.new(MoveData.FuryAttack.accuracy),
		hits = Number.Weighted.new({
			{value = 2, weight = 0.375},
			{value = 3, weight = 0.375},
			{value = 4, weight = 0.125},
			{value = 5, weight = 0.125},
		}),
		every = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.FuryAttack.power))
	})
	return Move.BaseMove.new({
		name = MoveData.FuryAttack.name,
		element = MoveData.FuryAttack.element,
		attempt = attempt,
	})
end

function GenericMoves.getThunderWave()
	local attempt = Attempt.SingleAttempt.new({
		animation = "ThunderWaveAnimation",
		accuracy = Condition.Prob.new(MoveData.ThunderWave.accuracy),
		onHit = Effect.Paralysis.new(Target.Defender.new()),
	})
	return Move.BaseMove.new({
		name = MoveData.ThunderWave.name,
		element = MoveData.ThunderWave.element,
		attempt = attempt,
	})
end

function GenericMoves.getFutureSight()
	local attempt = Attempt.SingleAttempt.new({
		animation = "FutureSightAnimation",
		accuracy = Condition.Prob.new(MoveData.FutureSight.accuracy),
		onHit = Effect.FutureSight.new(MoveData.FutureSight.power),
	})
	return Move.BaseMove.new({
		name = MoveData.FutureSight.name,
		element = MoveData.FutureSight.element,
		attempt = attempt,
	})
end

return GenericMoves
