--!strict
--[=[
	RankRegistry: the company ladder, looked up by level (Cleanup Crew "Clearance Level"). Data-driven: a level is one
	row in LEVELS, so later levels are appended here without touching any logic. Levels are cosmetic only.

	7 ranks: New Kid → Sweeper → Cleaner → Super Cleaner → Little Boss → Boss → Big Boss.
	Big Boss in about 6 weeks of regular play (5 days/week, ~4 shifts/day). After Big Boss, XP feeds
	the Clearance Level (an endless track, added later). The lanyard colours match the v6 badge palette
	(EmployeeLanyardConstants.COLOURS).

	The ladder is checked at load (`check`): level n is row n, level 1 needs 0 XP, thresholds strictly rise.

	@class RankRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)

type Level = RankTypes.Level

local LEVELS: { Level } = {
	{
		level = 1,
		name = "New Kid",
		xp = 0,
		lanyard = Color3.fromHex("6F737B"),
		lanyardName = "grey",
	},
	{
		level = 2,
		name = "Sweeper",
		xp = 75,
		lanyard = Color3.fromHex("2E9B43"),
		lanyardName = "green",
	},
	{
		level = 3,
		name = "Cleaner",
		xp = 300,
		lanyard = Color3.fromHex("2C6FD9"),
		lanyardName = "blue",
	},
	{
		level = 4,
		name = "Super Cleaner",
		xp = 800,
		lanyard = Color3.fromHex("7C3FCB"),
		lanyardName = "purple",
	},
	{
		level = 5,
		name = "Little Boss",
		xp = 1800,
		lanyard = Color3.fromHex("C8262E"),
		lanyardName = "red",
	},
	{
		level = 6,
		name = "Boss",
		xp = 3400,
		lanyard = Color3.fromHex("1F2C68"),
		lanyardName = "navy",
	},
	{
		level = 7,
		name = "Big Boss",
		xp = 5200,
		lanyard = Color3.fromHex("E9A923"),
		lanyardName = "gold",
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
