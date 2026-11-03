--!strict
--[=[
	EmployeeStatFormulas: the seam where an employee's five stats (EmployeeProfileRegistry, 1-5 bars) will one day
	change play. Stats are DISPLAY ONLY today: `STEP` is 0, so every `effect` is exactly 1 and nothing reads it yet.

	- `level(employee, stat)`: the employee's bars, `MIDDLE` for anyone without a profile.
	- `effectOf(level)` / `effect(employee, stat)`: a multiplier around 1, `STEP` per bar away from the middle,
	  clamped to the narrow band (requirements: about ±15%).

	Turning stats on later means a non-zero `STEP` (or a per-stat table) and a call from the system that owns the
	value (Sprint for speed and stamina, Carry for strength, Vacuum for suction, Noise for quiet). Every map is tuned
	for the lowest values, so a 1-bar employee must still clear it solo (characters/launch/new-employee-requirements.md).

	@class EmployeeStatFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)

type Stat = EmployeeProfileRegistry.Stat

local EmployeeStatFormulas = {
	-- The bar count that plays like today's tuning.
	MIDDLE = 3,
	-- The change per bar away from the middle. 0 while stats are display only.
	STEP = 0,
	-- The furthest any effect may move from 1.
	BAND = 0.15,
}

function EmployeeStatFormulas.level(employee: string, stat: Stat): number
	local profile = EmployeeProfileRegistry.get(employee)
	return if profile ~= nil then profile.stats[stat] else EmployeeStatFormulas.MIDDLE
end

function EmployeeStatFormulas.effectOf(level: number): number
	local offset = (math.clamp(level, 1, 5) - EmployeeStatFormulas.MIDDLE) * EmployeeStatFormulas.STEP
	local band = EmployeeStatFormulas.BAND
	return 1 + math.clamp(offset, -band, band)
end

function EmployeeStatFormulas.effect(employee: string, stat: Stat): number
	return EmployeeStatFormulas.effectOf(EmployeeStatFormulas.level(employee, stat))
end

return EmployeeStatFormulas
