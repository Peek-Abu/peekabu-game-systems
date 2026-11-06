--!strict
--[=[
	occupantstage (alias harlow): a filmmaker's staging of Mr. Harlow for a shot (OccupantServiceServer:stage, OccupantStageRules). Admins only
	(the Admins group fails closed in AdminServiceServer).
]=]
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local OccupantStageRules = require(ServerScriptService.Features.Occupant.Rules.OccupantStageRules)

return function(context: { Executor: Player }, action: string, target: Player?)
	local parsed: OccupantStageRules.Action? = OccupantStageRules.parse(action)
	if parsed == nil then
		return `Unknown action "{action}". Use one of: {table.concat(OccupantStageRules.ACTION_NAMES, ", ")}.`
	end
	if OccupantStageRules.needsTarget(parsed) and target == nil then
		return `Name the player too, e.g. harlow {parsed} PlayerName.`
	end
	local ok, message = OccupantServiceServer:stage(context.Executor, parsed, target)
	if ok then
		return `Harlow: {message}.`
	end
	return `Nothing done: {message}.`
end
