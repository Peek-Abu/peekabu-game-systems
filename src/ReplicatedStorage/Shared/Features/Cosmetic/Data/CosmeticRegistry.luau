--!strict
--[=[
	CosmeticRegistry: the catalogue of everything a player can own and wear in Odd Hours (employees, skins, idles,
	emotes, sticker packs and their stickers), looked up by id. Requirements: characters/launch/new-employee-requirements.md;
	design: docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md.

	Ids: `<Employee>.<Name>` for an item that belongs to one employee, a plain name for a shared one, a sticker
	`<Pack>.<Name>`. At load every item but a sticker is registered in EntitlementRegistry under its kind as the
	category, so ownership is the existing `entitlements` slice; a sticker is owned through its pack. Prices and lore
	are first drafts (owner: prices may change).

	The lists live in CosmeticEmployeeRegistry (employees, their defaults, skins and emotes) and CosmeticStickerRegistry
	(sticker packs and stickers); the vacuums and shared idles stay here.

	Art and animation ids are NOT here yet: the rig facts stay in EmployeeRegistry (step 2 wires skins to palettes).

	@class CosmeticRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CosmeticEmployeeRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticEmployeeRegistry)
local CosmeticStickerRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticStickerRegistry)
local EntitlementRegistry = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementRegistry)

type Item = CosmeticTypes.Item
type Kind = CosmeticTypes.Kind

-- The items shared by the whole crew: the vacuums and the shared idles.
local SHARED: { Item } = {
	-- Vacuums (one for the whole crew; the part after the dot is the VacuumSkinRegistry skin)
	{
		id = "Vacuum.StandardIssue",
		kind = "vacuum",
		name = "Standard Issue",
		rarity = "default",
		source = "default",
		lore = "The company vacuum. It is teal, it is loud, and it never gives up.",
	},
	{
		id = "Vacuum.BrassBellows",
		kind = "vacuum",
		name = "Brass Bellows",
		rarity = "rare",
		source = "gleam",
		price = 600,
		lore = "A brass vacuum under a glass dome. Nobody knows how old it is. The gauges still work. Mostly.",
	},

	-- Shared idles
	{
		id = "SleepySway",
		kind = "idle",
		name = "Sleepy Sway",
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Night shifts are long. A tiny nap standing up never hurt anybody.",
	},
}

-- The catalogue, in its order: the employees' items, the shared ones, then the stickers.
local ITEMS: { Item } = {}
for _, list in { CosmeticEmployeeRegistry, SHARED, CosmeticStickerRegistry } do
	table.move(list, 1, #list, #ITEMS + 1, ITEMS)
end

local byId: { [string]: Item } = {}
local sorted: { Item } = {}
for _, item in ITEMS do
	assert(byId[item.id] == nil, `CosmeticRegistry: duplicate id {item.id}`)
	local frozen = table.freeze(item)
	byId[item.id] = frozen
	table.insert(sorted, frozen)
	if item.kind ~= "sticker" and not EntitlementRegistry.has(item.kind, item.id) then
		EntitlementRegistry.register(item.kind, item.id, { name = item.name })
	end
end
table.sort(sorted, function(a, b)
	return a.id < b.id
end)
table.freeze(sorted)

local CosmeticRegistry = {
	-- Everyone's vacuum until they wear another.
	DEFAULT_VACUUM = "Vacuum.StandardIssue",
}

-- The art key after an id's first dot ("Pippa.OwnerSpecial" -> "OwnerSpecial", "Vacuum.BrassBellows" ->
-- "BrassBellows"); an id with no dot is its own key.
function CosmeticRegistry.keyOf(id: string): string
	return string.match(id, "^[^%.]+%.(.+)$") or id
end

function CosmeticRegistry.get(id: string): Item?
	return byId[id]
end

function CosmeticRegistry.has(id: string): boolean
	return byId[id] ~= nil
end

-- Every item, sorted by id.
function CosmeticRegistry.all(): { Item }
	return sorted
end

--[=[
	The items of `kind`; with `employee`, only that employee's and the shared ones (employee nil).
]=]
function CosmeticRegistry.ofKind(kind: Kind, employee: string?): { Item }
	local list: { Item } = {}
	for _, item in sorted do
		if item.kind == kind and (employee == nil or item.employee == nil or item.employee == employee) then
			table.insert(list, item)
		end
	end
	return list
end

-- The employee ids, sorted.
function CosmeticRegistry.employees(): { string }
	local list: { string } = {}
	for _, item in sorted do
		if item.kind == "employee" then
			table.insert(list, item.id)
		end
	end
	return list
end

--[=[
	The employee's free item of `kind` (its Classic skin, idle or default emote). Errors when there is none: the
	registry spec guarantees one each.
]=]
function CosmeticRegistry.defaultOf(employee: string, kind: Kind): Item
	for _, item in sorted do
		if item.kind == kind and item.employee == employee and item.source == "default" then
			return item
		end
	end
	error(`CosmeticRegistry: {employee} has no default {kind}`)
end

return CosmeticRegistry
