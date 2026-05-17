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

local AllMightMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function AllMightMoves.getDetroitSmash()
	return Move.BaseMove.new({
		name = MoveData.DetroitSmash.name,
		element = MoveData.DetroitSmash.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "DetroitSmashAnimation",
			accuracy = Condition.Prob.new(MoveData.DetroitSmash.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.DetroitSmash.power)),
				Effect.Hook.new("AfterMove", function(context)
					fireLog(context, `{context.attacker.itemType}: Detroit... SMASH!`)
				end)
			}),
		}),
	})
end

function AllMightMoves.getUnitedStatesSmash()
	return Move.BaseMove.new({
		name = MoveData.UnitedStatesSmash.name,
		element = MoveData.UnitedStatesSmash.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "UnitedStatesSmashAnimation",
			accuracy = Condition.Prob.new(MoveData.UnitedStatesSmash.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.UnitedStatesSmash.power)),
		}),
	})
end

function AllMightMoves.getFullCowl()
	return Move.BaseMove.new({
		name = MoveData.FullCowl.name,
		element = MoveData.FullCowl.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "FullCowlAnimation",
			accuracy = Condition.Prob.new(MoveData.FullCowl.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				battler._fullCowlActive = true
				local speedBoost = math.floor(battler.speed * (MoveData.FullCowl.params.speedBoostPercent / 100))
				battler.speed = battler.speed + speedBoost
				Effect.registerBuff(battler, { name = "Full Cowl", desc = `Speed +{MoveData.FullCowl.params.speedBoostPercent}% ({MoveData.FullCowl.params.duration} turns)` })
				fireLog(context, `{battler.itemType}: Full Cowl! Speed +{MoveData.FullCowl.params.speedBoostPercent}%!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.FullCowl.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler._fullCowlActive = false
						battler.speed = math.max(1, battler.speed - speedBoost)
						Effect.removeBuff(battler, "Full Cowl")
						fireLog({ battle = battle }, `{battler.itemType}'s Full Cowl wears off.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function AllMightMoves.getOneForAll100()
	return Move.BaseMove.new({
		name = MoveData.OneForAll100.name,
		element = MoveData.OneForAll100.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "OneForAll100Animation",
			accuracy = Condition.Prob.new(MoveData.OneForAll100.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.OneForAll100.power)),
				Effect.DirectDamage.new(Target.Attacker.new(), Number.Exactly.new(MoveData.OneForAll100.power))
			}),
		}),
	})
end

function AllMightMoves.getUnitedSmash()
	return Move.BaseMove.new({
		name = MoveData.UnitedSmash.name,
		element = MoveData.UnitedSmash.element,
		attempt = Attempt.Cascade.new({
			Attempt.SingleAttempt.new({
				animation = "SmashAnimation",
				accuracy = Condition.Prob.new(MoveData.UnitedSmash.accuracy),
				onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.UnitedSmash.power)),
			}),
			Attempt.SingleAttempt.new({
				animation = "SmashAnimation",
				accuracy = Condition.Prob.new(MoveData.UnitedSmash.accuracy),
				onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.UnitedSmash.power)),
			}),
			Attempt.SingleAttempt.new({
				animation = "UnitedSmashAnimation",
				accuracy = Condition.Prob.new(MoveData.UnitedSmash.accuracy),
				onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.UnitedSmash.power)),
			}),
		}),
	})
end

function AllMightMoves.getFinalStand()
	return Move.BaseMove.new({
		name = MoveData.FinalStand.name,
		element = MoveData.FinalStand.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "FinalStandAnimation",
			accuracy = Condition.Prob.new(MoveData.FinalStand.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				battler._finalStandActive = true
				Effect.registerBuff(battler, { name = "Final Stand", desc = `Plus Ultra! ({MoveData.FinalStand.params.duration} turns)` })
				fireLog(context, `{battler.itemType}: I AM HERE!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.FinalStand.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler._finalStandActive = false
						Effect.removeBuff(battler, "Final Stand")
						fireLog({ battle = battle }, `{battler.itemType}'s Final Stand ends.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

return AllMightMoves
