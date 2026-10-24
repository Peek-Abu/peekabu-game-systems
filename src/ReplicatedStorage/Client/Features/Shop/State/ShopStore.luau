--!strict
--[=[
	ShopStore: the Shop's client state: which product page is open (`product`, nil = the Shop's front) and the last
	buy result from the server (`result`, from ShopEvents.BuyResult) so the page can say "Need 300 more" or that it
	is already owned. Opening another page clears the old result. Charm atoms the Shop screen reads.

	@class ShopStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Result = { offer: string, reason: string }

local noProduct: string? = nil
local product = Charm.atom(noProduct)
local noResult: Result? = nil
local result = Charm.atom(noResult)

local ShopStore = {
	product = product,
	result = result,
}

function ShopStore.open(id: string?)
	product(id)
	result(nil)
end

function ShopStore.close()
	product(nil)
	result(nil)
end

function ShopStore.setResult(value: Result)
	result(value)
end

-- Forgets everything (between specs).
function ShopStore.reset()
	product(nil)
	result(nil)
end

return ShopStore
