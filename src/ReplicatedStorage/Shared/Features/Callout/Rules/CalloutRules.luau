--!strict
--[=[
	CalloutRules: pure callout logic, shared by both realms.

	- `allowed(times, now)`: the rate limit (one a CalloutConstants.GAP, BURST per WINDOW) over the player's recent
	  callout times; `remember(times, now)` keeps the list short.
	- `sticker(stickers, slot, owns)`: the sticker in a slot, when there is one and it is owned. Refusals: "empty slot",
	  "not owned".
	- `ping(id, at, from)`: whether a ping may go there. Refusals: "unknown ping", "too far" (PING_RANGE from `from`,
	  the body), "no body".

	@class CalloutRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)
local CalloutRegistry = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)

local CalloutRules = {}

function CalloutRules.allowed(times: { number }, now: number): boolean
	local recent = 0
	for _, at in times do
		if now - at < CalloutConstants.GAP then
			return false
		end
		if now - at < CalloutConstants.WINDOW then
			recent += 1
		end
	end
	return recent < CalloutConstants.BURST
end

-- Adds `now` and drops times older than the window (in place).
function CalloutRules.remember(times: { number }, now: number)
	for index = #times, 1, -1 do
		if now - times[index] >= CalloutConstants.WINDOW then
			table.remove(times, index)
		end
	end
	table.insert(times, now)
end

function CalloutRules.sticker(stickers: { string }, slot: number, owns: (id: string) -> boolean): (string?, string?)
	local id = stickers[slot]
	local item = if id ~= nil and id ~= "" then CosmeticRegistry.get(id) else nil
	if id == nil or item == nil or item.kind ~= "sticker" then
		return nil, "empty slot"
	end
	if not owns(id) then
		return nil, "not owned"
	end
	return id, nil
end

function CalloutRules.ping(id: string, at: Vector3, from: Vector3?): (boolean, string?)
	if CalloutRegistry.ping(id) == nil then
		return false, "unknown ping"
	end
	if from == nil then
		return false, "no body"
	end
	if (at - from).Magnitude > CalloutConstants.PING_RANGE then
		return false, "too far"
	end
	return true, nil
end

return CalloutRules
