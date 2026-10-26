--!strict
--[=[
	LockerRules: everything a Lost & Found Locker decides, as pure functions (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	- `pool(locker)`: the catalogue items it holds (their `source` is the Locker's; stickers come with their packs).
	- `odds(locker, pool?)`: the real chances. Rarity weights come from LockerConstants; a rarity with no items in the
	  pool drops out and the rest scale up to 100%, so what the odds sheet shows is what the roll does. Items share
	  their rarity's chance evenly. The pity number is `ceil(PITY_FACTOR / chance of Epic+)` (owner: from the odds).
	- `roll(locker, pity, r1, r2, pool?)`: r1 picks the rarity, r2 the item (both 0..1, from the server's Random). The
	  open that reaches the pity number only rolls among Epic+ rarities.
	- `outcome(...)`: pity after the open (reset on any Epic+), and a duplicate's refund.
	- `checkOpen` / `checkDirect`: whether a player may open, or (restricted from paid random items) buy directly.

	@class LockerRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)

type Item = CosmeticTypes.Item
type Locker = LockerTypes.Locker
type Rarity = CosmeticTypes.Rarity

local LockerRules = {}

function LockerRules.get(id: string): Locker?
	if id == "gloom" then
		return LockerConstants.LOCKERS.gloom
	elseif id == "gleam" then
		return LockerConstants.LOCKERS.gleam
	end
	return nil
end

function LockerRules.pool(locker: Locker): { Item }
	local list = {}
	for _, item in CosmeticRegistry.all() do
		if item.source == locker.source and item.kind ~= "sticker" then
			table.insert(list, item)
		end
	end
	return list
end

local function byRarity(pool: { Item }): { [Rarity]: { Item } }
	local groups: { [Rarity]: { Item } } = {}
	for _, item in pool do
		local group = groups[item.rarity]
		if group == nil then
			group = {}
			groups[item.rarity] = group
		end
		table.insert(group, item)
	end
	for _, group in groups do
		table.sort(group, function(a: Item, b: Item): boolean
			return a.id < b.id
		end)
	end
	return groups
end

-- The rarities in the pool with their weights, worst to best (only Epic+ when `epicOnly`).
local function weighted(
	locker: Locker,
	groups: { [Rarity]: { Item } },
	epicOnly: boolean
): ({ { rarity: Rarity, weight: number } }, number)
	local list: { { rarity: Rarity, weight: number } } = {}
	local total = 0
	for index = 1, #LockerConstants.RARITY_ORDER do
		local rarity: Rarity = LockerConstants.RARITY_ORDER[index]
		local weight = locker.odds[rarity] or 0
		local group = groups[rarity]
		if
			weight > 0
			and group ~= nil
			and #group > 0
			and (not epicOnly or LockerConstants.EPIC_PLUS[rarity] == true)
		then
			table.insert(list, { rarity = rarity, weight = weight })
			total += weight
		end
	end
	return list, total
end

function LockerRules.odds(locker: Locker, pool: { Item }?): LockerTypes.Odds
	local groups = byRarity(pool or LockerRules.pool(locker))
	local list, total = weighted(locker, groups, false)
	local rarities: { LockerTypes.RarityOdds } = {}
	local epicPlus = 0
	for _, entry in list do
		local chance = entry.weight / total
		local ids = {}
		for _, item in groups[entry.rarity] do
			table.insert(ids, item.id)
		end
		table.insert(rarities, { rarity = entry.rarity, chance = chance, items = ids })
		if LockerConstants.EPIC_PLUS[entry.rarity] == true then
			epicPlus += chance
		end
	end
	return {
		rarities = rarities,
		epicPlus = epicPlus,
		pityAt = if epicPlus > 0 then math.ceil(LockerConstants.PITY_FACTOR / epicPlus) else nil,
	}
end

-- r1 picks the rarity, r2 the item. Returns the item and whether the pity guarantee forced it.
function LockerRules.roll(locker: Locker, pity: number, r1: number, r2: number, pool: { Item }?): (Item?, boolean)
	local list = pool or LockerRules.pool(locker)
	local groups = byRarity(list)
	local pityAt = LockerRules.odds(locker, list).pityAt
	local forced = pityAt ~= nil and pity + 1 >= pityAt
	local entries, total = weighted(locker, groups, forced)
	if total <= 0 then
		return nil, false
	end
	local pick = math.clamp(r1, 0, 0.999999) * total
	local chosen: Rarity = entries[#entries].rarity
	for _, entry in entries do
		if pick < entry.weight then
			chosen = entry.rarity
			break
		end
		pick -= entry.weight
	end
	local group = groups[chosen]
	local index = math.clamp(math.floor(math.clamp(r2, 0, 0.999999) * #group) + 1, 1, #group)
	-- A lucky Epic+ on the pity open still counts as the guarantee: the player was owed one.
	return group[index], forced
end

function LockerRules.refund(locker: Locker, rarity: Rarity): number
	return math.floor(locker.keyPrice * (LockerConstants.REFUND[rarity] or 0))
end

function LockerRules.outcome(
	locker: Locker,
	item: Item,
	owned: boolean,
	pity: number,
	guaranteed: boolean
): LockerTypes.Outcome
	local epicPlus = LockerConstants.EPIC_PLUS[item.rarity] == true
	return {
		locker = locker.id,
		item = item.id,
		rarity = item.rarity,
		duplicate = owned,
		refund = if owned then LockerRules.refund(locker, item.rarity) else 0,
		guaranteed = guaranteed,
		pity = if epicPlus then 0 else pity + 1,
	}
end

function LockerRules.directPrice(item: Item): number
	return LockerConstants.DIRECT_PRICE[item.rarity] or LockerConstants.DEFAULT_DIRECT_PRICE
end

-- `keys` held, `balance` of the Locker's currency, `restricted` from paid random items (server's check).
function LockerRules.checkOpen(
	locker: Locker,
	poolSize: number,
	keys: number,
	balance: number,
	restricted: boolean
): (boolean, string?)
	if poolSize <= 0 then
		return false, "empty"
	end
	if locker.paidRandom and restricted then
		return false, "restricted"
	end
	if keys <= 0 and balance < locker.keyPrice then
		return false, "short"
	end
	return true, nil
end

-- Direct purchase (paid Lockers only, restricted players only); `balance` is the player's Gleam.
function LockerRules.checkDirect(
	locker: Locker,
	item: Item,
	owned: boolean,
	balance: number,
	restricted: boolean
): (boolean, string?)
	if not locker.paidRandom or not restricted then
		return false, "not restricted"
	end
	if item.source ~= locker.source or item.kind == "sticker" then
		return false, "not in this locker"
	end
	if owned then
		return false, "owned"
	end
	if balance < LockerRules.directPrice(item) then
		return false, "short"
	end
	return true, nil
end

local function counts(value: { [string]: number }): boolean
	if type(value) ~= "table" then
		return false
	end
	for key: unknown, n: unknown in pairs(value) do
		if
			type(key) ~= "string"
			or LockerRules.get(key) == nil
			or type(n) ~= "number"
			or n < 0
			or n ~= math.floor(n)
		then
			return false
		end
	end
	return true
end

-- The data-layer validator for the `lockers` slice.
function LockerRules.validate(state: LockerTypes.Lockers): boolean
	return counts(state.keys)
		and counts(state.pity)
		and type(state.opened) == "number"
		and state.opened >= 0
		and state.opened == math.floor(state.opened)
end

return LockerRules
