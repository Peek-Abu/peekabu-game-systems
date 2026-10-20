--!strict
--[=[
	ShiftLivesTracker: every player's lives in the current shift, kept by UserId. Each catch spends one; the last
	knocks the player out for the shift. A life is never regained; the shift's next start replaces everything.

	@class ShiftLivesTracker
]=]

local ShiftLivesRules = require(script.Parent.Parent.Rules.ShiftLivesRules)

export type ShiftLivesTracker = {
	-- Replaces everything: userId -> starting lives.
	reset: (self: ShiftLivesTracker, entries: { [number]: number }) -> (),
	-- A late joiner gets `lives`; a player already listed keeps what they have.
	admit: (self: ShiftLivesTracker, userId: number, lives: number) -> (),
	-- One catch: the lives left and whether the player is now out; (nil, nil) for an unknown player or one already out.
	spend: (self: ShiftLivesTracker, userId: number) -> (number?, boolean?),
	get: (self: ShiftLivesTracker, userId: number) -> number?,
	-- The lives the player started the shift with.
	max: (self: ShiftLivesTracker, userId: number) -> number?,
	isOut: (self: ShiftLivesTracker, userId: number) -> boolean,
	-- The players who are out, as a new sorted list.
	out: (self: ShiftLivesTracker) -> { number },
	clear: (self: ShiftLivesTracker) -> (),
}

local ShiftLivesTracker = {}

function ShiftLivesTracker.new(): ShiftLivesTracker
	local lives: { [number]: number } = {}
	local maxes: { [number]: number } = {}

	local tracker: ShiftLivesTracker = {
		reset = function(_self, entries)
			table.clear(lives)
			table.clear(maxes)
			for userId, count in entries do
				lives[userId] = count
				maxes[userId] = count
			end
		end,

		admit = function(_self, userId, count)
			if lives[userId] ~= nil then
				return
			end
			lives[userId] = count
			maxes[userId] = count
		end,

		spend = function(_self, userId)
			local remaining = lives[userId]
			if remaining == nil or remaining <= 0 then
				return nil, nil
			end
			local left, knockedOut = ShiftLivesRules.spend(remaining)
			lives[userId] = left
			return left, knockedOut
		end,

		get = function(_self, userId)
			return lives[userId]
		end,

		max = function(_self, userId)
			return maxes[userId]
		end,

		isOut = function(_self, userId)
			local remaining = lives[userId]
			return remaining ~= nil and remaining <= 0
		end,

		out = function(_self)
			local result: { number } = {}
			for userId, remaining in lives do
				if remaining <= 0 then
					table.insert(result, userId)
				end
			end
			table.sort(result)
			return result
		end,

		clear = function(_self)
			table.clear(lives)
			table.clear(maxes)
		end,
	}
	return tracker
end

return ShiftLivesTracker
