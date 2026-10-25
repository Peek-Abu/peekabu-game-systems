--!strict
--[=[
	CalloutRequestRules: the callout packets' shapes. A request is a sticker slot ({ kind = "sticker", slot }) or a
	ping ({ kind = "ping", id, x, y, z }: a finite spot). Parsing checks SHAPE only; CalloutRules decides.

	@class CalloutRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)
local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)

export type Request = { kind: "sticker", slot: number } | { kind: "ping", id: string, at: Vector3 }

local CalloutRequestRules = {}

local function finite(value: number): boolean
	return value == value and value > -1e6 and value < 1e6
end

function CalloutRequestRules.build(request: Request): { [string]: string | number }
	if request.kind == "sticker" then
		return { kind = "sticker", slot = request.slot }
	end
	return { kind = "ping", id = request.id, x = request.at.X, y = request.at.Y, z = request.at.Z }
end

function CalloutRequestRules.parse(payload: unknown): (Request?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; each field is shape-checked below
	local kind = fields.kind
	if kind == "sticker" then
		local slot = fields.slot
		if
			type(slot) == "number"
			and slot == math.floor(slot)
			and slot >= 1
			and slot <= CosmeticConstants.STICKER_SLOTS
		then
			return { kind = "sticker", slot = slot }, nil
		end
		return nil, "malformed sticker request"
	elseif kind == "ping" then
		local id, x, y, z = fields.id, fields.x, fields.y, fields.z
		if
			type(id) == "string"
			and #id <= 32
			and type(x) == "number"
			and type(y) == "number"
			and type(z) == "number"
			and finite(x)
			and finite(y)
			and finite(z)
		then
			return { kind = "ping", id = id, at = Vector3.new(x, y, z) }, nil
		end
		return nil, "malformed ping request"
	end
	return nil, `unknown callout kind {tostring(kind)}`
end

-- A Shown packet's fields as a Shown (`at` only for a ping).
function CalloutRequestRules.shown(packet: {
	userId: number,
	kind: string,
	id: string,
	x: number,
	y: number,
	z: number,
}): CalloutConstants.Shown?
	if packet.kind == "ping" then
		return { userId = packet.userId, kind = "ping", id = packet.id, at = Vector3.new(packet.x, packet.y, packet.z) }
	elseif packet.kind == "sticker" then
		return { userId = packet.userId, kind = "sticker", id = packet.id }
	end
	return nil
end

return CalloutRequestRules
