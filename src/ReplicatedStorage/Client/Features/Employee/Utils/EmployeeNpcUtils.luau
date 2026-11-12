--!strict
--[=[
	EmployeeNpcUtils: a local, non-player copy of an employee for the hub's characters (the Supply Counter clerk, the
	Training coach). Players spawn at their employee's `scale` (EmployeeRegistry; the server's EmployeeSpawnSystem.scale),
	so an NPC cloned straight from the template stood a size smaller than every player beside it (owner 11-11). The copy
	is scaled the same way and returned unparented, for the caller to place.

	@class EmployeeNpcUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

local EmployeeNpcUtils = {}

local function source(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crew = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local characters = if crew ~= nil then crew:FindFirstChild("Characters") else nil
	local found = if characters ~= nil then characters:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") then found else nil
end

--[=[
	A copy of employee `name`'s character at the size players spawn at; nil without its art.
]=]
function EmployeeNpcUtils.clone(name: string): Model?
	local template = source(name)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	local def = EmployeeRegistry.get(name)
	if def ~= nil and def.scale ~= 1 then
		model:ScaleTo(model:GetScale() * def.scale)
	end
	return model
end

return EmployeeNpcUtils
