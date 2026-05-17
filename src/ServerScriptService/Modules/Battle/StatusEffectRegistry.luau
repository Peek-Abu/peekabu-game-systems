--!strict
--[=[
	StatusEffectRegistry - Event-driven status effect definitions.
	
	Instead of BattleSession manually processing each status in a big if/else,
	each status type defines its own tick behavior. When applied to a battler,
	it subscribes to the battle's EventBus and fires automatically.
	
	## Adding a new status effect:
	1. Define it in STATUS_DEFINITIONS with a `tick` function
	2. The Burn/Poison/etc Effect in Effect.luau calls `applyStatus()`
	3. That's it — no changes needed in BattleSession
	
	@class StatusEffectRegistry
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local BattleModifiers = require(ServerScriptService.Modules.Battle.Base.BattleModifiers)

local StatusEffectRegistry = {}

export type StatusDefinition = {
	name: string,
	-- Called each turn tick. Return damage dealt (for networking) or 0.
	tick: (battler: any, battle: any) -> number,
	-- Whether this status prevents acting (checked by agenda)
	preventsAction: ((battler: any) -> boolean)?,
	-- How many turns the status lasts (nil = permanent until cured)
	duration: number?,
	-- Called once when the status is first registered on a battler.
	-- Use this to subscribe to events (e.g. BeforeHit for damage amplification).
	onRegister: ((battler: any, battle: any) -> ())?,
}

local STATUS_DEFINITIONS: { [string]: StatusDefinition } = {
	Burn = {
		name = "Burn",
		duration = 5,
		tick = function(battler: any, _battle: any): number
			local burnDmg = math.floor(battler.maxHp / 16)
			battler:takeDamage(burnDmg)
			return burnDmg
		end,
	},

	Poison = {
		name = "Poison",
		duration = 5,
		tick = function(battler: any, _battle: any): number
			local poisonDmg = math.floor(battler.maxHp / 8)
			battler:takeDamage(poisonDmg)
			return poisonDmg
		end,
	},

	Paralysis = {
		name = "Paralysis",
		duration = 3,
		tick = function(_battler: any, _battle: any): number
			return 0
		end,
		preventsAction = function(_battler: any): boolean
			return math.random(100) <= 25
		end,
	},

	Stun = {
		name = "Stun",
		duration = 1,
		tick = function(_battler: any, _battle: any): number
			return 0
		end,
		preventsAction = function(_battler: any): boolean
			return true -- 100% skip
		end,
	},

	Scorch = {
		name = "Scorch",
		duration = 4,
		-- Scorch doesn't deal direct damage. It amplifies Fire damage taken by 15%.
		-- The amplification is pushed via BattleModifiers on BeforeHit.
		tick = function(_battler: any, _battle: any): number
			return 0
		end,
		onRegister = function(battler: any, battle: any)
			battle.events:subscribe("BeforeHit", function(hitContext)
				if hitContext.defender ~= battler then return end
				if not table.find(battler.statusEffects, "Scorch") then return end
				if hitContext.move and hitContext.move.element == "Fire" then
					BattleModifiers.push(hitContext, "damageMultiplier", 1.15, "Scorch")
				end
			end)
		end,
	},
}

--- Get the definition for a status effect by name.
function StatusEffectRegistry.getDefinition(name: string): StatusDefinition?
	return STATUS_DEFINITIONS[name]
end

--- Register all active status effects for a battler onto the battle's EventBus.
--- Called once per battler at battle start (and when new statuses are applied mid-battle).
function StatusEffectRegistry.registerBattlerStatuses(battler: any, battle: any)
	for _, statusName in battler.statusEffects do
		StatusEffectRegistry.registerStatus(battler, statusName, battle)
	end
end

--- Subscribe a single status effect to the battle's event bus.
--- Ticks on "BattlerTurnEnd" — only when the affected battler's turn ends.
function StatusEffectRegistry.registerStatus(battler: any, statusName: string, battle: any)
	local def = STATUS_DEFINITIONS[statusName]
	if not def then return end

	-- Avoid double-subscribing: track registered statuses
	if not battler._registeredStatuses then
		battler._registeredStatuses = {}
	end
	if battler._registeredStatuses[statusName] then return end
	battler._registeredStatuses[statusName] = true

	-- One-time setup hook (e.g. Scorch subscribes to BeforeHit for damage amp)
	if def.onRegister then
		def.onRegister(battler, battle)
	end

	-- Track duration on battler for client-side display
	local turnsLeft = def.duration -- nil = permanent
	if turnsLeft then
		if not battler._statusDurations then
			battler._statusDurations = {}
		end
		battler._statusDurations[statusName] = turnsLeft
	end

	local unsub: () -> ()
	unsub = battle.events:subscribe("BattlerTurnEnd", function(data)
		if data.battler ~= battler then return end
		if not battler:isAlive() then return end
		if not table.find(battler.statusEffects, statusName) then
			unsub()
			return
		end

		local damage = def.tick(battler, battle)
		if damage > 0 then
			battle.events:fire("StatusDamage", {
				battler = battler,
				status = statusName,
				damage = damage,
				battle = battle,
			})
			battle.events:fire("BattleLog", {
				message = `{battler.itemType} takes {damage} {statusName} damage!`,
				category = "status",
			})
		end

		-- Handle duration expiry
		if turnsLeft then
			turnsLeft -= 1
			if battler._statusDurations then
				battler._statusDurations[statusName] = turnsLeft
			end
			if turnsLeft <= 0 then
				local idx = table.find(battler.statusEffects, statusName)
				if idx then
					table.remove(battler.statusEffects, idx)
				end
				battler._registeredStatuses[statusName] = nil
				if battler._statusDurations then
					battler._statusDurations[statusName] = nil
				end
				battle.events:fire("BattleLog", {
					message = `{battler.itemType}'s {statusName} wore off.`,
					category = "status",
				})
				unsub()
			end
		end
	end)
end

--- Check if a battler's status prevents them from acting this turn.
function StatusEffectRegistry.preventsAction(battler: any): boolean
	for _, statusName in battler.statusEffects do
		local def = STATUS_DEFINITIONS[statusName]
		if def and def.preventsAction and def.preventsAction(battler) then
			return true
		end
	end
	return false
end

return StatusEffectRegistry
