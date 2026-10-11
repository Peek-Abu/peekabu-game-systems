--!strict
--[=[
	VacuumChannelTracker: who is vacuuming which pile right now (Cleanup Crew M3 UI: the crew roster's "vacuuming" and
	the makers of each vacuum noise pulse, for the review's QUIETEST FEET / LOUDEST VACUUM). The Interaction channel asks
	Vacuum's `canChannel` at the start and every tick while a player holds the button; each allowed ask is `note`d. A
	player counts as vacuuming their last pile until `window` seconds pass with no ask (released, or the channel ended).
	`note` reports a start when the pile differs from their last one, exactly like the map it replaces. Plain
	bookkeeping (pure: it never touches the Instances it keys by).

	@class VacuumChannelTracker
]=]

export type VacuumChannelTracker = {
	note: (self: VacuumChannelTracker, userId: number, pile: Instance, now: number) -> boolean,
	makersOn: (self: VacuumChannelTracker, pile: Instance, now: number) -> { number },
	isActive: (self: VacuumChannelTracker, userId: number, now: number) -> boolean,
	forget: (self: VacuumChannelTracker, userId: number) -> (),
	clear: (self: VacuumChannelTracker) -> (),
}

type Channel = { pile: Instance, at: number }

local VacuumChannelTracker = {}

function VacuumChannelTracker.new(window: number): VacuumChannelTracker
	local channels: { [number]: Channel } = {}

	local tracker: VacuumChannelTracker = {
		note = function(_self, userId, pile, now)
			local current = channels[userId]
			local started = current == nil or current.pile ~= pile
			channels[userId] = { pile = pile, at = now }
			return started
		end,

		makersOn = function(_self, pile, now)
			local makers: { number } = {}
			for userId, channel in channels do
				if channel.pile == pile and now - channel.at <= window then
					table.insert(makers, userId)
				end
			end
			table.sort(makers)
			return makers
		end,

		isActive = function(_self, userId, now)
			local channel = channels[userId]
			return channel ~= nil and now - channel.at <= window
		end,

		forget = function(_self, userId)
			channels[userId] = nil
		end,

		clear = function(_self)
			table.clear(channels)
		end,
	}
	return tracker
end

return VacuumChannelTracker
