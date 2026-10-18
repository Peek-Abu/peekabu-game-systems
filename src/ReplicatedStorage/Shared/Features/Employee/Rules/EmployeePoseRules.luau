--!strict
--[=[
	EmployeePoseRules: which pose a portrait shows (EmployeePoseRegistry), from where it is shown and what is known
	about the player. The grade (results) beats the level (Clearance Level), which beats the context's own pose; a
	level with no entry inherits the highest listed level under it.

	@class EmployeePoseRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)

export type Facts = {
	-- The player's Clearance Level, nil until published.
	level: number?,
	-- The shift's grade letter, on the results.
	grade: string?,
}

local EmployeePoseRules = {}

local function byLevel(levels: { [number]: string }?, level: number?): string?
	if levels == nil or level == nil then
		return nil
	end
	local best: number? = nil
	for listed in levels do
		if listed <= level and (best == nil or listed > best) then
			best = listed
		end
	end
	return if best ~= nil then levels[best] else nil
end

--[=[
	The pose for `context`, or nil: no set (the employee is shown at rest), a context the set does not cover, or a
	pose name the set lacks.
]=]
function EmployeePoseRules.select(
	set: EmployeePoseRegistry.PortraitSet?,
	context: EmployeePoseRegistry.PortraitContext,
	facts: Facts
): EmployeePoseRegistry.PoseDef?
	if set == nil then
		return nil
	end
	local entry = set.contexts[context]
	if entry == nil then
		return nil
	end
	local grades = entry.byGrade
	local name = (if grades ~= nil and facts.grade ~= nil then grades[facts.grade] else nil)
		or byLevel(entry.byLevel, facts.level)
		or entry.pose
	return set.poses[name]
end

return EmployeePoseRules
