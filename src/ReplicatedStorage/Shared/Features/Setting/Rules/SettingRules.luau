--!strict
--[=[
	SettingRules: pure settings logic shared by both realms — checking a requested value against its
	definition, reading with defaults, writing the stored map (defaults stored as absence), the `settings`
	slice validator, and the request contract (built by the client, parsed by the server).

	@class SettingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local SettingConstants = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingConstants)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)
local SettingTypes = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingTypes)
local SettingKeybindUtils = require(ReplicatedStorage.Shared.Features.Setting.Utils.SettingKeybindUtils)

type Settings = PlayerDataTypes.Settings
type SettingValue = SettingTypes.SettingValue
type SettingDef = SettingTypes.SettingDef

local SettingRules = {}

--[=[
	The value to store for a request, or nil plus a reason. Numbers must be finite and within range (then
	snap to `step`); a choice must be an option; keybinds must parse.
]=]
function SettingRules.coerce(def: SettingDef, value: unknown): (SettingValue?, string?)
	if def.kind == "number" then
		if type(value) ~= "number" or value ~= value then
			return nil, "expected a number"
		end
		if value < def.min or value > def.max then
			return nil, `must be between {def.min} and {def.max}`
		end
		local step = def.step
		if step == nil then
			return value, nil
		end
		local snapped = def.min + math.round((value - def.min) / step) * step
		-- Round away float noise (0.1 + 0.2), then keep it inside the range.
		snapped = math.round(snapped * 1e6) / 1e6
		return math.clamp(snapped, def.min, def.max), nil
	elseif def.kind == "boolean" then
		if type(value) ~= "boolean" then
			return nil, "expected a boolean"
		end
		return value, nil
	elseif def.kind == "choice" then
		if type(value) ~= "string" or table.find(def.options, value) == nil then
			return nil, "not one of the options"
		end
		return value, nil
	else
		if type(value) ~= "string" then
			return nil, "expected keybinds text"
		end
		local map, reason = SettingKeybindUtils.parse(value)
		if map == nil then
			return nil, reason
		end
		return value, nil
	end
end

--[=[
	A setting's current value: the stored one when it still fits its definition, else the default. Nil for
	an unregistered id.
]=]
function SettingRules.valueOf(settings: Settings, id: string): SettingValue?
	local def = SettingRegistry.get(id)
	if def == nil then
		return nil
	end
	local stored = settings.values[id]
	if stored ~= nil then
		local value = SettingRules.coerce(def, stored)
		if value ~= nil and value == stored then
			return value
		end
	end
	return def.default
end

--[=[
	Stores an already-coerced value (in place); the default is stored as absence. True when it changed.
]=]
function SettingRules.store(settings: Settings, id: string, value: SettingValue): boolean
	local def = SettingRegistry.get(id)
	if def ~= nil and value == def.default then
		return SettingRules.clear(settings, id)
	end
	if settings.values[id] == value then
		return false
	end
	settings.values[id] = value
	return true
end

function SettingRules.clear(settings: Settings, id: string): boolean
	if settings.values[id] == nil then
		return false
	end
	settings.values[id] = nil
	return true
end

function SettingRules.clearAll(settings: Settings): boolean
	if next(settings.values) == nil then
		return false
	end
	table.clear(settings.values)
	return true
end

--[=[
	The `settings` slice invariant: at most MAX_STORED values; a registered id holds a valid value; an
	unknown (retired) id holds a scalar.
]=]
function SettingRules.validate(settings: Settings): (boolean, string?)
	local values = settings.values
	if type(values) ~= "table" then
		return false, "settings.values must be a table"
	end
	local count = 0
	for id, value in values do
		count += 1
		if type(id) ~= "string" or #id > SettingConstants.MAX_KEY_LENGTH then
			return false, "bad setting id"
		end
		local def = SettingRegistry.get(id)
		if def ~= nil then
			local coerced, reason = SettingRules.coerce(def, value)
			if coerced == nil or coerced ~= value then
				return false, `setting "{id}": {reason or "not a stored value"}`
			end
		elseif type(value) ~= "number" and type(value) ~= "boolean" and type(value) ~= "string" then
			return false, `setting "{id}" must be a number, boolean or string`
		end
	end
	if count > SettingConstants.MAX_STORED then
		return false, `more than {SettingConstants.MAX_STORED} stored settings`
	end
	return true, nil
end

function SettingRules.buildSet(id: string, value: SettingValue): { [string]: SettingValue }
	return { kind = "set", id = id, value = value }
end

function SettingRules.buildReset(id: string): { [string]: SettingValue }
	return { kind = "reset", id = id }
end

function SettingRules.buildResetAll(): { [string]: SettingValue }
	return { kind = "resetAll" }
end

--[=[
	Parses a request at the server's trust boundary. Shape only: whether the id is registered and the
	value fits is the service's check.
]=]
function SettingRules.parseRequest(payload: unknown): (SettingTypes.SettingRequest?, string?)
	if type(payload) ~= "table" then
		return nil, "payload is not a table"
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; each field is shape-checked below
	local kind = fields.kind
	if kind == "resetAll" then
		return { kind = "resetAll" }, nil
	end
	local id = fields.id
	if type(id) ~= "string" or #id == 0 or #id > SettingConstants.MAX_KEY_LENGTH then
		return nil, "missing or bad id"
	end
	if kind == "reset" then
		return { kind = "reset", id = id }, nil
	end
	if kind ~= "set" then
		return nil, "unknown request kind"
	end
	local value = fields.value
	if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then
		return { kind = "set", id = id, value = value }, nil
	end
	return nil, "value must be a number, boolean or string"
end

return SettingRules
