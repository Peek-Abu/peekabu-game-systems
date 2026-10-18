--!strict
--[=[
	CargoClaimTracker: which cargo items have been claimed (being banked, pocketed or spilled). Claiming is
	the first move of every step that consumes an item, so an item can be consumed once: a second Load of the
	same item finds it claimed (Cleanup Crew spec §6.4, "two simultaneous Loads can't double-count"). Items
	are identified by their CargoId.

	@class CargoClaimTracker
]=]

export type CargoClaimTracker = {
	claim: (self: CargoClaimTracker, itemId: number) -> boolean,
	release: (self: CargoClaimTracker, itemId: number) -> (),
	isClaimed: (self: CargoClaimTracker, itemId: number) -> boolean,
	clear: (self: CargoClaimTracker) -> (),
}

local CargoClaimTracker = {}

function CargoClaimTracker.new(): CargoClaimTracker
	local claimed: { [number]: boolean } = {}

	local tracker: CargoClaimTracker = {
		-- True when this call claimed it; false when it was already claimed.
		claim = function(_self, itemId)
			if claimed[itemId] then
				return false
			end
			claimed[itemId] = true
			return true
		end,

		-- Gives a claim back (the banking handler refused the deposit).
		release = function(_self, itemId)
			claimed[itemId] = nil
		end,

		isClaimed = function(_self, itemId)
			return claimed[itemId] == true
		end,

		clear = function(_self)
			table.clear(claimed)
		end,
	}
	return tracker
end

return CargoClaimTracker
