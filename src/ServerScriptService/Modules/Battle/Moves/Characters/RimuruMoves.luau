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

local RimuruMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function RimuruMoves.getPredatorMimic()
	return Move.BaseMove.new({
		name = MoveData.PredatorMimic.name,
		element = MoveData.PredatorMimic.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "PredatorAnimation",
			accuracy = Condition.Prob.new(MoveData.PredatorMimic.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local target = context.defender
				if target.moves and #target.moves > 0 then
					local randomMove = target.moves[math.random(#target.moves)]
					context.attacker._mimickedMove = randomMove
					Effect.registerBuff(context.attacker, { name = "Predator", desc = `Mimicked: {randomMove}` })
					fireLog(context, `{context.attacker.itemType} mimics {randomMove}!`, "passive")
				end
			end),
		}),
	})
end

function RimuruMoves.getWaterBlade()
	return Move.BaseMove.new({
		name = MoveData.WaterBlade.name,
		element = MoveData.WaterBlade.element,
		attempt = Attempt.Combo.new({
			animation = "WaterBladeAnimation",
			accuracy = Condition.Prob.new(90),
			hits = Number.Weighted.new({
				{value = 2, weight = 0.5},
				{value = 3, weight = 0.3},
				{value = 4, weight = 0.2},
			}),
			every = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(35))
		}),
	})
end

function RimuruMoves.getBeelzebub()
	return Move.BaseMove.new({
		name = MoveData.Beelzebub.name,
		element = MoveData.Beelzebub.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "BeelzebubAnimation",
			accuracy = Condition.Prob.new(MoveData.Beelzebub.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Beelzebub.power)),
				Effect.Hook.new("AfterMove", function(context)
					local healAmount = math.floor(context.damage * (MoveData.Beelzebub.params.healPercent / 100))
					context.attacker:heal(healAmount)
					fireLog(context, `{context.attacker.itemType} devours and heals {healAmount} HP!`, "buff")
				end)
			}),
		}),
	})
end

function RimuruMoves.getBarrierWall()
	return Move.BaseMove.new({
		name = MoveData.BarrierWall.name,
		element = MoveData.BarrierWall.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "BarrierAnimation",
			accuracy = Condition.Prob.new(MoveData.BarrierWall.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				local shieldAmount = math.floor(battler.maxHp * (MoveData.BarrierWall.params.shieldPercent / 100))
				battler._barrierShield = shieldAmount
				Effect.registerBuff(battler, { name = "Barrier", desc = `Shield: {shieldAmount} HP ({MoveData.BarrierWall.params.duration} turns)` })
				fireLog(context, `{battler.itemType} creates a barrier!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.BarrierWall.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 or battler._barrierShield <= 0 then
						battler._barrierShield = 0
						Effect.removeBuff(battler, "Barrier")
						fireLog({ battle = battle }, `{battler.itemType}'s barrier shatters.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function RimuruMoves.getStormTempest()
	return Move.BaseMove.new({
		name = MoveData.StormTempest.name,
		element = MoveData.StormTempest.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "StormTempestAnimation",
			accuracy = Condition.Prob.new(MoveData.StormTempest.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.StormTempest.power)),
		}),
	})
end

function RimuruMoves.getUltimateEvolve()
	return Move.BaseMove.new({
		name = MoveData.UltimateEvolve.name,
		element = MoveData.UltimateEvolve.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "UltimateEvolveAnimation",
			accuracy = Condition.Prob.new(MoveData.UltimateEvolve.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				if battler._copiedMoves and #battler._copiedMoves > 0 then
					local randomCopiedMove = battler._copiedMoves[math.random(#battler._copiedMoves)]
					battler._ultimateEvolveMove = randomCopiedMove
					Effect.registerBuff(battler, { name = "Evolved", desc = `Permanently gained: {randomCopiedMove}` })
					fireLog(context, `{battler.itemType} permanently evolves with {randomCopiedMove}!`, "passive")
				end
			end),
		}),
	})
end

return RimuruMoves
