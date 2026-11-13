--!strict
--[=[
	EmployeeSkinRules: which skin a character wears, whether its palette is usable, and which idle and fidget it plays
	(the same in menus and in a shift: owner, 2026-11-03).

	@class EmployeeSkinRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- The skin fields `select` reads (an EmployeeDef has them).
export type SkinSet = {
	skins: { [string]: EmployeeRegistry.SkinDef },
	defaultSkin: string,
}

-- The fields `idleOf` / `fidgetOf` read (an EmployeeDef has them).
export type LocomotionSet = {
	skins: { [string]: EmployeeRegistry.SkinDef },
	idles: { [string]: string }?,
	locomotion: EmployeeRegistry.LocomotionDef?,
}

-- The skin whose showcase idle the idle item `idleKey` plays (nil = no such item, or its skin has no idle).
local function idleSkin(def: LocomotionSet, idleKey: string?): EmployeeRegistry.SkinDef?
	local idles = def.idles
	local skinKey = if idleKey ~= nil and idles ~= nil then idles[idleKey] else nil
	local skin = if skinKey ~= nil then def.skins[skinKey] else nil
	return if skin ~= nil and skin.showcaseIdle ~= nil then skin else nil
end

-- What a character was built as: its employee, skin key and colour style (EmployeeServiceServer).
export type Worn = {
	employee: string,
	skin: string,
	style: number,
}

local EmployeeSkinRules = {}

--[=[
	Whether a character built as `current` must be rebuilt to wear `employee` / `skin` / `style`: any of the three
	changed, or nothing is worn yet. A style-only change rebuilds too (the outfit's looks and the body palette change).
]=]
function EmployeeSkinRules.wornChanged(current: Worn?, employee: string, skin: string, style: number): boolean
	return current == nil or current.employee ~= employee or current.skin ~= skin or current.style ~= style
end

--[=[
	The AnimationRegistry key of the idle loop a character or preview wearing `skinKey` plays: the chosen idle item's
	(`idleKey`, the key after the dot; nil or unknown = the skin's own), else the skin's own showcase idle when it has
	one, else the employee's idle; nil for an employee without its own locomotion. Whether an idle fits the skin is
	CosmeticRules.idleFits: the caller passes only an idle that does.
]=]
function EmployeeSkinRules.idleOf(def: LocomotionSet, skinKey: string?, idleKey: string?): string?
	local chosen = idleSkin(def, idleKey)
	if chosen ~= nil then
		return chosen.showcaseIdle
	end
	local skin = if skinKey ~= nil then def.skins[skinKey] else nil
	if skin ~= nil and skin.showcaseIdle ~= nil then
		return skin.showcaseIdle
	end
	local locomotion = def.locomotion
	return if locomotion ~= nil then locomotion.idle else nil
end

--[=[
	The AnimationRegistry key of the fidget that goes with `idleOf`: a skin with a showcase idle has its own fidget or
	none (the employee's would not fit that idle); any other skin plays the employee's. nil = no fidget.
]=]
function EmployeeSkinRules.fidgetOf(def: LocomotionSet, skinKey: string?, idleKey: string?): string?
	local chosen = idleSkin(def, idleKey)
	if chosen ~= nil then
		return chosen.showcaseFidget
	end
	local skin = if skinKey ~= nil then def.skins[skinKey] else nil
	if skin ~= nil and skin.showcaseIdle ~= nil then
		return skin.showcaseFidget
	end
	local locomotion = def.locomotion
	return if locomotion ~= nil then locomotion.fidget else nil
end

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
	The colour style a player's `wanted` style resolves to: itself when the skin has that style, else 1 (nil, 0, past
	the end, or not a whole number). 1 for a skin with no styles.
]=]
function EmployeeSkinRules.styleIndex(skin: EmployeeRegistry.SkinDef, wanted: number?): number
	local styles = skin.styles
	if styles ~= nil and wanted ~= nil and wanted == math.floor(wanted) and styles[wanted] ~= nil then
		return wanted
	end
	return 1
end

--[=[
	The skin's colour style for `wanted` (clamped by `styleIndex`); nil for a skin with no styles.
]=]
function EmployeeSkinRules.style(skin: EmployeeRegistry.SkinDef, wanted: number?): EmployeeRegistry.StyleDef?
	local styles = skin.styles
	if styles == nil then
		return nil
	end
	return styles[EmployeeSkinRules.styleIndex(skin, wanted)]
end

--[=[
	Whether the skin has real colour styles to pick between (more than one with art): only then does the UI show a
	style row.
]=]
function EmployeeSkinRules.hasStyles(skin: EmployeeRegistry.SkinDef): boolean
	local styles = skin.styles
	return styles ~= nil and #styles > 1
end

--[=[
	The real colour styles of `employee`'s skin `skinKey` (a catalogue skin id after the dot), in order: what the Shop
	and the locker show as chips. Empty when the skin has fewer than two styles with art, or is not registered.
]=]
function EmployeeSkinRules.stylesFor(employee: string?, skinKey: string): { EmployeeRegistry.StyleDef }
	local def = if employee ~= nil then EmployeeRegistry.get(employee) else nil
	local skin = if def ~= nil then def.skins[skinKey] else nil
	if skin == nil or not EmployeeSkinRules.hasStyles(skin) then
		return {}
	end
	return skin.styles or {}
end

--[=[
	The body palette texture id the skin gives the character, when it is a well-formed asset id: a styled skin's
	`style` palette (each style recolours the body), else the skin's own. nil when the art is pending, the id is
	malformed, or the style has no palette (an outfit over the body's own palettes): applying the skin then leaves the
	palette alone.
]=]
function EmployeeSkinRules.palette(skin: EmployeeRegistry.SkinDef, style: number?): string?
	local styleDef = EmployeeSkinRules.style(skin, style)
	if styleDef ~= nil then
		return wellFormed(styleDef.paletteTextureId)
	end
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
