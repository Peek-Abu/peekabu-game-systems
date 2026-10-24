--!strict
--[=[
	CharacterPickViewModel: the first-join pick screen's values: a card per employee (the free one first: "Free!" or
	its hire price), the main button (Start as an employee you own; Hire for their Credits price when you can afford
	it; otherwise how many more Credits you need), and when the screen opens (the loadout has synced, the pick is not
	made, the player is in the depot). Every employee comes from the catalogue; nothing is per character.

	@class CharacterPickViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

type Owns = (id: string) -> boolean

export type Card = {
	id: string,
	name: string,
	locked: boolean,
	selected: boolean,
	-- "Free!" or the hire price.
	tag: string,
}

-- `kind`: start as the selected employee, or hire them first (a Credits purchase through the Shop).
export type Start = { text: string, enabled: boolean, kind: "start" | "hire" | "none" }

local VM = {
	SCENE = "characterPick",
	DEFAULT = CosmeticConstants.DEFAULT_EMPLOYEE,
}

function VM.cards(owns: Owns, selected: string): { Card }
	local cards: { Card } = {}
	local price: { [string]: number } = {}
	for _, id in CosmeticRegistry.employees() do
		local item = CosmeticRegistry.get(id)
		if item ~= nil then
			price[id] = item.price or 0
			table.insert(cards, {
				id = id,
				name = item.name,
				locked = not owns(id),
				selected = id == selected,
				tag = if item.source == "default" or item.price == nil
					then "Free!"
					else ToonStyleViewModel.grouped(item.price),
			})
		end
	end
	table.sort(cards, function(a: Card, b: Card): boolean
		if price[a.id] ~= price[b.id] then
			return price[a.id] < price[b.id]
		end
		return a.id < b.id
	end)
	return cards
end

function VM.start(selected: string, owns: Owns, credits: number): Start
	local item = CosmeticRegistry.get(selected)
	if owns(selected) then
		return { text = `Start as {if item ~= nil then item.name else selected}!`, enabled = true, kind = "start" }
	end
	local price = if item ~= nil then item.price else nil
	if price == nil then
		return { text = "Coming later", enabled = false, kind = "none" }
	end
	if credits >= price then
		return { text = `Hire for {ToonStyleViewModel.grouped(price)}`, enabled = true, kind = "hire" }
	end
	return {
		text = `Need {ToonStyleViewModel.grouped(price - credits)} more Credits`,
		enabled = false,
		kind = "none",
	}
end

--[=[
	Whether the pick screen should be up: the loadout has arrived from the server (`synced`; before that the client
	holds a placeholder that always says not picked), the pick is not made and the player is in the depot.
]=]
function VM.shouldOpen(loadout: CosmeticTypes.Loadout, synced: boolean, inDepot: boolean): boolean
	return synced and inDepot and not loadout.picked
end

return VM
