--!strict
--[=[
	AbilityCooldownTracker: when each player's ability is ready again (server time), and each running Potted Plant
	(when it began, where the root stood, whether the client asked to stop). Plain bookkeeping for AbilityServiceServer.

	@class AbilityCooldownTracker
]=]

export type Plant = {
	startedAt: number,
	origin: Vector3,
	cancelled: boolean,
}

export type AbilityCooldownTracker = {
	readyAt: (self: AbilityCooldownTracker, userId: number) -> number,
	spend: (self: AbilityCooldownTracker, userId: number, now: number, cooldown: number) -> number,
	resetAll: (self: AbilityCooldownTracker) -> { number },
	startPlant: (self: AbilityCooldownTracker, userId: number, plant: Plant) -> (),
	plantOf: (self: AbilityCooldownTracker, userId: number) -> Plant?,
	endPlant: (self: AbilityCooldownTracker, userId: number) -> (),
	planters: (self: AbilityCooldownTracker) -> { number },
	clear: (self: AbilityCooldownTracker, userId: number) -> (),
}

local AbilityCooldownTracker = {}

function AbilityCooldownTracker.new(): AbilityCooldownTracker
	local ready: { [number]: number } = {}
	local plants: { [number]: Plant } = {}

	local tracker: AbilityCooldownTracker = {
		readyAt = function(_self, userId)
			return ready[userId] or 0
		end,

		spend = function(_self, userId, now, cooldown)
			local at = now + cooldown
			ready[userId] = at
			return at
		end,

		-- Everyone ready again (a new shift); returns who was waiting, to publish.
		resetAll = function(_self)
			local reset: { number } = {}
			for userId in ready do
				table.insert(reset, userId)
			end
			table.clear(ready)
			return reset
		end,

		startPlant = function(_self, userId, plant)
			plants[userId] = plant
		end,

		plantOf = function(_self, userId)
			return plants[userId]
		end,

		endPlant = function(_self, userId)
			plants[userId] = nil
		end,

		planters = function(_self)
			local list: { number } = {}
			for userId in plants do
				table.insert(list, userId)
			end
			return list
		end,

		clear = function(_self, userId)
			ready[userId] = nil
			plants[userId] = nil
		end,
	}
	return tracker
end

return AbilityCooldownTracker
