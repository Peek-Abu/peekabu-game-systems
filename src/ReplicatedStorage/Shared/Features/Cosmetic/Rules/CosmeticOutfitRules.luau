--!strict
--[=[
	CosmeticOutfitRules: everything one player wears, in one place (the owner's "who am I right now" utility). Every
	place that shows or builds a player's employee reads its Outfit from here: the employee, their look (skin, style,
	idle, emote wheel), the vacuum (one for the whole crew) and the sticker slots, with every fallback applied
	(CosmeticRules), so a preview and the real character always agree.

	- `current(loadout, owns)`: what the player wears now.
	- `tryOn(outfit, id)`: the same outfit with one item swapped in (a vacuum, a skin, an idle or an employee), for
	  previews of things not worn or not owned yet. Anything it can't wear leaves the outfit as it was.
	- `skinKey` / `vacuumKey`: the art registries' keys (EmployeeRegistry skins, VacuumSkinRegistry).
	Rank is not a cosmetic: the preview reads it from the live character (its lanyard).

	@class CosmeticOutfitRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)

type Outfit = CosmeticTypes.Outfit
type Loadout = CosmeticTypes.Loadout
type Owns = (id: string) -> boolean

local CosmeticOutfitRules = {}

local function copy(outfit: Outfit): Outfit
	return {
		employee = outfit.employee,
		look = {
			skin = outfit.look.skin,
			style = outfit.look.style,
			idle = outfit.look.idle,
			wheel = table.clone(outfit.look.wheel),
		},
		vacuum = outfit.vacuum,
		stickers = table.clone(outfit.stickers),
	}
end

-- A fresh look for `employee` in their free items (a try-on that changes who you are).
local function freshLook(employee: string): CosmeticTypes.Look
	local wheel = CosmeticConstants.emptyWheel()
	wheel[1] = CosmeticRegistry.defaultOf(employee, "emote").id
	return {
		skin = CosmeticRegistry.defaultOf(employee, "skin").id,
		style = 1,
		idle = CosmeticRegistry.defaultOf(employee, "idle").id,
		wheel = wheel,
	}
end

function CosmeticOutfitRules.current(loadout: Loadout, owns: Owns): Outfit
	local employee = CosmeticRules.currentEmployee(loadout, owns)
	local stickers: { string } = table.clone(loadout.stickers)
	return {
		employee = employee,
		look = CosmeticRules.lookFor(loadout, employee, owns),
		vacuum = CosmeticRules.vacuumFor(loadout, owns),
		stickers = stickers,
	}
end

function CosmeticOutfitRules.tryOn(outfit: Outfit, id: string): Outfit
	local result = copy(outfit)
	local item = CosmeticRegistry.get(id)
	if item == nil then
		return result
	end
	if item.kind == "vacuum" then
		result.vacuum = id
	elseif item.kind == "employee" then
		if result.employee ~= id then
			result.employee = id
			result.look = freshLook(id)
		end
	elseif item.kind == "skin" then
		local employee = item.employee
		if employee ~= nil then
			if result.employee ~= employee then
				result.employee = employee
				result.look = freshLook(employee)
			end
			result.look.skin = id
			result.look.style = 1
		end
	elseif item.kind == "idle" then
		local employee = item.employee
		if employee ~= nil and employee ~= result.employee then
			result.employee = employee
			result.look = freshLook(employee)
		end
		result.look.idle = id
	end
	return result
end

-- The employee's EmployeeRegistry skin key ("Pippa.OwnerSpecial" -> "OwnerSpecial").
function CosmeticOutfitRules.skinKey(outfit: Outfit): string
	return CosmeticRegistry.keyOf(outfit.look.skin)
end

-- The VacuumSkinRegistry key ("Vacuum.BrassBellows" -> "BrassBellows").
function CosmeticOutfitRules.vacuumKey(outfit: Outfit): string
	return CosmeticRegistry.keyOf(outfit.vacuum)
end

return CosmeticOutfitRules
