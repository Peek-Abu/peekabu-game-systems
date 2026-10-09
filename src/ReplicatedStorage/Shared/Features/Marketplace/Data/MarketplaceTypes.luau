--!strict
--[=[
	MarketplaceTypes: products, passes and receipts (design:
	docs/superpowers/specs/2026-10-09-marketplace-design.md).

	@class MarketplaceTypes
]=]

-- A developer product, registered under a game key ("gems-100").
export type ProductDef = {
	productId: number,
}

-- A gamepass, registered under a game key ("vip").
export type PassDef = {
	passId: number,
}

--[=[
	The fields of Roblox's ProcessReceipt receipt that the base reads. Built from the engine's receipt
	table at the boundary (MarketplaceServiceServer), so everything past it is typed.
]=]
export type Receipt = {
	purchaseId: string,
	playerId: number,
	productId: number,
	currencySpent: number,
}

-- What a receipt callback tells Roblox: acknowledged for good, or ask again later.
export type ReceiptDecision = "granted" | "retry"

return {}
