--!strict
--[=[
	CarryHoldTracker: who holds what — at most one object per player and one holder per object. Objects
	are identified by a number the shell assigns.

	@class CarryHoldTracker
]=]

export type CarryHoldTracker = {
	hold: (self: CarryHoldTracker, userId: number, objectId: number) -> boolean,
	release: (self: CarryHoldTracker, userId: number) -> number?,
	heldBy: (self: CarryHoldTracker, userId: number) -> number?,
	holderOf: (self: CarryHoldTracker, objectId: number) -> number?,
}

local CarryHoldTracker = {}

function CarryHoldTracker.new(): CarryHoldTracker
	local objectOf: { [number]: number } = {}
	local holderOfObject: { [number]: number } = {}

	local tracker: CarryHoldTracker = {
		hold = function(_self, userId, objectId)
			if objectOf[userId] ~= nil or holderOfObject[objectId] ~= nil then
				return false
			end
			objectOf[userId] = objectId
			holderOfObject[objectId] = userId
			return true
		end,

		release = function(_self, userId)
			local objectId = objectOf[userId]
			if objectId == nil then
				return nil
			end
			objectOf[userId] = nil
			holderOfObject[objectId] = nil
			return objectId
		end,

		heldBy = function(_self, userId)
			return objectOf[userId]
		end,

		holderOf = function(_self, objectId)
			return holderOfObject[objectId]
		end,
	}
	return tracker
end

return CarryHoldTracker
