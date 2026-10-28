--!strict
--[=[
	BadgeMilestoneRules: which Odd Hours badges a moment earns (keys from BadgeConstants.GAME). Pure; awarding a badge
	the player already owns is a no-op (BadgeServiceServer), so these only say what the moment qualifies for.

	- `rankKeys`: every rank badge up to the level reached (level 1 has none).
	- `shiftKeys`: Clocked In for a worked shift; Clean Sweep when the contract was met and the whole crew got out;
	  Night Shift Squad with SQUAD_SIZE or more on the crew.
	- `pullKeys`: a Locker pull's rarity; Lucky Locker for Epic or better, Super Lucky Locker for Legendary or better.
	- `skinKey`: New Look for equipping a skin that is not a default one.

	@class BadgeMilestoneRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadgeConstants = require(ReplicatedStorage.Shared.Features.Badge.Data.BadgeConstants)

-- What a finished shift tells the badges (a subset of RankTypes.ShiftFacts).
export type ShiftFacts = {
	worked: boolean,
	quotaMet: boolean?,
	crewExtracted: boolean?,
}

local EPIC_PLUS = table.freeze({ epic = true, legendary = true, odd = true })
local LEGENDARY_PLUS = table.freeze({ legendary = true, odd = true })

local BadgeMilestoneRules = {}

function BadgeMilestoneRules.rankKeys(level: number): { string }
	local keys: { string } = {}
	for reached = 2, level do
		table.insert(keys, `rank-{reached}`)
	end
	return keys
end

function BadgeMilestoneRules.shiftKeys(facts: ShiftFacts, crewSize: number): { string }
	local keys: { string } = {}
	if not facts.worked then
		return keys
	end
	table.insert(keys, "clocked-in")
	if facts.quotaMet == true and facts.crewExtracted == true then
		table.insert(keys, "clean-sweep")
	end
	if crewSize >= BadgeConstants.SQUAD_SIZE then
		table.insert(keys, "night-shift-squad")
	end
	return keys
end

function BadgeMilestoneRules.pullKeys(rarity: string): { string }
	local keys: { string } = {}
	if EPIC_PLUS[rarity] then
		table.insert(keys, "epic-pull")
	end
	if LEGENDARY_PLUS[rarity] then
		table.insert(keys, "legendary-pull")
	end
	return keys
end

-- `rarity` is the equipped skin's CosmeticRegistry rarity.
function BadgeMilestoneRules.skinKey(rarity: string): string?
	return if rarity ~= "default" then "new-look" else nil
end

return BadgeMilestoneRules
