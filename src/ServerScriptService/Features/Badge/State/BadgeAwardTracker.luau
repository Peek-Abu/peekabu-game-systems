--!strict
--[=[
	BadgeAwardTracker: per player, which badges are known owned (true), known not owned (false) or unknown
	(nil), and which awards are in flight, so one badge is never requested twice at once.

	@class BadgeAwardTracker
]=]

export type BadgeAwardTracker = {
	owned: (self: BadgeAwardTracker, userId: number, key: string) -> boolean?,
	setOwned: (self: BadgeAwardTracker, userId: number, key: string, owned: boolean) -> (),
	begin: (self: BadgeAwardTracker, userId: number, key: string) -> boolean,
	finish: (self: BadgeAwardTracker, userId: number, key: string) -> (),
	forget: (self: BadgeAwardTracker, userId: number) -> (),
}

local BadgeAwardTracker = {}

function BadgeAwardTracker.new(): BadgeAwardTracker
	local ownership: { [number]: { [string]: boolean } } = {}
	local pending: { [number]: { [string]: true } } = {}

	local tracker: BadgeAwardTracker = {
		owned = function(_self, userId, key)
			local known = ownership[userId]
			return if known ~= nil then known[key] else nil
		end,

		setOwned = function(_self, userId, key, owned)
			local known = ownership[userId]
			if known == nil then
				known = {}
				ownership[userId] = known
			end
			known[key] = owned
		end,

		-- Marks an award in flight; false when one already is.
		begin = function(_self, userId, key)
			local inFlight = pending[userId]
			if inFlight == nil then
				inFlight = {}
				pending[userId] = inFlight
			end
			if inFlight[key] then
				return false
			end
			inFlight[key] = true
			return true
		end,

		finish = function(_self, userId, key)
			local inFlight = pending[userId]
			if inFlight ~= nil then
				inFlight[key] = nil
			end
		end,

		forget = function(_self, userId)
			ownership[userId] = nil
			pending[userId] = nil
		end,
	}
	return tracker
end

return BadgeAwardTracker
