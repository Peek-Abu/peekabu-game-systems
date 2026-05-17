--!strict
local Effect = require(script.Parent.Effect)
local BattleModifiers = require(script.Parent.BattleModifiers)

-- IAttempt interface
local Attempt = {}
Attempt.__index = Attempt

function Attempt.new()
	local self = setmetatable({}, Attempt)
	return self
end

function Attempt:execute(context: any): boolean
	error("execute() must be implemented by concrete attempt")
end

-- Concrete Attempts
local SingleAttempt = {}
SingleAttempt.__index = SingleAttempt
setmetatable(SingleAttempt, Attempt)

function SingleAttempt.new(config: {
	animation: string?,
	accuracy: any, -- ICondition
	onHit: any, -- IEffect
	onMiss: any?, -- IEffect
	after: any?, -- IEffect
})
	local self = setmetatable(Attempt.new(), SingleAttempt)
	self.animation = config.animation
	self.accuracy = config.accuracy
	self.onHit = config.onHit
	self.onMiss = config.onMiss or Effect.NoEffect.new()
	self.after = config.after or Effect.NoEffect.new()
	return self
end

function SingleAttempt:execute(context: any): boolean
	-- context._modifiers = nil
	context.battle.events:fire("BeforeAccuracyCheck", context)
	if context.cancelled then
		return false
	end

	local hit = false
	-- accuracyOverride from passives (e.g. "never miss") bypasses the roll
	local forceHit = BattleModifiers.getFirst(context, "accuracyOverride", nil)
	local accuracyResult = forceHit ~= nil and forceHit or self.accuracy:check(context)

	if accuracyResult then
		context.hit = true
		context.battle.events:fire("BeforeHit", context)
		if context.cancelled or BattleModifiers.has(context, "cancelHit") then
			return false
		end

		local hpBefore = context.defender and context.defender.currentHp or 0
		self.onHit:apply(context)
		local hpAfter = context.defender and context.defender.currentHp or 0
		context.damage = math.max(0, hpBefore - hpAfter)
		hit = true

		-- Fire AfterHit for passive hooks (OnHit, OnDamaged, OnKill)
		context.battle.events:fire("AfterHit", context)
	else
		context.hit = false
		self.onMiss:apply(context)
		context.battle.events:fire("BattleLog", {
			message = "Attack missed!",
			category = "action",
		})
	end

	self.after:apply(context)
	return hit
end

local Cascade = {}
Cascade.__index = Cascade
setmetatable(Cascade, Attempt)

function Cascade.new(attempts: { any })
	local self = setmetatable(Attempt.new(), Cascade)
	self.attempts = attempts
	return self
end

function Cascade:execute(context: any): boolean
	for _, attempt in self.attempts do
		local success = attempt:execute(context)
		if not success then
			return false
		end
	end
	return true
end

local Combo = {}
Combo.__index = Combo
setmetatable(Combo, Attempt)

function Combo.new(config: {
	animation: string?,
	accuracy: any, -- ICondition
	hits: any, -- INumber
	every: any, -- IEffect
})
	local self = setmetatable(Attempt.new(), Combo)
	self.animation = config.animation
	self.accuracy = config.accuracy
	self.hits = config.hits
	self.every = config.every
	return self
end

function Combo:execute(context: any): boolean
	local numHits = math.floor(self.hits:evaluate(context))
	local landedAny = false
	for i = 1, numHits do
		-- context._modifiers = nil

		-- Phase 4: Per-hit QTE for combo moves
		-- If AttackAction set _perHitReactions, open a window before each hit
		local perHitReactions = context._perHitReactions
		if perHitReactions and context.defender and context.defender.userId then
			local reactionFinished = false
			local reactionResult = "Miss"

			-- Build available types array and find max duration
			local availableTypes: { string } = {}
			local windowDuration = 0.5
			for _, r in perHitReactions do
				table.insert(availableTypes, r.type)
				if r.duration and r.duration > windowDuration then windowDuration = r.duration end
			end

			context.battle:openInteractiveWindow(
				context.defender.userId,
				availableTypes,
				context,
				function(result: string, _timeDelta: number)
					reactionResult = result
					reactionFinished = true
				end
			)

			local waited = 0
			while not reactionFinished and waited < (windowDuration + 0.5) do
				task.wait(0.05)
				waited += 0.05
			end

			if reactionResult == "PerfectDodge" or reactionResult == "GoodDodge" then
			-- Dodge cancels the entire hit for this combo strike (no damage, no effects)
				BattleModifiers.push(context, "cancelHit", true, "ComboHitDodge")
			elseif reactionResult == "PerfectParry" or reactionResult == "GoodParry"then
				BattleModifiers.push(context, "cancelHit", true, "ComboHitParry")
			end
		end

		-- Check if hit was cancelled by dodge (via cancelHit modifier)
		if BattleModifiers.has(context, "cancelHit") then
			break -- Entire combo hit cancelled
		end

		context.battle.events:fire("BeforeAccuracyCheck", context)
		if context.cancelled then
			break
		end

		local forceHit = BattleModifiers.getFirst(context, "accuracyOverride", nil)
		local accuracyResult = forceHit ~= nil and forceHit or self.accuracy:check(context)
		if accuracyResult then
			context.hit = true
			context.battle.events:fire("BeforeHit", context)
			if context.cancelled or BattleModifiers.has(context, "cancelHit") then
				break
			end

			local hpBefore = context.defender and context.defender.currentHp or 0
			self.every:apply(context)
			local hpAfter = context.defender and context.defender.currentHp or 0
			context.damage = math.max(0, hpBefore - hpAfter)
			landedAny = true

			context.battle.events:fire("AfterHit", context)
		else
			context.hit = false
		end
		
		if context.defender and not context.defender:isAlive() then
			break
		end
	end
	return landedAny
end

return {
	SingleAttempt = SingleAttempt,
	Cascade = Cascade,
	Combo = Combo,
}
