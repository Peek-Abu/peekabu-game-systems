--!strict
--[=[
	Luffy Moves - Rubber-powered brawling moveset.
	
	Core moves:
	1. GumPistol   - Single-target melee, 100% Accuracy, Blunt damage.
	2. GumBazooka  - Heavier hit + 45% Stagger chance (delays enemy turn).
	3. GumBell     - Headbutt + 45% Stun chance (guaranteed skip turn).
	4. GumBalloon  - Defensive stance, 75% Blunt reduction for 2 turns.
	
	Specialized moves:
	- Gear2        - Speed boost.
	- Gear4        - Attack boost + knockback immunity.
	- Gear5        - Sun God awakening.
	- BajrangGun   - Ultimate Gear 5 attack.
	
	@class LuffyMoves
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
local BattleModifiers = require(ServerScriptService.Modules.Battle.Base.BattleModifiers)

local LuffyMoves = {}

-- Helper: fire a BattleLog event
local function fireLog(context: any, message: string, category: string?)
	if context.battle and context.battle.events then
		context.battle.events:fire("BattleLog", {
			message = message,
			category = category or "info",
		})
	end
end

--- 1) Gum-Gum Pistol — Simple poke
function LuffyMoves.getGumPistol()
	return Move.BaseMove.new({
		name = MoveData.GumPistol.name,
		element = MoveData.GumPistol.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "GumPistolAnimation",
			accuracy = Condition.Prob.new(MoveData.GumPistol.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.GumPistol.power)),
		}),
		reactions = {
			{ type = "Parry", time = 1.0, duration = 0.3 },
			{ type = "Dodge", time = 1.0, duration = 0.5 },
		},
	})
end

--- 2) Gum-Gum Bazooka — Heavier hit + Stagger
function LuffyMoves.getGumBazooka()
	return Move.BaseMove.new({
		name = MoveData.GumBazooka.name,
		element = MoveData.GumBazooka.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "GumBazookaAnimation",
			accuracy = Condition.Prob.new(MoveData.GumBazooka.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.GumBazooka.power)),
				Effect.ConditionEffect.new(
					Condition.Prob.new(MoveData.GumBazooka.params.staggerChance, "Stagger"),
					Effect.Stagger.new(Target.Defender.new())
				),
			}),
		}),
		reactions = {
			{ type = "Parry", time = 1.2, duration = 0.4 },
			{ type = "Dodge", time = 1.2, duration = 0.4 },
		},
	})
end

--- 3) Gum-Gum Bell — Headbutt + Stun
function LuffyMoves.getGumBell()
	return Move.BaseMove.new({
		name = MoveData.GumBell.name,
		element = MoveData.GumBell.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "GumBellAnimation",
			accuracy = Condition.Prob.new(MoveData.GumBell.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.GumBell.power)),
				Effect.ConditionEffect.new(
					Condition.Prob.new(MoveData.GumBell.params.stunChance, "Stun"),
					Effect.Stun.new(Target.Defender.new())
				),
			}),
		}),
		reactions = {
			{ type = "Parry", time = 0.8, duration = 0.3 },
			{ type = "Dodge", time = 0.8, duration = 0.3 },
		},
	})
end

--- 4) Gum-Gum Balloon — Defensive stance
function LuffyMoves.getGumBalloon()
	local duration = MoveData.GumBalloon.params.duration
	local reduction = MoveData.GumBalloon.params.bluntReduction

	return Move.BaseMove.new({
		name = MoveData.GumBalloon.name,
		element = MoveData.GumBalloon.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "GumBalloonAnimation",
			accuracy = Condition.Prob.new(MoveData.GumBalloon.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				local buffName = "Gum Balloon"
				
				Effect.registerBuff(battler, { 
					name = buffName, 
					desc = `Gum-Gum Balloon: Reduces Blunt damage by {reduction * 100}% ({duration} turns)` 
				})
				
				fireLog(context, `{battler.itemType} inflates into a balloon!`, "buff")

				local unsub: () -> ()
				unsub = context.battle.events:subscribe("BeforeHit", function(hitContext)
					if hitContext.defender ~= battler then return end
					if not battler:isAlive() then unsub() return end
					
					-- Check if the move is Blunt
					if hitContext.move and hitContext.move.damageSubType == "Blunt" then
						BattleModifiers.push(hitContext, "damageMultiplier", 1 - reduction, buffName)
						fireLog(hitContext, `{battler.itemType}'s rubber body bounces the impact!`, "passive")
					end
				end)

				-- Handle expiry
				local turnsLeft = duration
				local unsubExpiry: () -> ()
				unsubExpiry = context.battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						Effect.removeBuff(battler, buffName)
						unsub() -- Stop the damage reduction
						unsubExpiry() -- Stop tracking expiry
						fireLog({ battle = context.battle }, `{battler.itemType} deflates.`, "info")
					end
				end)
			end),
		}),
	})
end

function LuffyMoves.getGear2()
	return Move.BaseMove.new({
		name = MoveData.Gear2.name,
		element = MoveData.Gear2.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "Gear2Animation",
			accuracy = Condition.Prob.new(MoveData.Gear2.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				local speedBoost = math.floor(battler.speed * (MoveData.Gear2.params.speedBoostPercent / 100))
				battler.speed = battler.speed + speedBoost
				Effect.registerBuff(battler, { name = "Gear Second", desc = `Speed +{MoveData.Gear2.params.speedBoostPercent}% ({MoveData.Gear2.params.duration} turns)` })
				fireLog(context, `{battler.itemType}: Gear Second! Speed +{MoveData.Gear2.params.speedBoostPercent}%!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.Gear2.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler.speed = math.max(1, battler.speed - speedBoost)
						Effect.removeBuff(battler, "Gear Second")
						fireLog({ battle = battle }, `{battler.itemType}'s Gear Second wears off.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function LuffyMoves.getGear4()
	return Move.BaseMove.new({
		name = MoveData.Gear4.name,
		element = MoveData.Gear4.element,
		target = Target.Self.new(),
		attempt = Attempt.SingleAttempt.new({
			animation = "Gear4Animation",
			accuracy = Condition.Prob.new(MoveData.Gear4.accuracy),
			onHit = Effect.Hook.new("AfterMove", function(context)
				local battler = context.attacker
				battler._knockbackImmune = true
				local atkBoost = math.floor(battler.attack * (MoveData.Gear4.params.atkBoostPercent / 100))
				battler.attack = battler.attack + atkBoost
				Effect.registerBuff(battler, { name = "Gear Fourth", desc = `Attack +{MoveData.Gear4.params.atkBoostPercent}%, knockback immune ({MoveData.Gear4.params.duration} turns)` })
				fireLog(context, `{battler.itemType}: Gear Fourth! Attack +{MoveData.Gear4.params.atkBoostPercent}%!`, "buff")

				local battle = context.battle
				local turnsLeft = MoveData.Gear4.params.duration
				local unsub: () -> ()
				unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
					if data.battler ~= battler then return end
					if not battler:isAlive() then unsub() return end
					turnsLeft -= 1
					if turnsLeft <= 0 then
						battler._knockbackImmune = false
						battler.attack = math.max(1, battler.attack - atkBoost)
						Effect.removeBuff(battler, "Gear Fourth")
						fireLog({ battle = battle }, `{battler.itemType}'s Gear Fourth wears off.`, "info")
						unsub()
					end
				end)
			end),
		}),
	})
end

function LuffyMoves.getConquerorHaki()
	return Move.BaseMove.new({
		name = MoveData.ConquerorHaki.name,
		element = MoveData.ConquerorHaki.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "ConquerorHakiAnimation",
			accuracy = Condition.Prob.new(MoveData.ConquerorHaki.accuracy),
			onHit = Effect.Sequence.new({
				Effect.Stun.new(Target.Defender.new()),
				Effect.Hook.new("AfterMove", function(context)
					fireLog(context, `{context.defender.itemType} is intimidated by Conqueror's Haki!`, "status")
				end),
			}),
		}),
	})
end

function LuffyMoves.getGear5()
	return Move.BaseMove.new({
		name = MoveData.Gear5.name,
		element = MoveData.Gear5.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "Gear5Animation",
			accuracy = Condition.Prob.new(MoveData.Gear5.accuracy),
			onHit = Effect.Sequence.new({
				Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.Gear5.power)),
				Effect.Hook.new("AfterMove", function(context)
					local battler = context.attacker
					Effect.registerBuff(battler, { name = "Gear Fifth", desc = `Nika awakening ({MoveData.Gear5.params.duration} turns)` })
					fireLog(context, `{battler.itemType}: Gear Fifth!`, "buff")

					local battle = context.battle
					local turnsLeft = MoveData.Gear5.params.duration
					local unsub: () -> ()
					unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
						if data.battler ~= battler then return end
						if not battler:isAlive() then unsub() return end
						turnsLeft -= 1
						if turnsLeft <= 0 then
							Effect.removeBuff(battler, "Gear Fifth")
							fireLog({ battle = battle }, `{battler.itemType}'s Gear Fifth ends.`, "info")
							unsub()
						end
					end)
				end)
			}),
		}),
	})
end

function LuffyMoves.getBajrangGun()
	return Move.BaseMove.new({
		name = MoveData.BajrangGun.name,
		element = MoveData.BajrangGun.element,
		attempt = Attempt.SingleAttempt.new({
			animation = "BajrangGunAnimation",
			accuracy = Condition.Prob.new(MoveData.BajrangGun.accuracy),
			onHit = Effect.FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(MoveData.BajrangGun.power)),
		}),
	})
end

return LuffyMoves
