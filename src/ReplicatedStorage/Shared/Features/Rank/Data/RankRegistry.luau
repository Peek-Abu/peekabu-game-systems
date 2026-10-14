--!strict
--[=[
	RankRegistry: the company ladder, looked up by level (Cleanup Crew "Clearance Level"). Data-driven: a level is one
	row in LEVELS, so later levels are appended here without touching any logic. Levels are cosmetic only.

	MVP ships levels 1-3. Planned next rows (append when approved):
	  { level = 4, name = "Senior Clearance Associate", xp = 300, ... },
	  { level = 5, name = "Regional Clearance Lead", xp = 600, ... },

	The ladder is checked at load (`check`): level n is row n, level 1 needs 0 XP, thresholds strictly rise.

	@class RankRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)

type Level = RankTypes.Level

local LEVELS: { Level } = {
	{
		level = 1,
		name = "Intern (Unpaid)",
		xp = 0,
		lanyard = Color3.fromHex("8A8F98"),
		lanyardName = "grey",
	},
	{
		level = 2,
		name = "Probationary Associate",
		xp = 40,
		lanyard = Color3.fromHex("1E7A46"),
		lanyardName = "green",
	},
	{
		level = 3,
		name = "Clearance Associate",
		xp = 120,
		lanyard = Color3.fromHex("1F4E9A"),
		lanyardName = "blue",
	},
}

local RankRegistry = {}

-- Whether `levels` is a valid ladder (see the header).
function RankRegistry.check(levels: { Level }): boolean
	if #levels == 0 or levels[1].xp ~= 0 then
		return false
	end
	for index, level in levels do
		if level.level ~= index or level.name == "" then
			return false
		end
		if index > 1 and level.xp <= levels[index - 1].xp then
			return false
		end
	end
	return true
end

assert(RankRegistry.check(LEVELS), "RankRegistry: the ladder is malformed (see RankRegistry.check)")
for _, level in LEVELS do
	table.freeze(level)
end
table.freeze(LEVELS)

function RankRegistry.get(level: number): Level?
	return LEVELS[level]
end

-- Every level, lowest first (a copy).
function RankRegistry.all(): { Level }
	return table.clone(LEVELS)
end

function RankRegistry.top(): Level
	return LEVELS[#LEVELS]
end

return RankRegistry
