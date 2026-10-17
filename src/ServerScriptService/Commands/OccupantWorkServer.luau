--!strict
--[=[
	occupantwork: a developer's repro of the Manager's desk ambush. Sends him to the free desk nearest the caller, at
	least SUMMON_DISTANCE studs off (OccupantServiceServer:summonToDesk), so they can watch him sit and type, then walk
	up behind him. Admins only (the Admins group fails closed in AdminServiceServer).
]=]
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)

return function(context: { Executor: Player })
	local ok, message = OccupantServiceServer:summonToDesk(context.Executor)
	if ok then
		return `The Manager is heading to {message}. Wait for the typing, then walk up behind him (within 14 studs).`
	end
	return `Nothing sent: {message}.`
end
