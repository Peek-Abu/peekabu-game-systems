--!strict
--[=[
	CosmeticRequestRules: the build/parse contract for CosmeticEvents packets. The client BUILDS a request, the
	server PARSES it at the trust boundary (packets carry `unknown`, the TitleRequestRules precedent).

	Parsing checks SHAPE only: one of the six change kinds, ids of 1-64 characters (`""` allowed only to clear an
	emote or sticker slot), whole-number slots and styles. Whether an item exists, is owned and fits is
	CosmeticRules' job in the service.

	@class CosmeticRequestRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)

type Change = CosmeticTypes.Change

export type PickRequest = {
	employee: string,
}

local CosmeticRequestRules = {}

local function isId(value: unknown): boolean
	return type(value) == "string" and #value >= 1 and #value <= CosmeticConstants.MAX_ID_LENGTH
end

local function isSlotId(value: unknown): boolean
	return value == "" or isId(value)
end

local function isWhole(value: unknown): boolean
	return type(value) == "number" and value == math.floor(value) and value == value
end

function CosmeticRequestRules.buildEquip(change: Change): Change
	return table.clone(change)
end

--[=[
	@return Change? -- nil when the shape is wrong
	@return string? -- why
]=]
function CosmeticRequestRules.parseEquip(payload: unknown): (Change?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; each field is shape-checked below
	local kind, id, employee, slot, style = fields.kind, fields.id, fields.employee, fields.slot, fields.style
	if kind == "employee" then
		if type(id) == "string" and isId(id) then
			return { kind = "employee", id = id }, nil
		end
	elseif kind == "skin" then
		if type(id) == "string" and isId(id) and type(style) == "number" and isWhole(style) then
			return { kind = "skin", id = id, style = style }, nil
		end
	elseif kind == "idle" then
		if type(id) == "string" and isId(id) and type(employee) == "string" and isId(employee) then
			return { kind = "idle", employee = employee, id = id }, nil
		end
	elseif kind == "emote" then
		if
			type(id) == "string"
			and isSlotId(id)
			and type(employee) == "string"
			and isId(employee)
			and type(slot) == "number"
			and isWhole(slot)
		then
			return { kind = "emote", employee = employee, slot = slot, id = id }, nil
		end
	elseif kind == "vacuum" then
		if type(id) == "string" and isId(id) then
			return { kind = "vacuum", id = id }, nil
		end
	elseif kind == "sticker" then
		if type(id) == "string" and isSlotId(id) and type(slot) == "number" and isWhole(slot) then
			return { kind = "sticker", slot = slot, id = id }, nil
		end
	else
		return nil, `unknown change kind {tostring(kind)}`
	end
	return nil, `malformed {tostring(kind)} change`
end

export type SeenRequest = {
	ids: { string },
}

function CosmeticRequestRules.buildSeen(ids: { string }): SeenRequest
	return { ids = table.clone(ids) }
end

--[=[
	A list of 1..MAX_SEEN ids (a plain array). Whether each is owned is CosmeticRules.unseen's job.
]=]
function CosmeticRequestRules.parseSeen(payload: unknown): ({ string }?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the field is shape-checked below
	local list = fields.ids
	if type(list) ~= "table" then
		return nil, "missing ids"
	end
	local entries = list :: { [unknown]: unknown } -- unknown -> indexable at the trust boundary; every key and value is checked below
	local count = 0
	for _ in entries do
		count += 1
	end
	if count < 1 or count > CosmeticConstants.MAX_SEEN then
		return nil, `ids must hold 1-{CosmeticConstants.MAX_SEEN} entries`
	end
	local ids: { string } = {}
	for index = 1, count do
		local id = entries[index]
		if type(id) ~= "string" or not isId(id) then
			return nil, "ids must be a list of item ids"
		end
		ids[index] = id
	end
	return ids, nil
end

function CosmeticRequestRules.buildPick(employee: string): PickRequest
	return { employee = employee }
end

function CosmeticRequestRules.parsePick(payload: unknown): (string?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the field is shape-checked below
	local employee = fields.employee
	if type(employee) ~= "string" or not isId(employee) then
		return nil, "missing or malformed employee"
	end
	return employee, nil
end

return CosmeticRequestRules
