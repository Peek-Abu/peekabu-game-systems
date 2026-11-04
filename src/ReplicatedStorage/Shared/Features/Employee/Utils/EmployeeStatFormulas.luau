--!strict
--[=[
	EmployeeStatFormulas: how an employee's five stats (EmployeeProfileRegistry, 1-5 bars) change play
	(docs/superpowers/specs/2026-11-03-employee-stat-effects-design.md, owner-approved 2026-11-03).

	1 bar plays exactly like today's game, and each bar above it adds its stat's STEP, so a stat only ever helps and the
	maps (tuned for the lowest values) stay clearable solo by a 1-bar employee. Every 1-to-5 spread stays inside BAND.

	- `level(employee, stat)`: the employee's own bars, FLOOR for anyone without a profile.
	- `barsFrom(value)` / `barsOn(character, stat)`: bars from a value / a character's stat attribute (written by the
	  server's EmployeeStatSystem), clamped and rounded to 1-5; FLOOR when there is none.
	- `gain(stat, bars)`: the step times the bars above 1. `effect` is 1 + gain (Speed, Stamina, Suction: more is
	  better), `cut` is 1 - gain (Strength takes it off a load's weight, Quiet off a noise's radius).
	- `carriedWeight(weight, bars)`: a load's weight with Strength taken off (before Carry's slowdown).
	- `suctionRate(player, target)`: how fast the player's vacuum cleans (the Suction effect; an Interaction channel's
	  `rate`, for Vacuum's piles and Cargo's grime).
	- `noiseCut(bars)`: the radius factor of a noise several players make at once (a shared pile): the loudest
	  maker's, so a quiet employee never hides a loud one; 1 with no maker.

	The owner of each value reads it: Sprint (Speed, Stamina, Quiet on sprint feet), Cargo's load (Strength), Vacuum and
	Cargo's grime (Suction, Quiet on the vacuum).

	@class EmployeeStatFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)

type Stat = EmployeeProfileRegistry.Stat

-- The change per bar above 1 (the approved sizes): Speed +1.5% walk and sprint, Stamina +5% sprint length and refill
-- speed, Strength 4% off a load's weight, Suction +4% cleaning speed, Quiet 4% off your own noises' radius.
local STEP: { [Stat]: number } = {
	speed = 0.015,
	stamina = 0.05,
	strength = 0.04,
	suction = 0.04,
	quiet = 0.04,
}

local EmployeeStatFormulas = {
	-- The bar count that plays like today's tuning.
	FLOOR = 1,
	MAX = 5,
	STEP = table.freeze(STEP),
	-- The most any stat may move from 1 to 5 bars (about ±8% round the middle; requirements: about ±15%).
	BAND = 0.16,
}

function EmployeeStatFormulas.barsFrom(value: unknown): number
	if type(value) ~= "number" or value ~= value then
		return EmployeeStatFormulas.FLOOR
	end
	return math.clamp(math.round(value), EmployeeStatFormulas.FLOOR, EmployeeStatFormulas.MAX)
end

function EmployeeStatFormulas.level(employee: string, stat: Stat): number
	local profile = EmployeeProfileRegistry.get(employee)
	return if profile ~= nil then EmployeeStatFormulas.barsFrom(profile.stats[stat]) else EmployeeStatFormulas.FLOOR
end

function EmployeeStatFormulas.barsOn(character: Instance?, stat: Stat): number
	local value = if character ~= nil then character:GetAttribute(EmployeeConstants.STAT_ATTRIBUTES[stat]) else nil
	return EmployeeStatFormulas.barsFrom(value)
end

function EmployeeStatFormulas.gain(stat: Stat, bars: number): number
	local above = EmployeeStatFormulas.barsFrom(bars) - EmployeeStatFormulas.FLOOR
	return math.min(above * STEP[stat], EmployeeStatFormulas.BAND)
end

function EmployeeStatFormulas.effect(stat: Stat, bars: number): number
	return 1 + EmployeeStatFormulas.gain(stat, bars)
end

function EmployeeStatFormulas.cut(stat: Stat, bars: number): number
	return 1 - EmployeeStatFormulas.gain(stat, bars)
end

function EmployeeStatFormulas.carriedWeight(weight: number, bars: number): number
	return weight * EmployeeStatFormulas.cut("strength", bars)
end

function EmployeeStatFormulas.suctionRate(player: Player, _target: Instance?): number
	return EmployeeStatFormulas.effect("suction", EmployeeStatFormulas.barsOn(player.Character, "suction"))
end

function EmployeeStatFormulas.noiseCut(makers: { number }): number
	local loudest = 0
	for _, bars in makers do
		loudest = math.max(loudest, EmployeeStatFormulas.cut("quiet", bars))
	end
	return if #makers > 0 then loudest else 1
end

return EmployeeStatFormulas
