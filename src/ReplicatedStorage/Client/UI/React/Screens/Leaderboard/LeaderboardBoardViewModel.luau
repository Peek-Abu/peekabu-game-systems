--!strict
--[=[
	LeaderboardBoardViewModel: the words on the hub's weekly crew board (LeaderboardBoard), from the `crewBoard` world
	entry: a kid-level title, what the score means and when the board starts over, then the crews best first. Pure.

	@class LeaderboardBoardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardTypes = require(ReplicatedStorage.Shared.Features.Leaderboard.Data.LeaderboardTypes)

export type Row = { rank: string, names: string, score: string }

export type View = {
	title: string,
	subtitle: string,
	rows: { Row },
	empty: string?,
}

local TITLE = "BEST CREWS THIS WEEK"
local MEANING = "Most Gloom cleaned in one shift"
local EMPTY = "No crews yet this week. Be the first!"

local LeaderboardBoardViewModel = {}

-- "2d 5h" while a day or more is left, else "3h 20m".
local function countdown(seconds: number): string
	local left = math.max(0, math.floor(seconds))
	local days = left // 86400
	local hours = (left % 86400) // 3600
	if days > 0 then
		return `{days}d {hours}h`
	end
	return `{hours}h {(left % 3600) // 60}m`
end

-- 1240 -> "1,240".
local function commas(value: number): string
	local text = string.format("%d", math.floor(value))
	local result = text
	repeat
		local done: number
		result, done = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
	until done == 0
	return result
end

function LeaderboardBoardViewModel.view(board: LeaderboardTypes.Board?, now: number): View
	if board == nil then
		return { title = TITLE, subtitle = MEANING, rows = {}, empty = EMPTY }
	end
	local rows: { Row } = {}
	for index, entry in board.entries do
		table.insert(rows, {
			rank = tostring(index),
			names = table.concat(entry.names, " · "),
			score = commas(entry.score),
		})
	end
	return {
		title = TITLE,
		subtitle = `{MEANING} · new board in {countdown(board.endsAt - now)}`,
		rows = rows,
		empty = if #rows == 0 then EMPTY else nil,
	}
end

return LeaderboardBoardViewModel
