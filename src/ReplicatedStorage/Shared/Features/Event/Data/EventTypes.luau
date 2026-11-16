--!strict
--[=[
	EventTypes: a limited-time event (plan: the so-event plan page, owner picks r1 2026-11-16). An event has its own
	earned-only money (a slot currency), runs between two UTC times, pays that money for finished shifts, and turns
	what is left into another currency after it ends. Its items are CosmeticRegistry items with `source = "event"` and
	`event = <id>`; its Locker is a LockerConstants Locker with the same `event`.

	@class EventTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

-- What one finished shift pays (in the event's money): every finished shift, the contract met, the player's first
-- finished shift of the day, a Roblox friend in the crew.
export type Pay = {
	finished: number,
	contract: number,
	firstToday: number,
	friend: number,
}

-- The rare pickup in a shift: one acorn hides under a random cleared pile between firstPile and lastPile and gives
-- `amount` of the event's money to whoever touches it first (EventPickupSystem).
export type Pickup = {
	amount: number,
	firstPile: number,
	lastPile: number,
}

-- A Locker key sold for the event's money (the key is added to the player's keys for that Locker).
export type KeyOffer = {
	locker: string,
	price: number,
}

export type Event = {
	id: string,
	-- The player-facing name.
	name: string,
	-- One short word for the Shop tab and the hub chip.
	short: string,
	-- The event's money: a slot currency that only this event pays.
	currency: CurrencyConstants.CurrencyType,
	-- UTC unix seconds; live from `starts` up to (not including) `ends`.
	starts: number,
	ends: number,
	pay: Pay,
	-- After the event, each leftover unit of `currency` becomes `convertRate` of `convertTo`.
	convertTo: CurrencyConstants.CurrencyType,
	convertRate: number,
	keys: { KeyOffer },
	pickup: Pickup,
}

-- Why one shift paid what it did (the results screen's acorns line).
export type PayPart = "finished" | "contract" | "firstToday" | "friend"

export type Payout = {
	total: number,
	parts: { PayPart },
}

-- What one player's finished shift looked like, for the pay.
export type ShiftFacts = {
	quotaMet: boolean,
	firstToday: boolean,
	withFriend: boolean,
}

-- The account-wide `events` slice: the day number (EventUtils.day) the first-shift bonus was last paid (0 = never),
-- and the events whose Shop tab the player has been shown (the Shop opens on it only the first time, owner Y1).
export type Events = {
	day: number,
	shown: { [string]: boolean },
}

return {}
