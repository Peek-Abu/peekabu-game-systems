--!strict
--[=[
	occupantturn: a developer's repro of the Manager's slow turns (behaviours design §11). Forces his next head turn to
	a variant ("snap", "knowing", "stare"; "auto" clears it) through OccupantServiceServer:forceTurn; when he can see
	the caller, the turn starts at once at them. Admins only (the Admins group fails closed in AdminServiceServer).
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)

local VARIANTS: { [string]: OccupantTypes.TurnKind | "auto" } =
	{ snap = "snap", knowing = "knowing", stare = "stare", auto = "auto" }

return function(context: { Executor: Player }, variant: string)
	local kind: (OccupantTypes.TurnKind | "auto")? = VARIANTS[string.lower(variant)]
	if kind == nil then
		return `Unknown variant "{variant}": use snap, knowing, stare or auto.`
	end
	local ok, message = OccupantServiceServer:forceTurn(context.Executor, kind)
	if not ok then
		return `Nothing forced: {message}.`
	end
	if kind == "auto" then
		return "The Manager's head turns are back to their own choice."
	end
	return `The Manager's next head turn is the {kind}. Stand where he can see you to start it now, or wait for one.`
end
