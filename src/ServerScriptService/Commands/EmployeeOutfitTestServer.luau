--!strict
--[[
	employeeoutfittest: fits a skinned outfit Model from EmployeeConstants.OUTFITS_PATH onto a player's current
	character (EmployeeOutfitSystem.fit, no colour style), so a test outfit can be worn in Play without being a
	registered skin, sold or shown anywhere. Admins only (Cmdr's fail-closed allowlist).

	Mode "solo" shows only the outfit's new pieces (the Outfit meshes its SoloMeshes attribute names) on the plain
	body: every other outfit mesh is hidden and the body parts its HideParts covered are shown again, so a new piece
	can be judged without the pieces it is layered over.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeOutfitSystem = require(ReplicatedStorage.Shared.Features.Employee.Systems.EmployeeOutfitSystem)

local SOLO_ATTRIBUTE = "SoloMeshes"

local function outfitNamed(name: string): Model?
	local node: Instance? = ReplicatedStorage
	for _, step in EmployeeConstants.OUTFITS_PATH do
		node = if node ~= nil then node:FindFirstChild(step) else nil
	end
	local found = if node ~= nil then node:FindFirstChild(name) else nil
	return if found ~= nil and found:IsA("Model") then found else nil
end

-- The comma-separated names in `outfit`'s string attribute `attribute` (empty when unset).
local function namesIn(outfit: Model, attribute: string): { string }
	local value = outfit:GetAttribute(attribute)
	local names: { string } = {}
	if type(value) == "string" then
		for name in string.gmatch(value, "[^,%s]+") do
			table.insert(names, name)
		end
	end
	return names
end

-- Hides every fitted outfit mesh not in `keep` and shows the body parts the outfit had covered.
local function showSolo(character: Model, outfit: Model, keep: { string })
	local folder = character:FindFirstChild(EmployeeConstants.OUTFIT_FOLDER)
	if folder ~= nil then
		for _, mesh in folder:GetChildren() do
			if mesh:IsA("BasePart") then
				mesh.Transparency = if table.find(keep, mesh.Name) ~= nil then 0 else 1
			end
		end
	end
	for _, name in namesIn(outfit, EmployeeConstants.HIDE_PARTS_ATTRIBUTE) do
		local part = character:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			part.Transparency = 0
		end
	end
end

type Context = { Executor: Player }

return function(context: Context, outfitName: string, mode: string?, target: Player?)
	local who = target or context.Executor
	if mode ~= nil and mode ~= "solo" and mode ~= "all" then
		return `Unknown mode "{mode}" (all, or solo for only the outfit's new pieces).`
	end
	local outfit = outfitNamed(outfitName)
	if outfit == nil then
		return `There is no outfit "{outfitName}" in this place.`
	end
	local keep = namesIn(outfit, SOLO_ATTRIBUTE)
	if mode == "solo" and #keep == 0 then
		return `The outfit "{outfitName}" names no new pieces (its {SOLO_ATTRIBUTE} attribute), so solo has nothing to show.`
	end
	local character = who.Character
	if character == nil then
		return `{who.Name} has no character.`
	end
	if not EmployeeOutfitSystem.fit(character, outfit, nil) then
		return `The outfit "{outfitName}" was refused for {who.Name}'s character (see EmployeeOutfitSystem.fit).`
	end
	if mode == "solo" then
		showSolo(character, outfit, keep)
		return `{who.Name} now wears only the new pieces of "{outfitName}" ({table.concat(keep, ", ")}) on the plain body.`
	end
	return `{who.Name} now wears the outfit "{outfitName}" (until a respawn or skin change).`
end
