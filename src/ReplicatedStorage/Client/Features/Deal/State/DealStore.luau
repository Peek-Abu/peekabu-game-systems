--!strict
--[=[
	DealStore: the one-time deals' client state: each deal product's Robux price as Roblox reports it (`robux`, by deal
	id; DealServiceClient fetches them at start), so the deal card and the pick screen's button show what the purchase
	prompt will charge, and the card's % off is worked out from that price. A deal missing here shows its
	DealConstants price. A Charm atom the screens read.

	@class DealStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local noPrices: { [string]: number } = {}
local robux = Charm.atom(noPrices)

local DealStore = {
	robux = robux,
}

-- Keeps deal `id`'s live Robux price.
function DealStore.setRobux(id: string, price: number)
	local nextPrices = table.clone(robux())
	nextPrices[id] = price
	robux(nextPrices)
end

-- Forgets the live prices (specs).
function DealStore.reset()
	robux({})
end

return DealStore
