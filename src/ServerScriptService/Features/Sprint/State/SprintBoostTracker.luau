--!strict
--[=[
	SprintBoostTracker: each player's speed boost (an ability's Let's Go!): one scale and when it ends. A boost given
	again never stacks: the bigger scale and the later end win. The scale holds until `expired` takes it off (the
	service rescales WalkSpeed back right then), so every reader agrees with the WalkSpeed that is live.

	@class SprintBoostTracker
]=]

type Boost = { scale: number, untilTime: number }

export type Ended = { userId: number, scale: number }

export type SprintBoostTracker = {
	boost: (self: SprintBoostTracker, userId: number, scale: number, untilTime: number) -> number,
	scaleOf: (self: SprintBoostTracker, userId: number) -> number,
	expired: (self: SprintBoostTracker, now: number) -> { Ended },
	clear: (self: SprintBoostTracker, userId: number) -> (),
}

local SprintBoostTracker = {}

function SprintBoostTracker.new(): SprintBoostTracker
	local boosts: { [number]: Boost } = {}

	local tracker: SprintBoostTracker = {
		boost = function(self, userId, scale, untilTime)
			if scale <= 0 then
				return self:scaleOf(userId)
			end
			local current = boosts[userId]
			if current == nil then
				boosts[userId] = { scale = scale, untilTime = untilTime }
			else
				current.scale = math.max(current.scale, scale)
				current.untilTime = math.max(current.untilTime, untilTime)
			end
			return self:scaleOf(userId)
		end,

		scaleOf = function(_self, userId)
			local current = boosts[userId]
			return if current ~= nil then current.scale else 1
		end,

		expired = function(_self, now)
			local ended: { Ended } = {}
			for userId, current in boosts do
				if now >= current.untilTime then
					table.insert(ended, { userId = userId, scale = current.scale })
				end
			end
			for _, entry in ended do
				boosts[entry.userId] = nil
			end
			return ended
		end,

		clear = function(_self, userId)
			boosts[userId] = nil
		end,
	}
	return tracker
end

return SprintBoostTracker
