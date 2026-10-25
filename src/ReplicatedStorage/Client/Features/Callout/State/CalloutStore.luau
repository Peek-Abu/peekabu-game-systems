--!strict
--[=[
	CalloutStore: each player's latest sticker and when it arrived (the crew list shows it while it is fresh,
	CalloutConstants.STICKER_SECONDS). A Charm atom keyed by userId.

	@class CalloutStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)

export type Latest = { id: string, at: number }

local initial: { [number]: Latest } = {}
local stickers = Charm.atom(initial)

local CalloutStore = {
	stickers = stickers,
}

function CalloutStore.sticker(userId: number, id: string, at: number)
	local next = table.clone(stickers())
	next[userId] = { id = id, at = at }
	stickers(next)
end

-- The sticker `userId` showed in the last STICKER_SECONDS (nil when none, or it is old).
function CalloutStore.fresh(all: { [number]: Latest }, userId: number, now: number): string?
	local latest = all[userId]
	if latest == nil or now - latest.at > CalloutConstants.STICKER_SECONDS then
		return nil
	end
	return latest.id
end

-- Forgets `userId`'s sticker if it is still the one that arrived at `at` (a newer one stays).
function CalloutStore.expire(userId: number, at: number)
	local latest = stickers()[userId]
	if latest ~= nil and latest.at == at then
		CalloutStore.forget(userId)
	end
end

function CalloutStore.forget(userId: number)
	local next = table.clone(stickers())
	next[userId] = nil
	stickers(next)
end

-- Forgets everything (between specs).
function CalloutStore.reset()
	stickers({})
end

return CalloutStore
