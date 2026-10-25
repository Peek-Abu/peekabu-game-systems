--!strict
--[=[
	EmoteRequestRules: the emote packets' shapes. Parsing checks SHAPE only (a whole slot number 1-4); EmoteRules
	decides whether the emote may play.

	@class EmoteRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)

export type PlayRequest = { slot: number }

local EmoteRequestRules = {}

function EmoteRequestRules.buildPlay(slot: number): PlayRequest
	return { slot = slot }
end

function EmoteRequestRules.parsePlay(payload: unknown): (number?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the slot is shape-checked below
	local slot = fields.slot
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > CosmeticConstants.WHEEL_SLOTS then
		return nil, "missing or malformed slot"
	end
	return slot, nil
end

return EmoteRequestRules
