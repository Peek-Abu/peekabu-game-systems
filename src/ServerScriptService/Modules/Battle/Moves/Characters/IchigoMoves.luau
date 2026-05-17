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

local IchigoMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function IchigoMoves.getGetsugaTensho()
	return Move.BaseMove.new({
		name = MoveData.GetsugaTensho.name,
		element = MoveData.GetsugaTensho.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "GetsugaTenshoAnimation",
			accuracy = Condition.Prob.new(MoveData.GetsugaTensho.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.GetsugaTensho.power)),
		}),
	})
end

function IchigoMoves.getBankaiSpeed()
	return Move.BaseMove.new({
		name = MoveData.BankaiSpeed.name,
		element = MoveData.BankaiSpeed.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "BankaiAnimation",
			accuracy = Condition.Prob.new(MoveData.BankaiSpeed.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				battler._currentForm = "Bankai"
				Effect.registerBuff(battler, { name = "Bankai", desc = `Bankai form ({MoveData.BankaiSpeed.params.duration} turns)` })
				fireLog(context, `{battler.itemType}: Bankai!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.BankaiSpeed.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler._currentForm = nil
						Effect.removeBuff(battler, "Bankai")
						fireLog({ battle = battle }, `{battler.itemType}'s Bankai ends.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function IchigoMoves.getMusgetsu()
	return Move.BaseMove.new({
		name = MoveData.Mugetsu.name,
		element = MoveData.Mugetsu.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "MusgetsuAnimation",
			accuracy = Condition.Prob.new(MoveData.Mugetsu.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Mugetsu.power)),
				Effect.DirectDamage.new(Target.Attacker.new(), Number.Exactly.new(MoveData.Mugetsu.power))
			}),
		}),
	})
end

function IchigoMoves.getVastoLorde()
	return Move.BaseMove.new({
		name = MoveData.VastoLorde.name,
		element = MoveData.VastoLorde.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "VastoLordeAnimation",
			accuracy = Condition.Prob.new(MoveData.VastoLorde.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				battler._currentForm = "Hollow"
				battler._vastoLordeLifesteal = true
				Effect.registerBuff(battler, { name = "Vasto Lorde", desc = `Hollow form: lifesteal active ({MoveData.VastoLorde.params.duration} turns)` })
				fireLog(context, `{battler.itemType} transforms into Vasto Lorde!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.VastoLorde.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler._currentForm = nil
						battler._vastoLordeLifesteal = false
						Effect.removeBuff(battler, "Vasto Lorde")
						fireLog({ battle = battle }, `{battler.itemType}'s Vasto Lorde form fades.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function IchigoMoves.getGranRey()
	return Move.BaseMove.new({
		name = MoveData.GranRey.name,
		element = MoveData.GranRey.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "GranReyAnimation",
			accuracy = Condition.Prob.new(MoveData.GranRey.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.GranRey.power)),
		}),
	})
end

function IchigoMoves.getTrueZangetsu()
	return Move.BaseMove.new({
		name = MoveData.TrueZangetsu.name,
		element = MoveData.TrueZangetsu.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "TrueZangetsuAnimation",
			accuracy = Condition.Prob.new(MoveData.TrueZangetsu.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.TrueZangetsu.power)),
		}),
	})
end

return IchigoMoves
