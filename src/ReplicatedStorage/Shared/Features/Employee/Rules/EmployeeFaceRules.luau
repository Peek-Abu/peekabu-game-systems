--!strict
--[=[
	EmployeeFaceRules: which expression an employee shows, in two steps.

	1. The gameplay state, from what the server knows (`stateOf`):
	   - threatened: the Manager is chasing (or catching) this player, at any distance; or he is within
	     WORRIED_RADIUS and alert (investigating a noise, chasing someone, searching, catching). Beats
	     everything.
	   - cleaning: vacuuming, plus a CLEANING_LINGER tail so gaps between sweeps do not flicker.
	   - carrying: something in the hands, or cargo in the pockets.
	   - idle: otherwise.
	2. The face, from the employee's own mapping (`faceFor`, EmployeeRegistry `expressions`): employees
	   differ, so no state is hard-wired to an expression here.

	@class EmployeeFaceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

local ALERT_MODES: { [OccupantTypes.Mode]: boolean } = {
	investigate = true,
	chase = true,
	search = true,
	catch = true,
}

-- The mapping `faceFor` reads (an EmployeeDef has it).
export type Expressive = {
	expressions: { [EmployeeRegistry.GameplayState]: EmployeeRegistry.Face },
}

local EmployeeFaceRules = {}

--[=[
	@param mode The Manager's current mode, nil when there is no Manager.
	@param targetsMe Whether the Manager's target is this player.
	@param distance Studs between the Manager and this player, nil when unknown.
]=]
function EmployeeFaceRules.isThreatened(mode: OccupantTypes.Mode?, targetsMe: boolean, distance: number?): boolean
	if mode == nil then
		return false
	end
	if targetsMe and (mode == "chase" or mode == "catch") then
		return true
	end
	return distance ~= nil and distance <= EmployeeConstants.WORRIED_RADIUS and ALERT_MODES[mode] == true
end

--[=[
	Vacuuming now, or within CLEANING_LINGER of the last moment the vacuum ran.
	@param lastVacuumAt When the player last vacuumed (same clock as `now`), nil if never.
]=]
function EmployeeFaceRules.isCleaning(vacuuming: boolean, now: number, lastVacuumAt: number?): boolean
	return vacuuming or (lastVacuumAt ~= nil and now - lastVacuumAt <= EmployeeConstants.CLEANING_LINGER)
end

--[=[
	The gameplay state a face is chosen for. Threatened beats cleaning beats carrying.
	@param carrying Cargo in the hands (Carry) or in the pockets (Cargo).
]=]
function EmployeeFaceRules.stateOf(
	threatened: boolean,
	cleaning: boolean,
	carrying: boolean
): EmployeeRegistry.GameplayState
	if threatened then
		return "threatened"
	elseif cleaning then
		return "cleaning"
	elseif carrying then
		return "carrying"
	end
	return "idle"
end

-- The face this employee shows in `state` (its own mapping, EmployeeRegistry `expressions`).
function EmployeeFaceRules.faceFor(def: Expressive, state: EmployeeRegistry.GameplayState): EmployeeRegistry.Face
	return def.expressions[state]
end

return EmployeeFaceRules
