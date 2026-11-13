--!strict
--[=[
	DealViewModel: the one-time deals' words and lists for the shop's deal card, the chooser and the Pick Your Employee
	screen's deal button. Which deals show and what can be picked is DealRules'.

	@class DealViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

type Owns = (id: string) -> boolean
type DealId = DealConstants.DealId

export type Banner = {
	id: DealId,
	name: string,
	line: string,
	-- "R$ 399", or "Soon" until the product exists.
	price: string,
	off: string,
	buyable: boolean,
	-- Who the card shows: the employees whose Legendary skins it can give.
	faces: { { employee: string, skinKey: string? } },
}

export type Card = {
	-- What choosing it sends (a skin id, or an employee id).
	id: string,
	employee: string,
	skinKey: string?,
	title: string,
	line: string,
}

local VM = {
	SCENE = DealConstants.SCENE,
}

local function skinKeyOf(skin: string?): string?
	return if skin ~= nil then CosmeticRegistry.keyOf(skin) else nil
end

local function nameOf(id: string): string
	local item = CosmeticRegistry.get(id)
	return if item ~= nil then item.name else id
end

function VM.banner(id: DealId, productReady: boolean): Banner
	local deal = DealRules.deal(id)
	local faces = {}
	for _, employee in CosmeticRegistry.employees() do
		local skin = DealRules.legendaryOf(employee)
		local item = CosmeticRegistry.get(employee)
		-- New Hire shows the employees it can hire; Legendary shows every Legendary.
		if skin ~= nil and (id == "pickLegendary" or (item ~= nil and item.source ~= "default")) then
			table.insert(faces, { employee = employee, skinKey = skinKeyOf(skin) })
		end
	end
	return {
		id = id,
		name = string.upper(deal.name),
		line = deal.line,
		price = if productReady then `R$ {deal.robux}` else DealConstants.TEXT.soon,
		off = `-{deal.off}%`,
		buyable = productReady,
		faces = faces,
	}
end

function VM.cards(id: DealId, owns: Owns): { Card }
	local cards: { Card } = {}
	for _, choice in DealRules.choices(id, owns) do
		if id == "pickLegendary" then
			local item = CosmeticRegistry.get(choice)
			local employee = if item ~= nil and item.employee ~= nil then item.employee else choice
			table.insert(cards, {
				id = choice,
				employee = employee,
				skinKey = skinKeyOf(choice),
				title = nameOf(choice),
				line = "+ emote, stickers and idle",
			})
		else
			local skin = DealRules.legendaryOf(choice)
			table.insert(cards, {
				id = choice,
				employee = choice,
				skinKey = skinKeyOf(skin),
				title = nameOf(choice),
				line = if skin ~= nil then `+ {nameOf(skin)}` else "",
			})
		end
	end
	return cards
end

--[=[
	The Pick Your Employee screen's deal button for the selected employee: its words while Pick a New Hire is offered
	and can hire them (and the product exists), else nil.
]=]
function VM.hireButton(selected: string, owns: Owns, slice: PlayerDataTypes.Deals, productReady: boolean): string?
	if not productReady or not DealRules.offered("pickNewHire", slice, owns) then
		return nil
	end
	if table.find(DealRules.choices("pickNewHire", owns), selected) == nil then
		return nil
	end
	return `R$ {DealRules.deal("pickNewHire").robux} + Legendary`
end

return VM
