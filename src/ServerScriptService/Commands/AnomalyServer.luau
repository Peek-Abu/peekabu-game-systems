--!strict
--[=[
	anomaly: a developer's repro of the run's exterior anomalies. `<id>` forces exactly that one anomaly, `none` clears
	them all and `reroll` restores the seed's pick, through OfficeServiceServer:forceAnomalies (the published
	attribute the client reads). A rebuild drops a forced set. Admins only (the Admins group fails closed in
	AdminServiceServer).
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)

return function(_context: { Executor: Player }, choice: string)
	local word = string.lower(choice)
	local ids: { OfficeAnomalyConstants.AnomalyId }? = nil
	local summary = "The run's own anomalies are back."
	if word == "none" then
		ids = {}
		summary = "No anomalies this run."
	elseif word ~= "reroll" then
		local found: OfficeAnomalyConstants.AnomalyId? = nil
		for _, id in OfficeAnomalyConstants.IDS do
			if string.lower(id) == word then
				found = id
			end
		end
		if found == nil then
			return `Unknown anomaly "{choice}": use {table.concat(OfficeAnomalyConstants.IDS, ", ")}, none or reroll.`
		end
		ids = { found }
		summary = `Only {found} this run.`
	end
	if not OfficeServiceServer:forceAnomalies(ids) then
		return "Nothing changed: no office stands."
	end
	return summary
end
