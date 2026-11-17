--!strict
--[=[
	AnalyticsTypes: the shapes the week-1 analytics context passes around (type definitions only).

	There is deliberately no `CurrencyChange` here: economy events consume the one the Currency feature already
	exports (`CurrencyConstants.CurrencyChange`).

	@class AnalyticsTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

export type Cohort = "new" | "ret" | "unk"

export type Context = {
	tags: string,
	platform: string,
	party: number,
	cohort: Cohort,
	build: string,
}

export type EconomyCall = {
	flow: "source" | "sink",
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string?,
}

-- One owner-facing off switch per tracking pick (AnalyticsSwitchConstants).
export type Switch = "quits" | "hubTime" | "training" | "shiftsPerVisit" | "economy"

-- Where a player is when they quit.
export type Place = "hub" | "training" | "shift" | "results"

-- Something that just happened to a player in a shift (a knock-out is kept apart from a catch).
export type Moment = "caught" | "chased" | "knocked_out"

-- What a quit came right after.
export type After = Moment | "nothing"

-- How a hub stay ended: a real truck, the Training truck, or quitting the game.
export type HubEnd = "boarded" | "training" | "quit"

-- Roblox's economy transaction types (Enum.AnalyticsEconomyTransactionType names).
export type EconomyKind = "IAP" | "Shop" | "Gameplay" | "ContextualPurchase" | "TimedReward" | "Onboarding"

-- One currency move a feature reports after its transaction committed. `sku` is a bounded group (Roblox keeps 100);
-- `item` (the exact id), `rarity` and `where` (the screen or reason) ride in the custom fields.
export type EconomyRecord = {
	currency: CurrencyConstants.EconomyCurrency,
	flow: "source" | "sink",
	amount: number,
	kind: EconomyKind,
	sku: string,
	item: string?,
	rarity: string?,
	where: string?,
}

-- Plain functions (no `self`) so a feature can be handed just the sender.
export type Sender = {
	custom: (player: Player, event: string, value: number?, fields: { string }?) -> (),
	funnel: (player: Player, funnel: string, step: number, stepName: string, fields: { string }?) -> (),
	economy: (player: Player, call: EconomyCall, fields: { string }?) -> (),
}

return {}
