--!strict
--[=[
	Goku Moves - Dragon Ball Z
	
	Signature moves for Goku including Kamehameha, Spirit Bomb, Super Saiyan,
	Instant Transmission, Dragon Fist, and Ultra Instinct.
	
	@class GokuMoves
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

local GokuMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function GokuMoves.getKamehameha()
	local attempt = Attempt.SingleAttempt.new({
		animation = "KamehamehaAnimation",
		accuracy = Condition.Prob.new(95),
		onHit = Effect.Sequence.new({
			Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(85))
		}),
	})
	return Move.BaseMove.new({
		name = MoveData.Kamehameha.name,
		element = MoveData.Kamehameha.element,
		attempt = attempt,
	})
end

function GokuMoves.getSpiritBomb()
	local attempt = Attempt.SingleAttempt.new({
		animation = "SpiritBombAnimation",
		accuracy = Condition.Prob.new(MoveData.Kamehameha.accuracy),
		onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Kamehameha.power)),
	})
	return Move.BaseMove.new({
		name = MoveData.SpiritBomb.name,
		element = MoveData.SpiritBomb.element,
		attempt = attempt,
	})
end

function GokuMoves.getSuperSaiyan()
	local attempt = Attempt.SingleAttempt.new({
		animation = "SuperSaiyanAnimation",
		accuracy = Condition.Prob.new(MoveData.SpiritBomb.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			local battler = context.attacker
			battler._superSaiyanActive = true
			battler._originalAttack = battler.attack
			battler.attack = math.floor(battler.attack * MoveData.SuperSaiyan.params.attackMultiplier)
			Effect.registerBuff(battler, { name = "Super Saiyan", desc = `Attack x{MoveData.SuperSaiyan.params.attackMultiplier} ({MoveData.SuperSaiyan.params.duration} turns)` })
			fireLog(context, `{battler.itemType} transforms into Super Saiyan! Attack x{MoveData.SuperSaiyan.params.attackMultiplier}!`, "buff")
			
			local battle = context.battle
			local turnCount = 0
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				turnCount = turnCount + 1
				if turnCount >= MoveData.SuperSaiyan.params.duration then
					battler.attack = battler._originalAttack
					battler._superSaiyanActive = false
					Effect.removeBuff(battler, "Super Saiyan")
					fireLog({ battle = battle }, `{battler.itemType}'s Super Saiyan fades.`, "info")
					unsub()
				end
			end)
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.SuperSaiyan.name,
		element = MoveData.SuperSaiyan.element,
		target = Target.Self.new(),
		attempt = attempt,
	})
end

function GokuMoves.getInstantTransmission()
	local attempt = Attempt.SingleAttempt.new({
		animation = "InstantTransmissionAnimation",
		accuracy = Condition.Prob.new(MoveData.SuperSaiyan.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			context.attacker._instantTransmissionActive = true
			Effect.registerBuff(context.attacker, { name = "Instant Transmission", desc = "Next attack is guaranteed to hit" })
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.InstantTransmission.name,
		element = MoveData.InstantTransmission.element,
		target = Target.Self.new(),
		attempt = attempt,
	})
end

function GokuMoves.getDragonFist()
	local attempt = Attempt.Cascade.new({
		Attempt.SingleAttempt.new({
			animation = "PunchAnimation",
			accuracy = Condition.Prob.new(MoveData.DragonFist.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.DragonFist.power)),
		}),
		Attempt.SingleAttempt.new({
			animation = "PunchAnimation",
			accuracy = Condition.Prob.new(MoveData.DragonFist.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.DragonFist.power)),
		}),
		Attempt.SingleAttempt.new({
			animation = "DragonFistAnimation",
			accuracy = Condition.Prob.new(MoveData.DragonFist.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.DragonFist.power)),
		}),
	})
	return Move.BaseMove.new({
		name = MoveData.DragonFist.name,
		element = MoveData.DragonFist.element,
		attempt = attempt,
	})
end

function GokuMoves.getUltraInstinct()
	local attempt = Attempt.SingleAttempt.new({
		animation = "UltraInstinctAnimation",
		accuracy = Condition.Prob.new(MoveData.DragonFist.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			local battler = context.attacker
			battler._ultraInstinctActive = true
			Effect.registerBuff(battler, { name = "Ultra Instinct", desc = `50% auto-evade ({MoveData.UltraInstinct.params.duration} turns)` })
			fireLog(context, `{battler.itemType} enters Ultra Instinct! 50% auto-evade!`, "buff")
			
			local battle = context.battle
			local turnCount = 0
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				turnCount = turnCount + 1
				if turnCount >= MoveData.UltraInstinct.params.duration then
					battler._ultraInstinctActive = false
					Effect.removeBuff(battler, "Ultra Instinct")
					fireLog({ battle = battle }, `{battler.itemType}'s Ultra Instinct ends.`, "info")
					unsub()
				end
			end)
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.UltraInstinct.name,
		element = MoveData.UltraInstinct.element,
		target = Target.Self.new(),
		attempt = attempt,
	})
end

return GokuMoves
