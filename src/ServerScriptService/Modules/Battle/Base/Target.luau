--!strict

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function getEnemySide(battle: any, attacker: any): { any }
	local attackerSide = if table.find(battle.allies, attacker) then battle.allies else battle.enemies
	return if attackerSide == battle.allies then battle.enemies else battle.allies
end

local function getAllySide(battle: any, attacker: any): { any }
	return if table.find(battle.allies, attacker) then battle.allies else battle.enemies
end

local function aliveIn(side: { any }): { any }
	local alive = {}
	for _, b in side do
		if b:isAlive() then table.insert(alive, b) end
	end
	return alive
end

local function randomAlive(side: { any }): any?
	local alive = aliveIn(side)
	if #alive == 0 then return nil end
	return alive[math.random(#alive)]
end

-- ── ITarget ─────────────────────────────────────────────────────────────────

local Target = {}
Target.__index = Target

function Target.new()
	return setmetatable({}, Target)
end

--- Returns the targeting kind: "enemy", "self", "allEnemies", "allAllies"
function Target:type(): string
	error("type() must be implemented by concrete target")
end

--- Context-driven resolve.
---   Effect phase  (context.defender set): ALWAYS returns { battler, ... }
---   Input phase   (no context.defender):  returns single battler for AttackAction.new
function Target:resolve(context: any): any
	error("resolve() must be implemented by concrete target")
end

-- ── Concrete Targets ────────────────────────────────────────────────────────

-- Always resolves to context.attacker
local Attacker = {}
Attacker.__index = Attacker
setmetatable(Attacker, Target)

function Attacker.new()
	return setmetatable(Target.new(), Attacker)
end

function Attacker:type(): string return "self" end
function Attacker:resolve(context: any): any
	if context.defender then return { context.attacker } end
	return context.attacker
end

-- ─────────────────────────────────────────────────────────────────────────────

-- Single enemy. Effect phase → context.defender. Input phase → pick/validate.
local Defender = {}
Defender.__index = Defender
setmetatable(Defender, Target)

function Defender.new()
	return setmetatable(Target.new(), Defender)
end

function Defender:type(): string return "enemy" end
function Defender:resolve(context: any): any?
	-- Effect phase: return array
	if context.defender then return { context.defender } end

	-- Input phase: single battler for AttackAction.new
	local enemySide = getEnemySide(context.battle, context.attacker)

	if context.choiceIndex then
		if context.choiceIndex < 1 or context.choiceIndex > #enemySide then return nil end
		local target = enemySide[context.choiceIndex]
		if not target or not target:isAlive() then return nil end
		return target
	end

	-- NPC AI: random alive enemy
	return randomAlive(enemySide)
end

-- ─────────────────────────────────────────────────────────────────────────────

-- Self-targeting (heals, buffs, transformations)
local Self = {}
Self.__index = Self
setmetatable(Self, Target)

function Self.new()
	return setmetatable(Target.new(), Self)
end

function Self:type(): string return "self" end
function Self:resolve(context: any): any
	if context.defender then return { context.attacker } end
	return context.attacker
end

-- ─────────────────────────────────────────────────────────────────────────────

-- All alive enemies. Effect phase → array. Input phase → random primary (single).
local AllEnemies = {}
AllEnemies.__index = AllEnemies
setmetatable(AllEnemies, Target)

function AllEnemies.new()
	return setmetatable(Target.new(), AllEnemies)
end

function AllEnemies:type(): string return "allEnemies" end

function AllEnemies:resolve(context: any): any
	local battle = context.battle

	-- Effect phase: return full array of alive enemies
	if context.defender then
		if not battle then return { context.defender } end
		return aliveIn(getEnemySide(battle, context.attacker))
	end

	-- Input phase: pick random alive enemy as primary target for Attempt pipeline
	if not battle then return nil end
	return randomAlive(getEnemySide(battle, context.attacker))
end

-- ─────────────────────────────────────────────────────────────────────────────

-- All alive allies. Effect phase → array. Input phase → attacker as primary.
local AllAllies = {}
AllAllies.__index = AllAllies
setmetatable(AllAllies, Target)

function AllAllies.new()
	return setmetatable(Target.new(), AllAllies)
end

function AllAllies:type(): string return "allAllies" end
function AllAllies:resolve(context: any): any
	local battle = context.battle

	-- Effect phase
	if context.defender then
		if not battle then return { context.attacker } end
		return aliveIn(getAllySide(battle, context.attacker))
	end

	-- Input phase
	return context.attacker
end

-- ─────────────────────────────────────────────────────────────────────────────

-- Random alive enemy (auto-pick, no player choice)
local RandomEnemy = {}
RandomEnemy.__index = RandomEnemy
setmetatable(RandomEnemy, Target)

function RandomEnemy.new()
	return setmetatable(Target.new(), RandomEnemy)
end

function RandomEnemy:type(): string return "enemy" end
function RandomEnemy:resolve(context: any): any?
	local battle = context.battle
	local pick = if battle then randomAlive(getEnemySide(battle, context.attacker)) else context.defender
	if context.defender then
		return if pick then { pick } else {}
	end
	return pick
end

-- ─────────────────────────────────────────────────────────────────────────────

return {
	Attacker = Attacker,
	Defender = Defender,
	Self = Self,
	AllEnemies = AllEnemies,
	AllAllies = AllAllies,
	RandomEnemy = RandomEnemy,
}
