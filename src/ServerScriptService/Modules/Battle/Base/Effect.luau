--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IEffect interface
local Effect = {}
Effect.__index = Effect

function Effect.new()
	local self = setmetatable({}, Effect)
	return self
end

function Effect:apply(context: any): ()
	error("apply() must be implemented by concrete effect")
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

-- Build a per-target sub-context. Reuses the original context when the target
-- is already the primary defender, otherwise creates a lightweight copy.
local function subContext(context: any, target: any): any
	if target == context.defender then return context end
	return {
		attacker = context.attacker,
		defender = target,
		battle = context.battle,
		move = context.move,
	}
end

-- Register an active buff on a battler for client-side UI display.
-- buffEntry: { name: string, desc: string? }
local function registerBuff(battler: any, buffEntry: { name: string, desc: string? })
	if not battler._activeBuffs then
		battler._activeBuffs = {}
	end
	-- Avoid duplicates by name
	for _, existing in battler._activeBuffs do
		if existing.name == buffEntry.name then return end
	end
	table.insert(battler._activeBuffs, buffEntry)
end

-- Remove an active buff from a battler by name.
local function removeBuff(battler: any, buffName: string)
	if not battler._activeBuffs then return end
	for i, buff in battler._activeBuffs do
		if buff.name == buffName then
			table.remove(battler._activeBuffs, i)
			return
		end
	end
end

-- Concrete Effects
local NoEffect = {}
NoEffect.__index = NoEffect
setmetatable(NoEffect, Effect)

function NoEffect.new()
	return setmetatable(Effect.new(), NoEffect)
end

function NoEffect:apply(_context: any)
	-- Do nothing
end

local Sequence = {}
Sequence.__index = Sequence
setmetatable(Sequence, Effect)

function Sequence.new(effects: { any })
	local self = setmetatable(Effect.new(), Sequence)
	self.effects = effects
	return self
end

function Sequence:apply(context: any)
	-- Check if hit was cancelled (e.g., by dodge)
	local BattleModifiers = require(script.Parent.BattleModifiers)
	if BattleModifiers.has(context, "cancelHit") then
		return -- Entire sequence cancelled
	end
	
	for _, effect in self.effects do
		effect:apply(context)
	end
end

-- Targeted Effects
local RestoreHP = {}
RestoreHP.__index = RestoreHP
setmetatable(RestoreHP, Effect)

function RestoreHP.new(target: any, amount: any)
	local self = setmetatable(Effect.new(), RestoreHP)
	self.target = target
	self.amount = amount
	return self
end

function RestoreHP:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		local ctx = subContext(context, battler)
		local healAmount = self.amount:evaluate(ctx)
		battler:heal(healAmount)
		fireLog(ctx, `{battler.itemType} restored {healAmount} HP!`, "buff")
	end)
end

local DirectDamage = {}
DirectDamage.__index = DirectDamage
setmetatable(DirectDamage, Effect)

function DirectDamage.new(target: any, amount: any)
	local self = setmetatable(Effect.new(), DirectDamage)
	self.target = target
	self.amount = amount
	return self
end

function DirectDamage:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		local ctx = subContext(context, battler)
		local percentage = self.amount:evaluate(ctx)
		local damageAmount = math.floor(battler.maxHp * (percentage / 100))
		battler:takeDamage(damageAmount)
		fireLog(ctx, `{battler.itemType} took {damageAmount} damage!`, "damage")
	end)
end

local FormulaDamage = {}
FormulaDamage.__index = FormulaDamage
setmetatable(FormulaDamage, Effect)

function FormulaDamage.new(target: any, power: any)
	local self = setmetatable(Effect.new(), FormulaDamage)
	self.target = target
	self.power = power
	return self
end

function FormulaDamage:apply(context: any)
	local BattleModifiers = require(script.Parent.BattleModifiers)
	
	-- Check if hit was cancelled (e.g., by dodge)
	if BattleModifiers.has(context, "cancelHit") then
		return -- No damage if hit was cancelled
	end
	
	local attacker = context.attacker

	table.foreach(self.target:resolve(context), function(_, defender)
		if not defender:isAlive() then return end

		local ctx = subContext(context, defender)

		if not attacker then
			error("FormulaDamage:apply() - attacker is nil")
			return
		end

		local level = attacker.level or 50
		local power = self.power:evaluate(ctx)
		local attack = attacker.attack
		local defense = defender.defense

		local defMult = BattleModifiers.getProduct(ctx, "defenseMultiplier")
		defense = math.max(1, math.floor(defense * defMult))

		-- Type Effectiveness
		local TypeChart = require(ReplicatedStorage.Shared.Classes.Constants.TypeChart)
		local moveElement = (context.move and context.move.element) or "Neutral"
		local defElement = defender.element or "Neutral"
		local typeMult = TypeChart.getMultiplier(moveElement, defElement)

		-- Pokemon Gen 5+ Formula:
		-- Damage = (((2 * Level / 5 + 2) * Power * A/D) / 50 + 2)
		local damageAmount = math.floor((((2 * level / 5 + 2) * power * attack / defense) / 50 + 2))
		
		damageAmount = math.floor(damageAmount * typeMult)

		local dmgMult = BattleModifiers.getProduct(ctx, "damageMultiplier")
		damageAmount = math.floor(damageAmount * dmgMult)

		defender:takeDamage(damageAmount)
		
		local msg = TypeChart.getEffectivenessMessage(typeMult)
		if msg then
			fireLog(ctx, msg, if typeMult > 1 then "buff" else "info")
		end
		
		fireLog(ctx, `{defender.itemType} took {damageAmount} damage!`, "damage")
	end)
end

local Paralysis = {}
Paralysis.__index = Paralysis
setmetatable(Paralysis, Effect)

function Paralysis.new(target: any)
	local self = setmetatable(Effect.new(), Paralysis)
	self.target = target
	return self
end

function Paralysis:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		if not table.find(battler.statusEffects, "Paralysis") then
			table.insert(battler.statusEffects, "Paralysis")
			context.statusApplied = "Paralyzed"
			if context.battle and context.battle.registerNewStatus then
				context.battle:registerNewStatus(battler, "Paralysis")
			end
			fireLog(context, `{battler.itemType} was paralyzed!`, "status")
		end
	end)
end

local Stun = {}
Stun.__index = Stun
setmetatable(Stun, Effect)

function Stun.new(target: any)
	local self = setmetatable(Effect.new(), Stun)
	self.target = target
	return self
end

function Stun:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		if not table.find(battler.statusEffects, "Stun") then
			table.insert(battler.statusEffects, "Stun")
			context.statusApplied = "Stunned"
			if context.battle and context.battle.registerNewStatus then
				context.battle:registerNewStatus(battler, "Stun")
			end
			fireLog(context, `{battler.itemType} was stunned!`, "status")
		end
	end)
end

local Hook = {}
Hook.__index = Hook
setmetatable(Hook, Effect)

function Hook.new(eventName: string, callback: (eventContext: any, hookOwner: any) -> ())
	local self = setmetatable(Effect.new(), Hook)
	self.eventName = eventName
	self.callback = callback
	return self
end

function Hook:apply(context: any)
	-- Hooks fire exactly once (on the next fire of eventName) then auto-unsub.
	-- For "AfterMove", this means it fires on the CURRENT action's AfterMove
	-- (which fires right after move:execute in AttackAction).
	local fired = false
	local unsub: () -> ()
	unsub = context.battle.events:subscribe(self.eventName, function(eventContext)
		if fired then return end
		fired = true
		self.callback(eventContext)
		task.defer(unsub)
	end)
end

-- ── Stagger Effect ────────────────────────────────────────────────────────────
-- Delays a character's next action by one full interval.
-- Used for specialized counter-attacks or stun abilities.

local StaggerEffect = {}
StaggerEffect.__index = StaggerEffect
setmetatable(StaggerEffect, Effect)

function StaggerEffect.new(targetBattler: any)
	local self = setmetatable(Effect.new(), StaggerEffect)
	self.targetBattler = targetBattler
	return self
end

function StaggerEffect:apply(context: any)
	local battler = self.targetBattler or context.attacker
	if battler and context.battle and context.battle.removeNextSlotFor then
		context.battle:removeNextSlotFor(battler)
	end
end

local FutureSightEffect = {}
FutureSightEffect.__index = FutureSightEffect
setmetatable(FutureSightEffect, Effect)

function FutureSightEffect.new(power: number)
	local self = setmetatable(Effect.new(), FutureSightEffect)
	self.power = power
	return self
end

function FutureSightEffect:apply(context: any)
	local battle = context.battle
	local targetBattler = context.defender
	local userBattler = context.attacker
	local turnsLeft = 2

	local unsub: () -> ()
	unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
		if data.battler ~= userBattler then return end
		turnsLeft -= 1
		if turnsLeft > 0 then return end

		if userBattler:isAlive() then
			local delayedContext = {
				attacker = userBattler,
				defender = targetBattler,
				battle = data.battle,
				move = { name = "Future Sight", element = "Psychic" }
			}

			local Target = require(ServerScriptService.Modules.Battle.Base.Target)
			local Number = require(ReplicatedStorage.Shared.Classes.Number)
			FormulaDamage.new(Target.Defender.new(), Number.Exactly.new(self.power)):apply(delayedContext)
		end

		unsub()
	end)
end

local ConditionEffect = {}
ConditionEffect.__index = ConditionEffect
setmetatable(ConditionEffect, Effect)

function ConditionEffect.new(condition: any, onPass: any, onFail: any)
	local self = setmetatable(Effect.new(), ConditionEffect)
	self.condition = condition
	self.onPass = onPass or NoEffect.new()
	self.onFail = onFail or NoEffect.new()
	return self
end

function ConditionEffect:apply(context: any)
	if self.condition:check(context) then
		self.onPass:apply(context)
	else
		self.onFail:apply(context)
	end
end

-- ── ForEachTarget ──────────────────────────────────────────────────────────────────
-- Iterates targets, applies child effect per-target with a sub-context where
-- that target is the defender. Enables per-target conditional logic declaratively.

local ForEachTarget = {}
ForEachTarget.__index = ForEachTarget
setmetatable(ForEachTarget, Effect)

function ForEachTarget.new(target: any, childEffect: any)
	local self = setmetatable(Effect.new(), ForEachTarget)
	self.target = target
	self.childEffect = childEffect
	return self
end

function ForEachTarget:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, target)
		if not target:isAlive() then return end
		local ctx = subContext(context, target)
		self.childEffect:apply(ctx)
	end)
end

-- ── Burn Status ──────────────────────────────────────────────────────────────
-- Deals 1/16 max HP per turn tick.

local Burn = {}
Burn.__index = Burn
setmetatable(Burn, Effect)

function Burn.new(target: any)
	local self = setmetatable(Effect.new(), Burn)
	self.target = target
	return self
end

function Burn:apply(context: any)
	-- Check if hit was cancelled (e.g., by dodge)
	local BattleModifiers = require(script.Parent.BattleModifiers)
	if BattleModifiers.has(context, "cancelHit") then
		return -- Don't apply burn if hit was dodged
	end
	
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		if not table.find(battler.statusEffects, "Burn") then
			table.insert(battler.statusEffects, "Burn")
			context.statusApplied = "Burned"
			if context.battle and context.battle.registerNewStatus then
				context.battle:registerNewStatus(battler, "Burn")
			end
			fireLog(context, `{battler.itemType} was burned!`, "status")
		end
	end)
end

-- ── Poison Status ────────────────────────────────────────────────────────────
-- Deals 1/8 max HP per turn tick.

local Poison = {}
Poison.__index = Poison
setmetatable(Poison, Effect)

function Poison.new(target: any)
	local self = setmetatable(Effect.new(), Poison)
	self.target = target
	return self
end

function Poison:apply(context: any)
	-- Check if hit was cancelled (e.g., by dodge)
	local BattleModifiers = require(script.Parent.BattleModifiers)
	if BattleModifiers.has(context, "cancelHit") then
		return -- Don't apply poison if hit was dodged
	end
	
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		if not table.find(battler.statusEffects, "Poison") then
			table.insert(battler.statusEffects, "Poison")
			context.statusApplied = "Poisoned"
			if context.battle and context.battle.registerNewStatus then
				context.battle:registerNewStatus(battler, "Poison")
			end
			fireLog(context, `{battler.itemType} was poisoned!`, "status")
		end
	end)
end

-- ── Scorch Status ────────────────────────────────────────────────────────────
-- Marks target to take +15% Fire damage. Applied when already Burned.

local Scorch = {}
Scorch.__index = Scorch
setmetatable(Scorch, Effect)

function Scorch.new(target: any)
	local self = setmetatable(Effect.new(), Scorch)
	self.target = target
	return self
end

function Scorch:apply(context: any)
	-- Check if hit was cancelled (e.g., by dodge)
	local BattleModifiers = require(script.Parent.BattleModifiers)
	if BattleModifiers.has(context, "cancelHit") then
		return -- Don't apply scorch if hit was dodged
	end
	
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		if not table.find(battler.statusEffects, "Scorch") then
			table.insert(battler.statusEffects, "Scorch")
			context.statusApplied = "Scorched"
			if context.battle and context.battle.registerNewStatus then
				context.battle:registerNewStatus(battler, "Scorch")
			end
			fireLog(context, `{battler.itemType} is scorched! (+15% Fire damage taken)`, "status")
		end
	end)
end

-- ── SpeedBuff ────────────────────────────────────────────────────────────────
-- Temporarily boosts a battler's speed stat by a percentage.

local SpeedBuff = {}
SpeedBuff.__index = SpeedBuff
setmetatable(SpeedBuff, Effect)

function SpeedBuff.new(target: any, percentage: number, duration: number?)
	local self = setmetatable(Effect.new(), SpeedBuff)
	self.target = target
	self.percentage = percentage
	self.duration = duration
	return self
end

function SpeedBuff:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		local boost = math.floor(battler.speed * (self.percentage / 100))
		battler.speed = battler.speed + boost
		local buffName = `Speed +{self.percentage}%`
		local durationText = if self.duration then ` ({self.duration} turns)` else ""
		registerBuff(battler, { name = buffName, desc = `Speed +{self.percentage}%{durationText}`, turnsRemaining = self.duration })
		fireLog(context, `{battler.itemType} Speed +{self.percentage}%!{durationText}`, "buff")

		if self.duration and context.battle then
			local battle = context.battle
			local turnsLeft = self.duration
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				if not battler:isAlive() then unsub() return end
				turnsLeft -= 1
				for _, buff in battler._activeBuffs or {} do
					if buff.name == buffName then
						buff.turnsRemaining = turnsLeft
						buff.desc = `Speed +{self.percentage}% ({turnsLeft} turns)`
						break
					end
				end
				if turnsLeft <= 0 then
					battler.speed = math.max(1, battler.speed - boost)
					removeBuff(battler, buffName)
					fireLog({ battle = battle }, `{battler.itemType}'s Speed buff faded.`, "info")
					unsub()
				end
			end)
		end
	end)
end

-- ── AttackBuff ───────────────────────────────────────────────────────────────

local AttackBuff = {}
AttackBuff.__index = AttackBuff
setmetatable(AttackBuff, Effect)

function AttackBuff.new(target: any, percentage: number, duration: number?)
	local self = setmetatable(Effect.new(), AttackBuff)
	self.target = target
	self.percentage = percentage
	self.duration = duration
	return self
end

function AttackBuff:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		local boost = math.floor(battler.attack * (self.percentage / 100))
		battler.attack = battler.attack + boost
		local buffName = `Attack +{self.percentage}%`
		local durationText = if self.duration then ` ({self.duration} turns)` else ""
		registerBuff(battler, { name = buffName, desc = `Attack +{self.percentage}%{durationText}`, turnsRemaining = self.duration })
		fireLog(context, `{battler.itemType} Attack +{self.percentage}%!{durationText}`, "buff")

		if self.duration and context.battle then
			local battle = context.battle
			local turnsLeft = self.duration
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				if not battler:isAlive() then unsub() return end
				turnsLeft -= 1
				for _, buff in battler._activeBuffs or {} do
					if buff.name == buffName then
						buff.turnsRemaining = turnsLeft
						buff.desc = `Attack +{self.percentage}% ({turnsLeft} turns)`
						break
					end
				end
				if turnsLeft <= 0 then
					battler.attack = math.max(1, battler.attack - boost)
					removeBuff(battler, buffName)
					fireLog({ battle = battle }, `{battler.itemType}'s Attack buff faded.`, "info")
					unsub()
				end
			end)
		end
	end)
end

-- ── DefenseBuff ──────────────────────────────────────────────────────────────

local DefenseBuff = {}
DefenseBuff.__index = DefenseBuff
setmetatable(DefenseBuff, Effect)

function DefenseBuff.new(target: any, percentage: number, duration: number?)
	local self = setmetatable(Effect.new(), DefenseBuff)
	self.target = target
	self.percentage = percentage
	self.duration = duration
	return self
end

function DefenseBuff:apply(context: any)
	table.foreach(self.target:resolve(context), function(_, battler)
		if not battler:isAlive() then return end
		local boost = math.floor(battler.defense * (self.percentage / 100))
		battler.defense = battler.defense + boost
		local buffName = `Defense +{self.percentage}%`
		local durationText = if self.duration then ` ({self.duration} turns)` else ""
		registerBuff(battler, { name = buffName, desc = `Defense +{self.percentage}%{durationText}`, turnsRemaining = self.duration })
		fireLog(context, `{battler.itemType} Defense +{self.percentage}%!{durationText}`, "buff")

		if self.duration and context.battle then
			local battle = context.battle
			local turnsLeft = self.duration
			local unsub: () -> ()
			unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
				if data.battler ~= battler then return end
				if not battler:isAlive() then unsub() return end
				turnsLeft -= 1
				for _, buff in battler._activeBuffs or {} do
					if buff.name == buffName then
						buff.turnsRemaining = turnsLeft
						buff.desc = `Defense +{self.percentage}% ({turnsLeft} turns)`
						break
					end
				end
				if turnsLeft <= 0 then
					battler.defense = math.max(1, battler.defense - boost)
					removeBuff(battler, buffName)
					fireLog({ battle = battle }, `{battler.itemType}'s Defense buff faded.`, "info")
					unsub()
				end
			end)
		end
	end)
end

return {
	NoEffect = NoEffect,
	Sequence = Sequence,
	RestoreHP = RestoreHP,
	DirectDamage = DirectDamage,
	FormulaDamage = FormulaDamage,
	Paralysis = Paralysis,
	Stun = Stun,
	Burn = Burn,
	Poison = Poison,
	Scorch = Scorch,
	Hook = Hook,
	Stagger = StaggerEffect,
	FutureSight = FutureSightEffect,
	ConditionEffect = ConditionEffect,
	ForEachTarget = ForEachTarget,
	SpeedBuff = SpeedBuff,
	AttackBuff = AttackBuff,
	DefenseBuff = DefenseBuff,
	-- Utility functions for custom buff tracking
	registerBuff = registerBuff,
	removeBuff = removeBuff,
}
