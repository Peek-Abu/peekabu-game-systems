--!strict
--[=[
	CoffeeStore: Coffee for the crew's client state: the coffee developer product's Robux price as Roblox reports it
	(`robux`; CoffeeServiceClient fetches it at start), so the choice shows what the purchase prompt will charge. Nil
	until Roblox answers (CoffeeRules.robuxText then shows CoffeeConstants.ROBUX_PRICE). A Charm atom the coffee
	choice reads.

	@class CoffeeStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local noPrice: number? = nil
local robux = Charm.atom(noPrice)

local CoffeeStore = {
	robux = robux,
}

-- Keeps the product's live Robux price.
function CoffeeStore.setRobux(price: number?)
	robux(price)
end

-- Forgets the live price (specs).
function CoffeeStore.reset()
	robux(nil)
end

return CoffeeStore
