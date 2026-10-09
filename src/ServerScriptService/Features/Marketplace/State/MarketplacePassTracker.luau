--!strict
--[=[
	MarketplacePassTracker: which registered gamepasses each present player owns, by game key. Filled
	from UserOwnsGamePassAsync on join and from purchases; a pass is never "un-owned" while the player
	stays, so there is only `grant`.

	@class MarketplacePassTracker
]=]

export type MarketplacePassTracker = {
	grant: (self: MarketplacePassTracker, userId: number, key: string) -> boolean,
	owns: (self: MarketplacePassTracker, userId: number, key: string) -> boolean,
	ownedBy: (self: MarketplacePassTracker, userId: number) -> { string },
	forget: (self: MarketplacePassTracker, userId: number) -> (),
}

local MarketplacePassTracker = {}

function MarketplacePassTracker.new(): MarketplacePassTracker
	local owned: { [number]: { [string]: true } } = {}

	local tracker: MarketplacePassTracker = {
		-- Records ownership; true when it is new.
		grant = function(_self, userId, key)
			local passes = owned[userId]
			if passes == nil then
				passes = {}
				owned[userId] = passes
			end
			if passes[key] then
				return false
			end
			passes[key] = true
			return true
		end,

		owns = function(_self, userId, key)
			local passes = owned[userId]
			return passes ~= nil and passes[key] == true
		end,

		ownedBy = function(_self, userId)
			local keys: { string } = {}
			local passes = owned[userId]
			if passes ~= nil then
				for key in passes do
					table.insert(keys, key)
				end
			end
			table.sort(keys)
			return keys
		end,

		forget = function(_self, userId)
			owned[userId] = nil
		end,
	}
	return tracker
end

return MarketplacePassTracker
