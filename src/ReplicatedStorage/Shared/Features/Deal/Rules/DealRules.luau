--!strict
--[=[
	DealRules: the one-time deals' decisions (DealConstants). The `deals` account slice remembers which deals were
	bought and how many picks are not chosen yet: a receipt marks the deal bought and adds one pick in the same save
	(exactly once), and the player spends the pick in the chooser. A deal shows until it is bought, and never when
	nothing is left to pick; the chooser leaves out what the player already owns. Pure.

	- Pick a Legendary: a Legendary skin (with the rest of its bundle) of an employee the player has hired.
	- Pick a New Hire: an employee not hired yet who can be hired, granted with their Legendary skin.

	@class DealRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticBundleRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

type Owns = (id: string) -> boolean
type DealId = DealConstants.DealId
type Deals = PlayerDataTypes.Deals

local DealRules = {}

--[=[
	A new player's slice: nothing bought, no picks.
]=]
function DealRules.fresh(): Deals
	return { bought = {}, picks = {} }
end

--[=[
	The data layer's validator: only known deals; `bought` holds true; `picks` holds whole numbers 0 or more.
]=]
function DealRules.validate(value: Deals): (boolean, string?)
	if type(value.bought) ~= "table" or type(value.picks) ~= "table" then
		return false, "deals needs bought and picks tables"
	end
	for id, flag in value.bought do
		if DealRules.parseDeal(id) == nil or flag ~= true then
			return false, `deals.bought.{id} must be a known deal set to true`
		end
	end
	for id, count in value.picks do
		if DealRules.parseDeal(id) == nil or type(count) ~= "number" or count < 0 or count ~= math.floor(count) then
			return false, `deals.picks.{id} must be a known deal with a whole number, 0 or more`
		end
	end
	return true, nil
end

--[=[
	The deal `id` names. Errors on an unknown id: callers pass ids from DealConstants.ORDER or DealRules.parseDeal.
]=]
function DealRules.deal(id: DealId): DealConstants.Deal
	return assert(DealConstants.DEALS[id], `unknown deal "{id}"`)
end

--[=[
	The deal id `value` names, or nil when it is not a deal.
]=]
function DealRules.parseDeal(value: string): DealId?
	for _, id in DealConstants.ORDER do
		if id == value then
			return id
		end
	end
	return nil
end

--[=[
	The employee's Legendary skin id, or nil when they have none.
]=]
function DealRules.legendaryOf(employee: string): string?
	for _, item in CosmeticRegistry.ofKind("skin", employee) do
		if item.employee == employee and item.rarity == "legendary" then
			return item.id
		end
	end
	return nil
end

-- An employee the deal can hire: a real, paid hire (not the free one) who has a Legendary skin.
local function hireable(employee: string): boolean
	local item = CosmeticRegistry.get(employee)
	return item ~= nil and item.source ~= "default" and item.price ~= nil and DealRules.legendaryOf(employee) ~= nil
end

--[=[
	What the player can pick in `deal` now, sorted by id.
]=]
function DealRules.choices(deal: DealId, owns: Owns): { string }
	local list: { string } = {}
	if deal == "pickLegendary" then
		for _, item in CosmeticRegistry.ofKind("skin") do
			local employee = item.employee
			if item.rarity == "legendary" and employee ~= nil and owns(employee) and not owns(item.id) then
				table.insert(list, item.id)
			end
		end
	else
		for _, employee in CosmeticRegistry.employees() do
			if not owns(employee) and hireable(employee) then
				table.insert(list, employee)
			end
		end
	end
	table.sort(list)
	return list
end

--[=[
	Whether the shop shows `deal`: not bought yet, no pick waiting, and something left to pick.
]=]
function DealRules.offered(deal: DealId, slice: Deals, owns: Owns): boolean
	return slice.bought[deal] ~= true and (slice.picks[deal] or 0) == 0 and #DealRules.choices(deal, owns) > 0
end

--[=[
	The offered deals in the shop's order.
]=]
function DealRules.offeredList(slice: Deals, owns: Owns): { DealId }
	local list: { DealId } = {}
	for _, id in DealConstants.ORDER do
		if DealRules.offered(id, slice, owns) then
			table.insert(list, id)
		end
	end
	return list
end

--[=[
	The first deal with an unspent pick and something to pick (the chooser opens for it), or nil.
]=]
function DealRules.pending(slice: Deals, owns: Owns): DealId?
	for _, id in DealConstants.ORDER do
		if (slice.picks[id] or 0) > 0 and #DealRules.choices(id, owns) > 0 then
			return id
		end
	end
	return nil
end

--[=[
	A receipt's change: the deal is bought, and one more pick waits. A second receipt (bought twice before the card
	could hide) adds a second pick, so no purchase is ever lost.
]=]
function DealRules.applyPurchase(slice: Deals, deal: DealId)
	slice.bought[deal] = true
	slice.picks[deal] = (slice.picks[deal] or 0) + 1
end

--[=[
	Takes one pick away. False when there is none (the transaction then rolls back).
]=]
function DealRules.spend(slice: Deals, deal: DealId): boolean
	local count = slice.picks[deal] or 0
	if count <= 0 then
		return false
	end
	if count > 1 then
		slice.picks[deal] = count - 1
	else
		slice.picks[deal] = nil
	end
	return true
end

--[=[
	Whether the player may pick `choice` in `deal` now: a pick waits and it is one of the choices.
]=]
function DealRules.canChoose(deal: DealId, choice: string, slice: Deals, owns: Owns): (boolean, string?)
	if (slice.picks[deal] or 0) <= 0 then
		return false, "no pick waiting"
	end
	if table.find(DealRules.choices(deal, owns), choice) == nil then
		return false, "not a choice"
	end
	return true, nil
end

-- A Legendary skin and the rest of its bundle (its emote and sticker pack); the skin alone when it has no bundle.
local function withBundle(skin: string): { string }
	local bundle = CosmeticBundleRegistry.containing(skin)[1]
	if bundle == nil then
		return { skin }
	end
	local ids = { skin }
	for _, id in bundle.items do
		if id ~= skin then
			table.insert(ids, id)
		end
	end
	return ids
end

--[=[
	The cosmetic ids a choice grants: a Legendary skin comes with the rest of its bundle (CosmeticBundleRegistry), since
	a skin is granted alone; a New Hire is the employee and their Legendary skin's bundle.
]=]
function DealRules.grants(deal: DealId, choice: string): { string }
	if deal == "pickLegendary" then
		return withBundle(choice)
	end
	local skin = DealRules.legendaryOf(choice)
	if skin == nil then
		return { choice }
	end
	local ids = { choice }
	for _, id in withBundle(skin) do
		table.insert(ids, id)
	end
	return ids
end

return DealRules
