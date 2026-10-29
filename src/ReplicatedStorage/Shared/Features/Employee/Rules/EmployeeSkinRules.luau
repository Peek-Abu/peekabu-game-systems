--!strict
--[=[
	EmployeeSkinRules: which skin a character wears, and whether its palette is usable.

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
	@param wanted The skin key the player wears (their loadout's skin id after the dot), nil for none.
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

local function wellFormed(id: string?): string?
	if id ~= nil and string.match(id, "^rbxassetid://%d+$") ~= nil then
		return id
	end
	return nil
end

--[=[
	The skin's palette texture id when it is a well-formed asset id; nil when the art is pending or the id
	is malformed (applying the skin then leaves the palette alone).
]=]
function EmployeeSkinRules.palette(skin: EmployeeRegistry.SkinDef): string?
	return wellFormed(skin.paletteTextureId)
end

--[=[
	The palette texture id the skin gives clothing piece `piece`, when it gives one and it is well-formed; nil keeps
	the piece's own palette.
]=]
function EmployeeSkinRules.piecePalette(skin: EmployeeRegistry.SkinDef, piece: string): string?
	local palettes = skin.piecePalettes
	return if palettes ~= nil then wellFormed(palettes[piece]) else nil
end

return EmployeeSkinRules
