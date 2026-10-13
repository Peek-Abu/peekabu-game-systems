--!strict
--[=[
	EmployeeFaceRules: which expression an employee shows, from what the server knows.

	- Worried: the Manager is chasing (or catching) this player, at any distance; or he is within
	  WORRIED_RADIUS and alert (investigating a noise, chasing someone, searching, catching). Being worried
	  beats everything.
	- Happy: vacuuming, carrying something in the hands, or holding cargo in the pockets; and for
	  HAPPY_LINGER seconds after the last of those (so banking a haul, which empties the pockets, still
	  reads as a happy moment).
	- Content: otherwise.

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
	@param lastBusyAt When the player was last busy (same clock as `now`), nil if never.
]=]
function EmployeeFaceRules.decide(threatened: boolean, busy: boolean, now: number, lastBusyAt: number?): EmployeeRegistry.Face
	if threatened then
		return "Worried"
	end
	if busy or (lastBusyAt ~= nil and now - lastBusyAt <= EmployeeConstants.HAPPY_LINGER) then
		return "Happy"
	end
	return "Content"
end

return EmployeeFaceRules
