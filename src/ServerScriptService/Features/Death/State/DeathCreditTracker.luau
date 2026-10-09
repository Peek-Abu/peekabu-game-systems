--!strict
--[=[
	DeathCreditTracker: the last damage source per humanoid, so a death can be credited to whoever (or
	whatever) hit last within the credit window. The clock is passed in.

	@class DeathCreditTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathTypes = require(ReplicatedStorage.Shared.Features.Death.Data.DeathTypes)

type DamageSource = DeathTypes.DamageSource
type Entry = { source: DamageSource, at: number }

export type DeathCreditTracker = {
	record: (self: DeathCreditTracker, victim: Humanoid, source: DamageSource, now: number) -> (),
	credit: (self: DeathCreditTracker, victim: Humanoid, now: number, window: number) -> DamageSource?,
	forget: (self: DeathCreditTracker, victim: Humanoid) -> (),
}

local DeathCreditTracker = {}

function DeathCreditTracker.new(): DeathCreditTracker
	-- Weak keys: a destroyed humanoid that never died must not keep its entry alive.
	local entries: { [Humanoid]: Entry } = {}
	setmetatable(entries, { __mode = "k" })

	local tracker: DeathCreditTracker = {
		record = function(_self, victim, source, now)
			entries[victim] = { source = table.clone(source), at = now }
		end,

		credit = function(_self, victim, now, window)
			local entry = entries[victim]
			if entry == nil or now - entry.at > window then
				return nil
			end
			return entry.source
		end,

		forget = function(_self, victim)
			entries[victim] = nil
		end,
	}
	return tracker
end

return DeathCreditTracker
