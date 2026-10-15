--!strict
--[=[
	EmployeeSkinRules: which skin a character wears, whether its palette is usable, and its ID-card photo.

	@class EmployeeSkinRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- The skin fields `select` reads (an EmployeeDef has them).
export type SkinSet = {
	skins: { [string]: EmployeeRegistry.SkinDef },
	defaultSkin: string,
}

local EmployeeSkinRules = {}

--[=[
	The player's skin when the employee has it, else the employee's default skin; nil only when the
	default skin itself is missing.
	@param wanted The player's skin name (EmployeeSkinRegistry.skinFor), nil for none.
]=]
function EmployeeSkinRules.select(def: SkinSet, wanted: string?): EmployeeRegistry.SkinDef?
	if wanted ~= nil then
		local skin = def.skins[wanted]
		if skin ~= nil then
			return skin
		end
	end
	return def.skins[def.defaultSkin]
end

--[=[
	The skin's palette texture id when it is a well-formed asset id; nil when the art is pending or the id
	is malformed (applying the skin then leaves the palette alone).
]=]
function EmployeeSkinRules.palette(skin: EmployeeRegistry.SkinDef): string?
	local id = skin.paletteTextureId
	if id ~= nil and string.match(id, "^rbxassetid://%d+$") ~= nil then
		return id
	end
	return nil
end

--[=[
	The ID-card photo for `skin`: its own portrait when it is a well-formed asset id, else the employee's.
]=]
function EmployeeSkinRules.portrait(def: { portrait: string }, skin: EmployeeRegistry.SkinDef): string
	local id = skin.portrait
	if id ~= nil and string.match(id, "^rbxassetid://%d+$") ~= nil then
		return id
	end
	return def.portrait
end

return EmployeeSkinRules
