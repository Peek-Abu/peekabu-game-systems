--!strict
--[=[
	ShiftNightViewModel: the Night Shift words every shift screen shares (owner concept B 11-18: nights in a row, a
	weekly quota every ShiftNightConstants.WEEK_NIGHTS nights, no end). `of` reads the run off the shift snapshot (nil
	on a quick shift or an older snapshot, so every screen keeps its quick-shift look); the landing readout's NIGHT n /
	WEEK w (`nightTitle`, `weekTitle`), the HUD's "This week: 900 / 1,500" (`weekLine`: the week's Gloom so far plus
	tonight's while the night runs), the vote's "NEXT: NIGHT 5" and "CLOCK OUT" (`votes`), and the run-over header
	(`ended`: FIRED!, OUT OF COATS or CLOCKED OUT, and the night reached). Words at a kid's reading level. Pure.

	@class ShiftNightViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)

-- A Night Shift run as the screens read it.
export type Night = {
	night: number,
	week: number,
	-- The week's quota (nil until the server sets one) and the Gloom cleared toward it (tonight's once it is over).
	weekQuota: number?,
	weekCleared: number,
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
		weekQuota = count(snapshot.weekQuota),
		weekCleared = count(snapshot.weekCleared) or 0,
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

-- The HUD's week line: the week's Gloom so far (plus tonight's `cleared` while the night runs, before the server
-- folds it in) over the week's quota; nil without a quota.
function ShiftNightViewModel.weekLine(night: Night, cleared: number, phase: ShiftTypes.ShiftPhase): string?
	local quota = night.weekQuota
	if quota == nil then
		return nil
	end
	local tonight = if phase == "running" or phase == "starting" then cleared else 0
	local done = math.max(0, night.weekCleared + tonight)
	return `This week: {ShiftNightViewModel.commas(done)} / {ShiftNightViewModel.commas(quota)}`
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
		return { title = "FIRED!", line = `You missed the week's goal · {reached}`, good = false }
	elseif over == "wiped" then
		return { title = "OUT OF COATS", line = `Everyone ran out of coats · {reached}`, good = false }
	end
	return { title = "CLOCKED OUT", line = `You kept your pay · {reached}`, good = true }
end

return ShiftNightViewModel
