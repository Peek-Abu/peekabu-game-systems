--!strict
--[=[
	EmployeeStatOverrideTracker: admin stat overrides for testing (the `employeestatset` command), per player. A
	player's bars are their employee's own (EmployeeStatFormulas.level) with any override on top; an override lasts
	until it is cleared or the player leaves. Plain bookkeeping keyed by UserId.

	@class EmployeeStatOverrideTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeStatFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeStatFormulas)

type Stat = EmployeeProfileRegistry.Stat

export type EmployeeStatOverrideTracker = {
	set: (self: EmployeeStatOverrideTracker, userId: number, stat: Stat, bars: number) -> (),
	-- `stat` nil clears every override the player has.
	clear: (self: EmployeeStatOverrideTracker, userId: number, stat: Stat?) -> (),
	barsFor: (self: EmployeeStatOverrideTracker, userId: number, employee: string) -> { [Stat]: number },
	forget: (self: EmployeeStatOverrideTracker, userId: number) -> (),
	-- How many players have an override (getState).
	count: (self: EmployeeStatOverrideTracker) -> number,
}

local EmployeeStatOverrideTracker = {}

function EmployeeStatOverrideTracker.new(): EmployeeStatOverrideTracker
	local overrides: { [number]: { [Stat]: number } } = {}

	local tracker: EmployeeStatOverrideTracker
	tracker = {
		set = function(_self, userId, stat, bars)
			local own = overrides[userId]
			if own == nil then
				own = {}
				overrides[userId] = own
			end
			own[stat] = EmployeeStatFormulas.barsFrom(bars)
		end,

		clear = function(_self, userId, stat)
			local own = overrides[userId]
			if own == nil then
				return
			end
			if stat ~= nil then
				own[stat] = nil
			end
			if stat == nil or next(own) == nil then
				overrides[userId] = nil
			end
		end,

		barsFor = function(_self, userId, employee)
			local own = overrides[userId]
			local bars: { [Stat]: number } = {}
			for _, stat: Stat in EmployeeProfileRegistry.STATS do
				local override = if own ~= nil then own[stat] else nil
				bars[stat] = override or EmployeeStatFormulas.level(employee, stat)
			end
			return bars
		end,

		forget = function(_self, userId)
			overrides[userId] = nil
		end,

		count = function(_self)
			local count = 0
			for _ in overrides do
				count += 1
			end
			return count
		end,
	}
	return tracker
end

return EmployeeStatOverrideTracker
