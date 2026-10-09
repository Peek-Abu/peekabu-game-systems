--!strict
--[=[
	TitleRequestRules: the pure build/parse contract for titles packets (titles design spec,
	Decision 3). The client BUILDS the equip request, the server PARSES it at the trust boundary —
	`TitleEvents` packets carry `unknown` (the AnimationRequests/DebuggerEvents precedent), so
	this module is where the shape is actually enforced.

	Parsing validates SHAPE only: whether the id is registered is asserted by the service, and
	whether it is earned is its policy gate. An unknown-but-well-formed id degrades to a refused
	request with a logged reason, never a crash.

	@class TitleRequestRules
]=]

export type EquipRequest = {
	titleId: string,
}

local TitleRequestRules = {}

--[=[
	@param titleId string -- A registered title id
	@return EquipRequest
]=]
function TitleRequestRules.buildEquip(titleId: string): EquipRequest
	return { titleId = titleId }
end

--[=[
	@param payload unknown
	@return string? -- the requested title id, nil when the shape is wrong
	@return string? -- reason on failure
]=]
function TitleRequestRules.parseEquip(payload: unknown): (string?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; each field is shape-checked below
	local titleId = fields.titleId
	if type(titleId) ~= "string" or titleId == "" then
		return nil, "missing or non-string titleId"
	end
	return titleId, nil
end

return TitleRequestRules
