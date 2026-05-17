--!strict
--[=[
	Natsu Moves - Dragon Slayer fire-based moveset.
	
	Core moves:
	1. FireDragonIronFist  - Single-target melee, 40% Burn chance
	2. FireDragonRoar      - AoE fire attack, 30% Burn, applies Scorch if already Burned
	3. FlamesOfEmotion     - Self-buff (+10% Atk/Spd), tiered Fire Dragon Stacks gain
	4. DragonsFeast         - Feast on Fire Dragon Stacks for heal + power amp
	
	@class NatsuMoves
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

local NatsuMoves = {}

-- Helper: fire a BattleLog event if a battle context is available
local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

--- 1) Fire Dragon's Iron Fist — bread-and-butter single-target melee
function NatsuMoves.getFireDragonIronFist()
	return Move.BaseMove.new({
		name = MoveData.FireDragonIronFist.name,
		element = MoveData.FireDragonIronFist.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "FireDragonIronFistAnimation",
			accuracy = Condition.Prob.new(MoveData.FireDragonIronFist.accuracy),
			onHit = Effect.Sequence.new({
				-- 1.0x base power, Fire Dragon Stacks bonus applied via passive modifier
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.FireDragonIronFist.power)),
				-- 40% chance to Burn
				Effect.ConditionEffect.new(
					Condition.Prob.new(MoveData.FireDragonIronFist.params.burnChance, "Burn"),
					Effect.Burn.new(Target.Defender.new())
				),
			}),
		}),
		reactions = {
			{ type = "Parry", time = 1.1, duration = 0.3 },
			{ type = "Dodge", time = 1.1, duration = 0.5 },
		},
		-- attackerReactions = {
		-- 	{ type = "Timing", time = 0.3, duration = 0.4, bonusMultiplier = 1.25 },
		-- },
	})
end

--- 2) Fire Dragon's Roar — AoE fire attack, Burn + Scorch if already Burned
function NatsuMoves.getFireDragonRoar()
	return Move.BaseMove.new({
		name = MoveData.FireDragonRoar.name,
		element = MoveData.FireDragonRoar.element,
		target = Target.AllEnemies.new(),
		cooldown = 2,
		attempt = Attempt.SingleAttempt.new({
			animation = "FireDragonRoarAnimation",
			accuracy = Condition.Prob.new(MoveData.FireDragonRoar.accuracy),
			onHit = Effect.Sequence.new({
				-- AoE damage via targeting system
				Effect.FormulaDamage.new(Target.AllEnemies.new(), Number.Exactly.new(MoveData.FireDragonRoar.power)),
				-- Per-target Burn/Scorch (each enemy rolls independently)
				Effect.ForEachTarget.new(Target.AllEnemies.new(), Effect.Sequence.new({
					-- 30% Burn chance per target
					Effect.ConditionEffect.new(
						Condition.Prob.new(MoveData.FireDragonRoar.params.burnChance, "Burn"),
						Effect.Burn.new(Target.Defender.new())
					),
					-- If already Burned (or just got Burned above), apply Scorch
					Effect.ConditionEffect.new(
						Condition.ForTarget.new(Target.Defender.new(), Condition.HasStatus.new("Burn")),
						Effect.Scorch.new(Target.Defender.new())
					),
				})),
			}),
		}),
		reactions = {
			-- { type = "Parry", time = 1.4, duration = 0.4 },
			{ type = "Dodge", time = 0.55, duration = 0.3 },
		},
	})
end

function NatsuMoves.getFlamesOfEmotion()
	return Move.BaseMove.new({
		name = MoveData.FlamesOfEmotion.name,
		element = MoveData.FlamesOfEmotion.element,
		target = Target.Self.new(),
		cooldown = 3,
		attempt = Attempt.SingleAttempt.new({
			animation = "FlamesOfEmotionAnimation",
			accuracy = Condition.Prob.new(MoveData.FlamesOfEmotion.accuracy),
			onHit = Effect.Sequence.new({
				-- +10% Attack
				Effect.AttackBuff.new(Target.Self.new(), MoveData.FlamesOfEmotion.params.buffPercent, MoveData.FlamesOfEmotion.params.duration),
				Effect.SpeedBuff.new(Target.Self.new(), MoveData.FlamesOfEmotion.params.buffPercent, MoveData.FlamesOfEmotion.params.duration),
				Effect.Hook.new("AfterMove", function(context)
					local battler = context.attacker
					local hpPercent = (battler.currentHp / battler.maxHp) * 100
					
					-- Tiered gain: 1 base, +1 if <50%, +1 if <25% (total up to 3)
					local gain = 1
					if hpPercent < 25 then
						gain = 3
					elseif hpPercent < 50 then
						gain = 2
					end

					battler._fireDragonStacks = math.min(MoveData.FlamesOfEmotion.params.maxStacks, (battler._fireDragonStacks or 0) + gain)
					Effect.removeBuff(battler, "Fire Dragon Stacks")
					Effect.registerBuff(battler, { 
						name = "Fire Dragon Stacks", 
						desc = `Fire Dragon Stacks: {battler._fireDragonStacks}/{MoveData.FlamesOfEmotion.params.maxStacks} (+{battler._fireDragonStacks * 5}% Power, +{battler._fireDragonStacks * 3}% Res, +{battler._fireDragonStacks * 5}% Burn chance)` 
					})
					fireLog(context, `{battler.itemType} built draconic power! Stacks: {battler._fireDragonStacks} (+{gain})`, "passive")
				end),
			}),
		}),
	})
end

--- 4) Dragon's Feast — feast on Fire Dragon Stacks for heal + status cleanse
function NatsuMoves.getDragonsFeast()
	return Move.BaseMove.new({
		name = MoveData.DragonsFeast.name,
		element = MoveData.DragonsFeast.element,
		target = Target.Self.new(),
		cooldown = 3,
		attempt = Attempt.SingleAttempt.new({
			animation = "DragonsFeastAnimation",
			accuracy = Condition.Prob.new(MoveData.DragonsFeast.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				local stacks = battler._fireDragonStacks or 0

				if stacks == 0 then
					fireLog(context, `{battler.itemType} has no stacks to feast upon!`, "info")
					return
				end

				-- Heal 5% maxHP per stack
				local healPercent = (MoveData.DragonsFeast.params.healPercentPerStack / 100) * stacks
				local healAmount = math.floor(battler.maxHp * healPercent)
				battler:heal(healAmount)

				battler._dragonsFeastBonus = 1 + ((MoveData.DragonsFeast.params.ampPercentPerStack / 100) * stacks)

				fireLog(context, `{battler.itemType} feasted on {stacks} stacks! Healed {healAmount} HP, next Fire technique +{stacks * MoveData.DragonsFeast.params.ampPercentPerStack}% power`, "passive")

				-- Status cleanse (threshold >= 3)
				if stacks >= 3 then
					local negativeStatuses = { "Burn", "Poison", "Scorch", "Paralysis" }
					local removedCount = 0
					for _, status in negativeStatuses do
						local idx = table.find(battler.statusEffects, status)
						if idx then
							table.remove(battler.statusEffects, idx)
							if battler._statusDurations then battler._statusDurations[status] = nil end
							if battler._registeredStatuses then battler._registeredStatuses[status] = nil end
							removedCount += 1
						end
					end
					if removedCount > 0 then
						fireLog(context, `{battler.itemType} consumed his negative statuses through the feast!`, "status")
					end
				end

				-- Reset stacks
				battler._fireDragonStacks = 0
				Effect.removeBuff(battler, "Fire Dragon Stacks")
				Effect.registerBuff(battler, { name = "Fire Dragon's Feast", desc = `Next Fire / Beast / Brawler technique +{stacks * MoveData.DragonsFeast.params.ampPercentPerStack}% power` })
			end),
		}),
	})
end

return NatsuMoves
