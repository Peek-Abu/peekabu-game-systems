--!strict
--[=[
	AnalyticsRules: cleaning event names and building AnalyticsService custom fields. Pure.

	Custom fields are up to three short strings that segment an event (an item, a night, a mode); the engine
	keys them CustomField01..03.

	@class AnalyticsRules
]=]

local AnalyticsRules = {}

AnalyticsRules.MAX_NAME_LENGTH = 50

local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

--[=[
	A trimmed, length-capped name; nil when nothing is left.
]=]
function AnalyticsRules.name(raw: string): string?
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end
	return string.sub(trimmed, 1, AnalyticsRules.MAX_NAME_LENGTH)
end

--[=[
	The engine's custom-field map for up to three values (the rest are ignored); nil with none.
]=]
function AnalyticsRules.customFields(values: { string }?): { [string]: string }?
	if values == nil or #values == 0 then
		return nil
	end
	local fields: { [string]: string } = {}
	for index, key in FIELD_KEYS do
		local value = values[index]
		if value ~= nil then
			fields[key] = string.sub(value, 1, AnalyticsRules.MAX_NAME_LENGTH)
		end
	end
	return fields
end

return AnalyticsRules
