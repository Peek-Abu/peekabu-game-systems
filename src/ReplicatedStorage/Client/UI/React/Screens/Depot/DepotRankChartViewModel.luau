--!strict
--[=[
	DepotRankChartViewModel: the hub's rank chart (the rank chart spot): every rank of the company ladder
	(RankRegistry), top rank first, the ones you have reached, where you are, and one line saying how much XP the
	next rank needs. Words for young players. `fit` scales the chart's design size to the screen. Pure.

	@class DepotRankChartViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)

export type Row = {
	level: number,
	name: string,
	-- The rank's lanyard colour.
	colour: Color3,
	reached: boolean,
	here: boolean,
}

export type View = {
	rows: { Row },
	line: string,
}

-- The chart's design size (desktop / phone), px.
local SIZE = Vector2.new(460, 560)
local PHONE_SIZE = Vector2.new(330, 400)

local VM = {
	SIZE = SIZE,
	PHONE_SIZE = PHONE_SIZE,
}

function VM.chart(xp: number?): View
	local points = math.max(xp or 0, 0)
	local current = RankFormulas.levelFor(points)
	local levels = RankRegistry.all()
	local rows: { Row } = {}
	for index = #levels, 1, -1 do
		local level = levels[index]
		table.insert(rows, {
			level = level.level,
			name = level.name,
			colour = level.lanyard,
			reached = level.level <= current.level,
			here = level.level == current.level,
		})
	end
	local nextLevel = RankRegistry.get(current.level + 1)
	local line = if nextLevel == nil
		then `You are the {current.name}!`
		else `{nextLevel.xp - points} more XP to {nextLevel.name}!`
	return { rows = rows, line = line }
end

-- The scale that fits the chart in the screen (90% of it), never above 1.
function VM.fit(viewport: Vector2, phone: boolean): number
	local size = if phone then PHONE_SIZE else SIZE
	return math.min(1, viewport.X * 0.9 / size.X, viewport.Y * 0.9 / size.Y)
end

return VM
