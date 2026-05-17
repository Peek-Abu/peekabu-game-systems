--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Target = require(ServerScriptService.Modules.Battle.Base.Target)
local Number = require(ReplicatedStorage.Shared.Classes.Number)
local MoveData = require(ReplicatedStorage.Shared.Data.MoveData)
local Condition = require(ServerScriptService.Modules.Battle.Base.Condition)
local Effect = require(ServerScriptService.Modules.Battle.Base.Effect)
local Attempt = require(ServerScriptService.Modules.Battle.Base.Attempt)
local Move = require(ServerScriptService.Modules.Battle.Base.Move)

local GojoMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function GojoMoves.getLapseBlue()
	return Move.BaseMove.new({
		name = MoveData.LapseBlue.name,
		element = MoveData.LapseBlue.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "LapseBlueAnimation",
			accuracy = Condition.Prob.new(MoveData.LapseBlue.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.LapseBlue.power)),
		}),
	})
end

function GojoMoves.getReversalRed()
	return Move.BaseMove.new({
		name = MoveData.ReversalRed.name,
		element = MoveData.ReversalRed.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "ReversalRedAnimation",
			accuracy = Condition.Prob.new(MoveData.ReversalRed.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.ReversalRed.power)),
		}),
	})
end

function GojoMoves.getHollowPurple()
	return Move.BaseMove.new({
		name = MoveData.HollowPurple.name,
		element = MoveData.HollowPurple.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "HollowPurpleAnimation",
			accuracy = Condition.Prob.new(MoveData.HollowPurple.accuracy),
			onHit = Effect.Hook.new("BeforeHit", function(context)
				context._ignoreDefense = true
				context.defender:takeDamage(MoveData.HollowPurple.power);
				fireLog(context, `{context.attacker.itemType}: Hollow Purple!`)
			end),
		}),
	})
end

function GojoMoves.getDomainExpansion()
	return Move.BaseMove.new({
		name = MoveData.DomainExpansion.name,
		element = MoveData.DomainExpansion.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "DomainExpansionAnimation",
			accuracy = Condition.Prob.new(MoveData.DomainExpansion.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				battler._domainActive = true
				Effect.registerBuff(battler, { name = "Domain Expansion", desc = `All attacks guaranteed hit ({MoveData.DomainExpansion.params.duration} turns)` })
				fireLog(context, `{battler.itemType}: Domain Expansion!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.DomainExpansion.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler._domainActive = false
						Effect.removeBuff(battler, "Domain Expansion")
						fireLog({ battle = battle }, `{battler.itemType}'s Domain Expansion collapses.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function GojoMoves.getTeleportSwap()
	return Move.BaseMove.new({
		name = MoveData.TeleportSwap.name,
		element = MoveData.TeleportSwap.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "TeleportAnimation",
			accuracy = Condition.Prob.new(MoveData.TeleportSwap.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				context.attacker._nextAttackBonus = MoveData.TeleportSwap.params.nextAttackBonus
				Effect.registerBuff(context.attacker, { name = "Teleport", desc = `Next attack +{(MoveData.TeleportSwap.params.nextAttackBonus - 1) * 100}% damage` })
				fireLog(context, `{context.attacker.itemType} teleports into position!`, "buff")
			end),
		}),
	})
end

function GojoMoves.getUnlimitedVoid()
	return Move.BaseMove.new({
		name = MoveData.UnlimitedVoid.name,
		element = MoveData.UnlimitedVoid.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "UnlimitedVoidAnimation",
			accuracy = Condition.Prob.new(MoveData.UnlimitedVoid.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local target = context.defender
				target._unlimitedVoidStun = MoveData.UnlimitedVoid.params.stunDuration
				Effect.registerBuff(target, { name = "Unlimited Void", desc = `Trapped in Unlimited Void ({MoveData.UnlimitedVoid.params.stunDuration} turns)` })
				fireLog(context, `{target.itemType} is trapped in Unlimited Void!`, "status")

				local battle = context.battle
				local turnsLeft = MoveData.UnlimitedVoid.params.stunDuration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= target then return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						target._unlimitedVoidStun = 0
						Effect.removeBuff(target, "Unlimited Void")
						fireLog({ battle = battle }, `{target.itemType} escapes Unlimited Void.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

return GojoMoves
