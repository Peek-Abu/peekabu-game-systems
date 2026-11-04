--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeService = require(ServerScriptService.Features.Employee.EmployeeServiceServer)

type Stat = EmployeeProfileRegistry.Stat

-- The stats a name stands for ("all" = every stat); nil for an unknown name.
local function statsFor(name: string): { Stat }?
	local wanted = string.lower(name)
	if wanted == "all" then
		return table.clone(EmployeeProfileRegistry.STATS)
	end
	for _, stat: Stat in EmployeeProfileRegistry.STATS do
		if stat == wanted then
			return { stat }
		end
	end
	return nil
end

return function(context: { Executor: Player }, statName: string, barsText: string, target: Player?)
	local player = target or context.Executor
	local stats = statsFor(statName)
	if stats == nil then
		return `Unknown stat "{statName}": speed, stamina, strength, suction, quiet or all.`
	end
	local reset = string.lower(barsText) == "reset"
	local bars = tonumber(barsText)
	if not reset and (bars == nil or bars ~= math.floor(bars) or bars < 1 or bars > 5) then
		return `Bars must be 1 to 5, or reset (got "{barsText}").`
	end
	local value = if reset then nil else bars
	local rebuilt, reason = EmployeeService:overrideStats(player, stats, value)
	local what = if reset then "reset to their own" else `set to {barsText}`
	if rebuilt then
		return `{player.Name}'s {string.lower(statName)} {what}; rebuilt where they stand.`
	end
	return `{player.Name}'s {string.lower(statName)} {what}, but not rebuilt now: {reason or "?"}.`
end
