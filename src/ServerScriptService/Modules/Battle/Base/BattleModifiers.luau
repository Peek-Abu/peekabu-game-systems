--!strict
--[=[
	BattleModifiers - Generic modifier pipeline for battle passives.
	
	Passives push modifiers onto the action context during BeforeHit, and
	effects (FormulaDamage, Accuracy, etc.) read them generically. No
	character-specific logic lives in shared effect code.
	
	## Modifier Types
	- damageMultiplier: multiplies final damage (stacks multiplicatively)
	- defenseMultiplier: multiplies effective defense (stacks multiplicatively)
	- accuracyOverride: force hit (true) or force miss (false)
	- cancelHit: cancels the hit entirely (boolean)
	- reflectDamage: flat damage reflected back to attacker
	- absorbHit: cancels hit and heals defender by this amount
	- chanceBonus: additive flat bonus to a specific success probability. 
	  Value should be a table: { tag: string, value: number } (e.g. { tag = "Burn", value = 10 })
	
	## Usage in passives (CharacterDefinitions):
	```lua
	local Modifiers = require(...BattleModifiers)
	effect = function(context)
	    Modifiers.push(context, "damageMultiplier", 0.5, "Infinity Field")
	end
	```
	
	## Usage in effects (FormulaDamage, Accuracy):
	```lua
	local dmgMult = Modifiers.getProduct(context, "damageMultiplier")
	damageAmount = math.floor(damageAmount * dmgMult)
	```
	
	@class BattleModifiers
]=]

local BattleModifiers = {}

--- Push a modifier onto the context. Source is for debug/logging.
function BattleModifiers.push(context: any, modType: string, value: any, source: string?)
	if not context._modifiers then
		context._modifiers = {}
	end
	table.insert(context._modifiers, {
		type = modType,
		value = value,
		source = source or "unknown",
	})
end

--- Get all modifiers of a given type from the context.
function BattleModifiers.getAll(context: any, modType: string): { { value: any, source: string } }
	local results = {}
	if not context._modifiers then return results end
	for _, mod in context._modifiers do
		if mod.type == modType then
			table.insert(results, mod)
		end
	end
	return results
end

--- Get the multiplicative product of all modifiers of a given type (default 1).
--- Use for damageMultiplier, defenseMultiplier, etc.
function BattleModifiers.getProduct(context: any, modType: string): number
	local product = 1
	if not context._modifiers then return product end
	for _, mod in context._modifiers do
		if mod.type == modType then
			product *= mod.value
		end
	end
	return product
end

--- Get the additive sum of all modifiers of a given type (default 0).
--- Use for reflectDamage, absorbHit, etc.
function BattleModifiers.getSum(context: any, modType: string): number
	local sum = 0
	if not context._modifiers then return sum end
	for _, mod in context._modifiers do
		if mod.type == modType then
			sum += mod.value
		end
	end
	return sum
end

--- Get the additive sum of all chance bonuses matching a specific tag (default 0).
--- Use for procs like Burn, Paralysis, etc.
function BattleModifiers.getChanceBonus(context: any, tag: string?): number
	if not tag or not context._modifiers then return 0 end
	local sum = 0
	for _, mod in context._modifiers do
		if mod.type == "chanceBonus" and mod.value and mod.value.tag == tag then
			sum += mod.value.value
		end
	end
	return sum
end

--- Check if any modifier of a given type exists (boolean check).
--- Use for cancelHit, accuracyOverride, etc.
function BattleModifiers.has(context: any, modType: string): boolean
	if not context._modifiers then return false end
	for _, mod in context._modifiers do
		if mod.type == modType then
			return true
		end
	end
	return false
end

--- Get the first modifier value of a given type, or a default.
function BattleModifiers.getFirst(context: any, modType: string, default: any): any
	if not context._modifiers then return default end
	for _, mod in context._modifiers do
		if mod.type == modType then
			return mod.value
		end
	end
	return default
end

return BattleModifiers
