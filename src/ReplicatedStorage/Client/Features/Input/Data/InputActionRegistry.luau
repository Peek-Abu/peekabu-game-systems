--!strict
--[=[
	InputActionRegistry: the catalog of named input actions.

	`register` is a developer-error contract (the ItemRegistry precedent): it validates and asserts
	loudly at boot rather than failing quietly, including on a second registration of the same id.
	`registerDefaults` registers InputConstants.DEFAULT_ACTIONS and is safe to call more than once.

	@class InputActionRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputClient = ReplicatedStorage.Client.Features.Input
local InputTypes = require(InputClient.Data.InputTypes)
local InputConstants = require(InputClient.Data.InputConstants)
local InputBindingRules = require(InputClient.Rules.InputBindingRules)

type ActionDef = InputTypes.ActionDef

-- The UserInputTypes a keyboard list may hold, by name (an EnumItem is identified by its enum type and
-- name; matching names keeps the check cast-free across the KeyCode | UserInputType union).
local MOUSE_BUTTON_NAMES: { [string]: boolean } = {
	MouseButton1 = true,
	MouseButton2 = true,
	MouseButton3 = true,
}

local definitions: { [string]: ActionDef } = {}

local InputActionRegistry = {}

--[=[
	Registers a new action. Asserts: the id is new; the context is declared; at least one binding
	exists; the gamepad list holds only gamepad keys; the keyboard list holds only keyboard keys and
	mouse buttons.
	@param id string
	@param def ActionDef
]=]
function InputActionRegistry.register(id: string, def: ActionDef)
	assert(definitions[id] == nil, `input action "{id}" is already registered`)
	assert(InputConstants.isContext(def.context), `input action "{id}" has unknown context "{def.context}"`)
	local keyboard = def.bindings.keyboard
	local gamepad = def.bindings.gamepad
	local count = (if keyboard ~= nil then #keyboard else 0) + (if gamepad ~= nil then #gamepad else 0)
	assert(count > 0, `input action "{id}" has no bindings`)
	if gamepad ~= nil then
		for _, key in gamepad do
			assert(InputBindingRules.isGamepadKey(key), `input action "{id}": {key.Name} is not a gamepad key`)
		end
	end
	if keyboard ~= nil then
		for _, key in keyboard do
			if key.EnumType == Enum.KeyCode then
				assert(
					not InputBindingRules.isGamepadKey(key),
					`input action "{id}": {key.Name} is a gamepad key in the keyboard list`
				)
			else
				assert(
					key.EnumType == Enum.UserInputType and MOUSE_BUTTON_NAMES[key.Name] == true,
					`input action "{id}": {key.Name} is not a keyboard key or mouse button`
				)
			end
		end
	end
	definitions[id] = def
end

--[=[
	Registers the base's default actions (InputConstants.DEFAULT_ACTIONS), skipping any already
	registered. Idempotent.
]=]
function InputActionRegistry.registerDefaults()
	for id, def in InputConstants.DEFAULT_ACTIONS do
		if definitions[id] == nil then
			InputActionRegistry.register(id, def)
		end
	end
end

function InputActionRegistry.get(id: string): ActionDef?
	return definitions[id]
end

function InputActionRegistry.has(id: string): boolean
	return definitions[id] ~= nil
end

--[=[
	Every registered id, sorted (a stable resolution order).
	@return { string }
]=]
function InputActionRegistry.ids(): { string }
	local ids: { string } = {}
	for id in definitions do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return InputActionRegistry
