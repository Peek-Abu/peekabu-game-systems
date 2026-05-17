--!strict
--[=[
	Naruto Moves - Naruto
	
	@class NarutoMoves
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

local NarutoMoves = {}

local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

function NarutoMoves.getRasengan()
	local attempt = Attempt.SingleAttempt.new({
		animation = "RasenganAnimation",
		accuracy = Condition.Prob.new(95),
		onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(80)),
	})
	return Move.BaseMove.new({
		name = MoveData.Rasengan.name,
		element = MoveData.Rasengan.element,
		attempt = attempt,
	})
end

function NarutoMoves.getShadowClone()
	local attempt = Attempt.SingleAttempt.new({
		animation = "ShadowCloneAnimation",
		accuracy = Condition.Prob.new(MoveData.ShadowClone.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			local battler = context.attacker
			battler._activeClones = math.min((battler._activeClones or 0) + MoveData.ShadowClone.params.cloneGain, MoveData.ShadowClone.params.maxClones)
			Effect.removeBuff(battler, "Shadow Clones")
			Effect.registerBuff(battler, { name = "Shadow Clones", desc = `Active clones: {battler._activeClones}/{MoveData.ShadowClone.params.maxClones}` })
			fireLog(context, `{battler.itemType} creates a shadow clone! Active clones: {battler._activeClones}`, "buff")
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.ShadowClone.name,
		element = MoveData.ShadowClone.element,
		target = Target.Self.new(),
		attempt = attempt,
	})
end

function NarutoMoves.getTailedBeastBomb()
	local attempt = Attempt.SingleAttempt.new({
		animation = "TailedBeastBombAnimation",
		accuracy = Condition.Prob.new(MoveData.TailedBeastBomb.accuracy),
		onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.TailedBeastBomb.power)),
	})
	return Move.BaseMove.new({
		name = MoveData.TailedBeastBomb.name,
		element = MoveData.TailedBeastBomb.element,
		attempt = attempt,
	})
end

function NarutoMoves.getSageMode()
	local attempt = Attempt.SingleAttempt.new({
		animation = "SageModeAnimation",
		accuracy = Condition.Prob.new(MoveData.SageMode.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			local battler = context.attacker
			battler._sageModeActive = true
			local speedBoost = math.floor(battler.speed * (MoveData.SageMode.params.speedBoostPercent / 100))
			battler.speed = battler.speed + speedBoost
			Effect.registerBuff(battler, { name = "Sage Mode", desc = `Speed +{MoveData.SageMode.params.speedBoostPercent}% ({MoveData.SageMode.params.duration} turns)` })
			fireLog(context, `{battler.itemType} enters Sage Mode! Speed +{MoveData.SageMode.params.speedBoostPercent}%!`, "buff")

			local battle = context.battle
			local turnsLeft = MoveData.SageMode.params.duration
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				if not battler:isAlive() then unsub() return end
				turnsLeft -= 1
				if turnsLeft <= 0 then
					battler._sageModeActive = false
					battler.speed = math.max(1, battler.speed - speedBoost)
					Effect.removeBuff(battler, "Sage Mode")
					fireLog({ battle = battle }, `{battler.itemType}'s Sage Mode ends.`, "info")
					unsub()
				end
			end)
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.SageMode.name,
		element = MoveData.SageMode.element,
		target = Target.Self.new(),
		attempt = attempt,
	})
end

function NarutoMoves.getRasenshuriken()
	local attempt = Attempt.SingleAttempt.new({
		animation = "RasenshurikenAnimation",
		accuracy = Condition.Prob.new(MoveData.Rasenshuriken.accuracy),
		onHit = Effect.Sequence.new({
			Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Rasenshuriken.power)),
			Effect.Hook.new("AfterMove", function(context)
				local target = context.defender
				target._rasenshurikenBleed = MoveData.Rasenshuriken.params.bleedDuration
				fireLog(context, `{target.itemType} is bleeding from Rasenshuriken!`, "status")
			end)
		}),
	})
	return Move.BaseMove.new({
		name = MoveData.Rasenshuriken.name,
		element = MoveData.Rasenshuriken.element,
		attempt = attempt,
	})
end

function NarutoMoves.getBaryonMode()
	local attempt = Attempt.SingleAttempt.new({
		animation = "BaryonModeAnimation",
		accuracy = Condition.Prob.new(MoveData.BaryonMode.accuracy),
		onHit = Effect.Hook.new("AfterMove", function(context)
			local battler = context.attacker
			battler._baryonModeActive = true
			Effect.registerBuff(battler, { name = "Baryon Mode", desc = `Immortal ({MoveData.BaryonMode.params.duration} turns)` })
			fireLog(context, `{battler.itemType} enters Baryon Mode! Immortal for {MoveData.BaryonMode.params.duration} turns!`, "buff")
			
			local battle = context.battle
			local turnCount = 0
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				turnCount = turnCount + 1
				if turnCount >= MoveData.BaryonMode.params.duration then
					battler._baryonModeActive = false
					Effect.removeBuff(battler, "Baryon Mode")
					fireLog({ battle = battle }, `{battler.itemType}'s Baryon Mode ends.`, "info")
					unsub()
				end
			end)
		end),
	})
	return Move.BaseMove.new({
		name = MoveData.BaryonMode.name,
		element = MoveData.BaryonMode.element,
		target = Target.Self.new(),
		attempt = attempt,
	})
end

return NarutoMoves
