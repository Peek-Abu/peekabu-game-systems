--!strict
--[=[
	RankTracker: each player's session-only rank, kept in server memory by UserId (RankConstants.RANK_PERSIST = false).
	Nothing here is ever written to a profile. Reads hand out copies; `update` edits in place under the same
	mutator contract as the profile slice (return whether anything changed), so RankRules drives both.

	@class RankTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankTypes = require(ReplicatedStorage.Shared.Features.Rank.Data.RankTypes)

type RankState = RankTypes.RankState

export type RankTracker = {
	get: (self: RankTracker, userId: number) -> RankState?,
	set: (self: RankTracker, userId: number, state: RankState) -> (),
	-- Runs `fn` on the player's rank in place; false when they have none or `fn` changed nothing.
	update: (self: RankTracker, userId: number, fn: (state: RankState) -> boolean) -> boolean,
	forget: (self: RankTracker, userId: number) -> (),
	clear: (self: RankTracker) -> (),
	count: (self: RankTracker) -> number,
}

local RankTracker = {}

function RankTracker.new(): RankTracker
	local ranks: { [number]: RankState } = {}

	local tracker: RankTracker = {
		get = function(_self, userId)
			local state = ranks[userId]
			return if state ~= nil then table.clone(state) else nil
		end,

		set = function(_self, userId, state)
			ranks[userId] = table.clone(state)
		end,

		update = function(_self, userId, fn)
			local state = ranks[userId]
			if state == nil then
				return false
			end
			return fn(state)
		end,

		forget = function(_self, userId)
			ranks[userId] = nil
		end,

		clear = function(_self)
			table.clear(ranks)
		end,

		count = function(_self)
			local total = 0
			for _ in ranks do
				total += 1
			end
			return total
		end,
	}
	return tracker
end

return RankTracker
