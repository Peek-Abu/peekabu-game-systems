--!strict
--[=[
	CosmeticDevPickRules: the Studio-only first-join pick skip (CosmeticConstants.DEV_PICK_ATTRIBUTE). With the
	Workspace attribute set to a registered employee's name, in Studio only, the server picks that employee for every
	player who has not picked yet (through CosmeticServiceServer:pick, the same path a real click takes, so it still
	refuses an employee the player does not own) and the client skips that pick's "You're hired!" reveal. Off by default;
	outside Studio it is never on, whatever the attribute says.

	@class CosmeticDevPickRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- The grant source of a first-join pick (CosmeticServiceServer announces it).
local PICK_SOURCE = "pick"

local CosmeticDevPickRules = {}

--[=[
	The employee to pick for players who have not picked, or nil when the skip is off: not in Studio, no attribute,
	or not a registered employee's name.
]=]
function CosmeticDevPickRules.employee(isStudio: boolean, attribute: unknown): string?
	if not isStudio or type(attribute) ~= "string" or attribute == "" then
		return nil
	end
	return if EmployeeRegistry.get(attribute) ~= nil then attribute else nil
end

--[=[
	Whether the client skips a grant's reveal: only the pick's, only while the skip is on.
]=]
function CosmeticDevPickRules.skipsReveal(isStudio: boolean, attribute: unknown, source: string): boolean
	return source == PICK_SOURCE and CosmeticDevPickRules.employee(isStudio, attribute) ~= nil
end

return CosmeticDevPickRules
