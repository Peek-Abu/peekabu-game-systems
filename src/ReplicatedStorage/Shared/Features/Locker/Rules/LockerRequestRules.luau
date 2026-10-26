--!strict
--[=[
	LockerRequestRules: shape-checks the Locker requests at the trust boundary (the payloads arrive untyped).

	@class LockerRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)

local MAX_ID = 64

export type OpenRequest = { locker: LockerTypes.LockerId }
export type BuyRequest = { locker: LockerTypes.LockerId, item: string }

local LockerRequestRules = {}

local function lockerOf(value: unknown): LockerTypes.LockerId?
	if value == "gloom" then
		return "gloom"
	elseif value == "gleam" then
		return "gleam"
	end
	return nil
end

function LockerRequestRules.buildOpen(locker: LockerTypes.LockerId): OpenRequest
	return { locker = locker }
end

function LockerRequestRules.buildBuy(locker: LockerTypes.LockerId, item: string): BuyRequest
	return { locker = locker, item = item }
end

function LockerRequestRules.parseOpen(payload: unknown): LockerTypes.LockerId?
	if type(payload) ~= "table" then
		return nil
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the field is shape-checked below
	return lockerOf(fields.locker)
end

function LockerRequestRules.parseBuy(payload: unknown): (LockerTypes.LockerId?, string?)
	if type(payload) ~= "table" then
		return nil, nil
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; each field is shape-checked below
	local item = fields.item
	if type(item) ~= "string" or #item == 0 or #item > MAX_ID then
		return nil, nil
	end
	if fields.locker == "gloom" then
		return "gloom", item
	elseif fields.locker == "gleam" then
		return "gleam", item
	end
	return nil, nil
end

return LockerRequestRules
