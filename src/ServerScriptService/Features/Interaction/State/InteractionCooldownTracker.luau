--!strict
--[=[
	InteractionCooldownTracker: when each player last used each object, so a kind's cooldown can be
	enforced per player per object. Objects are identified by a number the shell assigns. The clock is
	passed in.

	@class InteractionCooldownTracker
]=]

export type InteractionCooldownTracker = {
	remaining: (
		self: InteractionCooldownTracker,
		userId: number,
		targetId: number,
		now: number,
		cooldown: number
	) -> number,
	mark: (self: InteractionCooldownTracker, userId: number, targetId: number, now: number) -> (),
	forgetPlayer: (self: InteractionCooldownTracker, userId: number) -> (),
	forgetTarget: (self: InteractionCooldownTracker, targetId: number) -> (),
}

local InteractionCooldownTracker = {}

function InteractionCooldownTracker.new(): InteractionCooldownTracker
	-- userId -> targetId -> the time of the last accepted use.
	local lastUse: { [number]: { [number]: number } } = {}

	local tracker: InteractionCooldownTracker = {
		remaining = function(_self, userId, targetId, now, cooldown)
			local uses = lastUse[userId]
			local at = if uses ~= nil then uses[targetId] else nil
			if at == nil then
				return 0
			end
			return math.max(0, at + cooldown - now)
		end,

		mark = function(_self, userId, targetId, now)
			local uses = lastUse[userId]
			if uses == nil then
				uses = {}
				lastUse[userId] = uses
			end
			uses[targetId] = now
		end,

		forgetPlayer = function(_self, userId)
			lastUse[userId] = nil
		end,

		forgetTarget = function(_self, targetId)
			for _, uses in lastUse do
				uses[targetId] = nil
			end
		end,
	}
	return tracker
end

return InteractionCooldownTracker
