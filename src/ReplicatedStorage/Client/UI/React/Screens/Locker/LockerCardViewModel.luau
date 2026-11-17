--!strict
--[=[
	LockerCardViewModel: one Locker card on the Shop's Lockers tab (its keys, pity line and meter, money on hand and Open
	button), worked out from `LockerRules` and the player's synced state. Split out of LockerViewModel, which
	re-exports all of it (callers keep using LockerViewModel).

	@class LockerCardViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Locker = ReplicatedStorage.Shared.Features.Locker
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

type Item = CosmeticTypes.Item
type Locker = LockerTypes.Locker
type LockerId = LockerTypes.LockerId

-- `acorns`: a live event's money (absent reads 0).
export type Balances = { gloom: number, gleam: number, acorns: number? }

export type ButtonKind = "key" | "buy" | "short" | "restricted" | "empty"

export type OpenButton = {
	text: string,
	enabled: boolean,
	kind: ButtonKind,
	currency: LockerTypes.Currency,
	price: string,
}

export type LockerCard = {
	id: LockerId,
	name: string,
	currency: LockerTypes.Currency,
	keys: number,
	keysText: string,
	keyPrice: string,
	pityText: string,
	restricted: boolean,
	button: OpenButton,
	-- "You have N" of the Locker's own money (Gloom, or the event's), drawn on the card; nil for the Gleam Locker,
	-- whose Gleam is in the menu bar (owner 11-16: bars show only Gleam and Credits).
	haveText: string?,
	haveCurrency: LockerTypes.Currency?,
	-- The pity meter (owner 11-16 pick A): opens since the last Epic or better, out of the pity number, as the kit's
	-- ToonBar. nil when nothing counts (an empty Locker, or a paid one for a restricted player).
	meter: PityMeter?,
}

export type PityMeter = {
	-- 0..1 of the way to the guaranteed Epic or better.
	fill: number,
	-- "12 / 17" across the bar.
	label: string,
	-- "Epic or better in 5 opens!" (or "Next open is Epic or better!").
	text: string,
	-- The ToonBar kind: the Gleam Locker's gold, every other Locker's goo.
	kind: "gloom" | "stamina",
}

local LockerCardViewModel = {}

function LockerCardViewModel.card(
	locker: Locker,
	state: LockerTypes.Lockers,
	balances: Balances,
	restricted: boolean,
	pool: { Item }?
): LockerCard
	local items = pool or LockerRules.pool(locker)
	local odds = LockerRules.odds(locker, items)
	local keys = state.keys[locker.id] or 0
	local pity = state.pity[locker.id] or 0
	-- An empty Locker has nothing to buy directly either, so it reads as empty and says what a restricted player
	-- will be able to do there (not "Buy items directly below" over nothing).
	local isRestricted = locker.paidRandom and restricted and #items > 0
	local priceText = ToonStyleViewModel.grouped(locker.keyPrice)
	local balance = if locker.currency == "gleam"
		then balances.gleam
		elseif locker.currency == "acorns" then balances.acorns or 0
		else balances.gloom

	local pityText = if locker.paidRandom and restricted
		then "Nothing here yet. Soon you can buy its items one by one."
		else "Nothing inside yet."
	if isRestricted then
		pityText = "Buy items directly below."
	elseif odds.pityAt ~= nil then
		local remaining = math.max(1, odds.pityAt - pity)
		pityText = if remaining == 1
			then "Epic or better on the next open!"
			else `Epic or better in {remaining} opens or sooner.`
	end

	local button: OpenButton
	if #items == 0 then
		button = {
			text = "Coming soon",
			enabled = false,
			kind = "empty",
			currency = locker.currency,
			price = priceText,
		}
	elseif isRestricted then
		button = {
			text = "Buy directly",
			enabled = false,
			kind = "restricted",
			currency = locker.currency,
			price = priceText,
		}
	elseif keys > 0 then
		button = {
			text = "Open (1 key)",
			enabled = true,
			kind = "key",
			currency = locker.currency,
			price = priceText,
		}
	elseif balance >= locker.keyPrice then
		button = {
			text = "Open",
			enabled = true,
			kind = "buy",
			currency = locker.currency,
			price = priceText,
		}
	else
		local missing = locker.keyPrice - balance
		button = {
			text = `Need {ToonStyleViewModel.grouped(missing)} more`,
			enabled = locker.currency == "gleam",
			kind = "short",
			currency = locker.currency,
			price = priceText,
		}
	end

	local meter: PityMeter? = nil
	local pityAt = odds.pityAt
	if pityAt ~= nil and #items > 0 and not isRestricted then
		local count = math.clamp(pity, 0, pityAt)
		local left = math.max(1, pityAt - count)
		meter = {
			fill = count / pityAt,
			label = `{count} / {pityAt}`,
			text = if left == 1 then "Next open is Epic or better!" else `Epic or better in {left} opens!`,
			kind = if locker.currency == "gleam" then "stamina" else "gloom",
		}
	end

	local keysText = if keys == 0 then "No keys" elseif keys == 1 then "1 key" else `{keys} keys`
	return {
		id = locker.id,
		name = locker.name,
		currency = locker.currency,
		keys = keys,
		keysText = keysText,
		keyPrice = priceText,
		pityText = pityText,
		restricted = isRestricted,
		button = button,
		haveText = if locker.currency == "gleam" then nil else `You have {ToonStyleViewModel.grouped(balance)}`,
		haveCurrency = if locker.currency == "gleam" then nil else locker.currency,
		meter = meter,
	}
end

return LockerCardViewModel
