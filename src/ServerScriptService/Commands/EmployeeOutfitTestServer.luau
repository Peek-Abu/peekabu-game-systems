--!strict
--[[
	employeeoutfittest: fits a skinned outfit Model from EmployeeConstants.OUTFITS_PATH onto a player's current
	character (EmployeeOutfitSystem.fit, no colour style), so a test outfit can be worn in Play without being a
	registered skin, sold or shown anywhere. Admins only (Cmdr's fail-closed allowlist).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeOutfitSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeOutfitSystem)

local function outfitNamed(name: string): Model?
	local node: Instance? = ReplicatedStorage
	for _, step in EmployeeConstants.OUTFITS_PATH do
		node = if node ~= nil then node:FindFirstChild(step) else nil
	end
	local found = if node ~= nil then node:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") then found else nil
end

type Context = { Executor: Player }

return function(context: Context, outfitName: string, target: Player?)
	local who = target or context.Executor
	local outfit = outfitNamed(outfitName)
	if outfit == nil then
		return `There is no outfit "{outfitName}" in this place.`
	end
	local character = who.Character
	if character == nil then
		return `{who.Name} has no character.`
	end
	if EmployeeOutfitSystem.fit(character, outfit, nil) then
		return `{who.Name} now wears the outfit "{outfitName}" (until a respawn or skin change).`
	end
	return `The outfit "{outfitName}" was refused for {who.Name}'s character (see EmployeeOutfitSystem.fit).`
end
