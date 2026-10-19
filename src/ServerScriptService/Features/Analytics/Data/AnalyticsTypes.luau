--!strict
--[=[
	AnalyticsTypes: the shapes the week-1 analytics context passes around (type definitions only).

	There is deliberately no `CurrencyChange` here: economy events consume the one the Currency feature already
	exports (`CurrencyConstants.CurrencyChange`).

	@class AnalyticsTypes
]=]

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

-- Plain functions (no `self`) so a feature can be handed just the sender.
export type Sender = {
	custom: (player: Player, event: string, value: number?, fields: { string }?) -> (),
	funnel: (player: Player, step: number, stepName: string, fields: { string }?) -> (),
	economy: (player: Player, call: EconomyCall, fields: { string }?) -> (),
}

return {}
