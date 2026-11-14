--!strict
--[=[
	DepotRankChartViewModel: the hub's rank chart (the rank chart spot; p075 scene menus, owner yes 2026-11-14): the
	company ladder (RankRegistry) as a staircase, lowest rank first, one step per rank with its level and the XP that
	reaches it (ranks come at a level's XP, never after a count of shifts), the step you are on, and one card:
	- NEXT RANK: the next rank's name, level and badge, your XP toward it (the bar fills across the band from your
	  rank to the next) and what it gives (its lanyard colour, a new badge to wear, a Roblox badge, a new pose);
	- TOP RANK! once you are Big Boss: every step lit and your XP total.
	Words for young players. `fit` scales the chart's design size to the screen. Pure.

	@class DepotRankChartViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankRegistry = require(ReplicatedStorage.Shared.Features.Rank.Data.RankRegistry)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)

export type Step = {
	level: number,
	name: string,
	levelText: string,
	xpText: string,
	-- The rank's lanyard colour.
	colour: Color3,
	reached: boolean,
	here: boolean,
}

export type Card = {
	title: string,
	rank: string,
	levelText: string,
	-- The rank whose badge the card shows (the v6 lanyard badge, LanyardBadges R<n>).
	badge: number,
	xpText: string,
	-- How full the XP bar is, 0..1.
	fraction: number,
	gets: { string },
}

export type View = {
	steps: { Step },
	-- The level you are on.
	here: number,
	top: boolean,
	subtitle: string,
	card: Card,
}

-- The chart's design size (desktop / phone), px.
local SIZE = Vector2.new(1420, 860)
local PHONE_SIZE = Vector2.new(732, 344)

local VM = {
	SIZE = SIZE,
	PHONE_SIZE = PHONE_SIZE,
}

-- 1800 -> "1,800".
local function thousands(value: number): string
	local text = tostring(math.floor(value))
	local out = text
	while true do
		local grouped, count = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = grouped
		if count == 0 then
			break
		end
	end
	return out
end

function VM.chart(xp: number?): View
	local points = math.max(xp or 0, 0)
	local current = RankFormulas.levelFor(points)
	local steps: { Step } = {}
	for _, level in RankRegistry.all() do
		table.insert(steps, {
			level = level.level,
			name = string.upper(level.name),
			levelText = `LEVEL {level.level}`,
			xpText = `{thousands(level.xp)} XP`,
			colour = level.lanyard,
			reached = level.level <= current.level,
			here = level.level == current.level,
		})
	end
	local nextLevel = RankRegistry.get(current.level + 1)
	if nextLevel == nil then
		return {
			steps = steps,
			here = current.level,
			top = true,
			subtitle = `You made it to the top!\nEveryone can see your {current.lanyardName} lanyard.`,
			card = {
				title = "TOP RANK!",
				rank = string.upper(current.name),
				levelText = `Level {current.level}`,
				badge = current.level,
				xpText = `{thousands(points)} XP`,
				fraction = 1,
				gets = { "You have every lanyard!", "More levels coming soon." },
			},
		}
	end
	local band = nextLevel.xp - current.xp
	return {
		steps = steps,
		here = current.level,
		top = false,
		subtitle = "Earn XP on every shift.\nReach the next level to rank up!",
		card = {
			title = "NEXT RANK",
			rank = string.upper(nextLevel.name),
			levelText = `Level {nextLevel.level}`,
			badge = nextLevel.level,
			xpText = `{thousands(points)} / {thousands(nextLevel.xp)} XP`,
			fraction = math.clamp((points - current.xp) / band, 0, 1),
			gets = {
				`A {nextLevel.lanyardName} lanyard`,
				"A new badge to wear",
				"A Roblox badge",
				"A new pose",
			},
		},
	}
end

-- The scale that fits the chart in the screen (90% of it), never above 1.
function VM.fit(viewport: Vector2, phone: boolean): number
	local size = if phone then PHONE_SIZE else SIZE
	return math.min(1, viewport.X * 0.9 / size.X, viewport.Y * 0.9 / size.Y)
end

return VM
