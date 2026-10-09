--!strict
--[=[
	SettingKeybindUtils: the `keybinds` setting's compact string, parsed and formatted.

		interact=kb:F,MouseButton1/gp:ButtonY;sprint=kb:LeftControl

	Entries are `action=devices`, separated by `;`; devices are `kb:` and `gp:` lists separated by `/`; keys
	are comma-separated names. Keyboard keys are non-gamepad Enum.KeyCode names or MouseButton1-3; gamepad
	keys are KeyCode names starting with Button, DPad or Thumbstick (the Input feature's split). Action ids
	are letters, digits, `_` and `-`. Anything else rejects the whole string, so a stored value is always
	usable as a whole.

	@class SettingKeybindUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingConstants = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingConstants)
local SettingTypes = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingTypes)

type KeyNames = SettingTypes.KeyNames
type KeybindMap = SettingTypes.KeybindMap

export type KeyBindings = {
	keyboard: { Enum.KeyCode | Enum.UserInputType },
	gamepad: { Enum.KeyCode },
}

local keyboardKeys: { [string]: Enum.KeyCode | Enum.UserInputType } = {}
local gamepadKeys: { [string]: Enum.KeyCode } = {}

local function isGamepadName(name: string): boolean
	return string.match(name, "^Button") ~= nil
		or string.match(name, "^DPad") ~= nil
		or string.match(name, "^Thumbstick") ~= nil
end

for _, item in Enum.KeyCode:GetEnumItems() do
	if isGamepadName(item.Name) then
		gamepadKeys[item.Name] = item
	elseif item.Name ~= "Unknown" then
		keyboardKeys[item.Name] = item
	end
end
keyboardKeys.MouseButton1 = Enum.UserInputType.MouseButton1
keyboardKeys.MouseButton2 = Enum.UserInputType.MouseButton2
keyboardKeys.MouseButton3 = Enum.UserInputType.MouseButton3

local function splitKeys(list: string, known: { [string]: unknown }): { string }?
	local keys: { string } = {}
	for _, name in string.split(list, ",") do
		if known[name] == nil then
			return nil
		end
		table.insert(keys, name)
	end
	if #keys > SettingConstants.MAX_KEYS_PER_DEVICE then
		return nil
	end
	return keys
end

local SettingKeybindUtils = {}

--[=[
	Parses a keybinds string. Nil plus a reason when anything in it is malformed.
]=]
function SettingKeybindUtils.parse(text: string): (KeybindMap?, string?)
	local map: KeybindMap = {}
	if text == "" then
		return map, nil
	end
	if #text > SettingConstants.MAX_KEYBINDS_LENGTH then
		return nil, "keybinds are too long"
	end
	for _, entry in string.split(text, ";") do
		local action, devices = string.match(entry, "^([%w_%-]+)=(.+)$")
		if action == nil or devices == nil or #action > SettingConstants.MAX_KEY_LENGTH then
			return nil, `malformed keybind entry "{entry}"`
		end
		if map[action] ~= nil then
			return nil, `action "{action}" is bound twice`
		end
		local names: KeyNames = { keyboard = {}, gamepad = {} }
		for _, device in string.split(devices, "/") do
			local prefix, list = string.match(device, "^(%a%a):(.+)$")
			local keys = if prefix == "kb" and list ~= nil
				then splitKeys(list, keyboardKeys)
				elseif prefix == "gp" and list ~= nil then splitKeys(list, gamepadKeys)
				else nil
			if keys == nil then
				return nil, `malformed keys "{device}" for "{action}"`
			end
			if prefix == "kb" then
				names.keyboard = keys
			else
				names.gamepad = keys
			end
		end
		map[action] = names
	end
	return map, nil
end

--[=[
	Formats a map (actions sorted, so equal maps give equal strings).
]=]
function SettingKeybindUtils.format(map: KeybindMap): string
	local actions: { string } = {}
	for action in map do
		table.insert(actions, action)
	end
	table.sort(actions)
	local entries: { string } = {}
	for _, action in actions do
		local names = map[action]
		local devices: { string } = {}
		if #names.keyboard > 0 then
			table.insert(devices, `kb:{table.concat(names.keyboard, ",")}`)
		end
		if #names.gamepad > 0 then
			table.insert(devices, `gp:{table.concat(names.gamepad, ",")}`)
		end
		if #devices > 0 then
			table.insert(entries, `{action}={table.concat(devices, "/")}`)
		end
	end
	return table.concat(entries, ";")
end

--[=[
	Turns parsed key names into enums (names that are not known are skipped).
]=]
function SettingKeybindUtils.toBindings(names: KeyNames): KeyBindings
	local bindings: KeyBindings = { keyboard = {}, gamepad = {} }
	for _, name in names.keyboard do
		local key = keyboardKeys[name]
		if key ~= nil then
			table.insert(bindings.keyboard, key)
		end
	end
	for _, name in names.gamepad do
		local key = gamepadKeys[name]
		if key ~= nil then
			table.insert(bindings.gamepad, key)
		end
	end
	return bindings
end

return SettingKeybindUtils
