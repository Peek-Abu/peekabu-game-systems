--!strict
--[=[
	ShiftNightViewModel: the Night Shift words every shift screen shares (owner concept B 11-18: nights in a row, each
	night's goal the only fail line, a week every ShiftNightConstants.WEEK_NIGHTS nights, no end). `of` reads the run
	off the shift snapshot (nil on a quick shift or an older snapshot, so every screen keeps its quick-shift look); the
	landing readout's NIGHT n / WEEK w (`nightTitle`, `weekTitle`), the vote's "NEXT: NIGHT 6" and "CLOCK OUT"
	(`votes`), the short week report after a survived week (`weekReport`: WEEK 1 DONE!, the nights survived and the
	bonus) and the run-over header (`ended`: FIRED!, OUT OF COATS or CLOCKED OUT, and the night reached). Screens show
	tonight's goal only (owner 11-18: easier to read). Words at a kid's reading level. Pure.

	@class ShiftNightViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)

-- A Night Shift run as the screens read it.
export type Night = {
	night: number,
	week: number,
	-- The week report's bonus: set on the results of a survived week's last night (nil otherwise).
	weekBonus: number?,
	-- How the run ended (nil: it goes on) and the night it reached (this night when the server names none).
	runOver: ShiftTypes.RunOver?,
	nightReached: number,
}

export type VoteWords = { another: string, depot: string, footer: string }

-- The run-over header: its big title, the line under it, and whether it is a good ending (gold) or a bad one (coral).
export type EndView = { title: string, line: string, good: boolean }

local ShiftNightViewModel = {}

local function count(value: unknown): number?
	return if type(value) == "number" then value else nil
end

-- "1,500": a whole number with thousands commas.
function ShiftNightViewModel.commas(value: number): string
	local text = tostring(math.floor(value))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return text .. out
end

-- The Night Shift run in `snapshot`; nil on a quick shift, an older snapshot (no night) or no snapshot.
function ShiftNightViewModel.of(snapshot: ShiftTypes.ShiftSnapshot?): Night?
	if snapshot == nil or snapshot.runMode ~= "night" then
		return nil
	end
	local night = count(snapshot.night)
	if night == nil then
		return nil
	end
	local whole = math.max(1, math.floor(night))
	return {
		night = whole,
		week = count(snapshot.week) or ShiftNightFormulas.week(whole),
		weekBonus = count(snapshot.weekBonus),
		runOver = snapshot.runOver,
		nightReached = count(snapshot.nightReached) or whole,
	}
end

function ShiftNightViewModel.nightTitle(night: number): string
	return `NIGHT {math.floor(night)}`
end

function ShiftNightViewModel.weekTitle(week: number): string
	return `WEEK {math.floor(week)}`
end

-- The short week report (owner 11-18) on the results of a survived week's last night: WEEK w DONE!, the nights
-- survived and the bonus; nil on any other night and once the run is over (its own header wins). Later weeks may add
-- choices here (items, power-ups, heals, a map pick, the company); none yet, so it stays one line.
function ShiftNightViewModel.weekReport(night: Night): EndView?
	local bonus = night.weekBonus
	if bonus == nil or night.runOver ~= nil then
		return nil
	end
	local nights = if night.night == 1 then "1 night" else `{night.night} nights`
	return {
		title = `WEEK {night.week} DONE!`,
		line = `{nights} survived · Week bonus +{ShiftNightViewModel.commas(bonus)} Credits`,
		good = true,
	}
end

-- The vote's two choices: the next night (by number) or clocking out with the pay.
function ShiftNightViewModel.votes(night: Night): VoteWords
	return {
		another = `NEXT: {ShiftNightViewModel.nightTitle(night.night + 1)}`,
		depot = "CLOCK OUT",
		footer = "Clock out to keep your pay · a tie means Next night",
	}
end

-- The run-over header, or nil while the run goes on.
function ShiftNightViewModel.ended(night: Night): EndView?
	local over = night.runOver
	if over == nil then
		return nil
	end
	local reached = `You got to night {night.nightReached}`
	if over == "fired" then
		return { title = "FIRED!", line = `You missed tonight's goal · {reached}`, good = false }
	elseif over == "wiped" then
		return { title = "OUT OF COATS", line = `Everyone ran out of coats · {reached}`, good = false }
	end
	return { title = "CLOCKED OUT", line = `You kept your pay · {reached}`, good = true }
end

return ShiftNightViewModel
