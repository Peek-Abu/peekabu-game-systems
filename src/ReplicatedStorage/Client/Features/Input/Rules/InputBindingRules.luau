--!strict
--[=[
	InputBindingRules: the pure core of input resolution.

	- `reachable(stack, base)`: the contexts an action may fire in right now. Walking the stack from the
	  top, every context down to and including the first sinking one is reachable; the base context is
	  reachable only when nothing above it sinks.
	- `actionsFor(key, ids, lookup, overrides, reachable)`: the actions a physical key triggers.
	- `effective(defaults, override)`: an action's bindings with an override applied per device.

	No Instances, no services: the shell (InputServiceClient) feeds it.

	@class InputBindingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputTypes = require(ReplicatedStorage.Client.Features.Input.Data.InputTypes)

type InputKey = InputTypes.InputKey
type Bindings = InputTypes.Bindings
type ActionDef = InputTypes.ActionDef
type ContextEntry = InputTypes.ContextEntry

local InputBindingRules = {}

--[=[
	True iff `key` is a gamepad KeyCode (a button, the d-pad or a thumbstick).
	@param key InputKey
	@return boolean
]=]
function InputBindingRules.isGamepadKey(key: InputKey): boolean
	if key.EnumType ~= Enum.KeyCode then
		return false
	end
	local name = key.Name
	return string.match(name, "^Button") ~= nil
		or string.match(name, "^DPad") ~= nil
		or string.match(name, "^Thumbstick") ~= nil
end

--[=[
	The set of contexts reachable from the top of `stack` (see the module header).
	@param stack { ContextEntry } -- bottom first, as InputContextTracker snapshots it
	@param base string -- the always-present bottom context
	@return { [string]: boolean }
]=]
function InputBindingRules.reachable(stack: { ContextEntry }, base: string): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for index = #stack, 1, -1 do
		local entry = stack[index]
		set[entry.name] = true
		if entry.sink then
			return set
		end
	end
	set[base] = true
	return set
end

--[=[
	An action's bindings with `override` applied: each device the override lists replaces the default
	list for that device; an unlisted device keeps its default.
	@param defaults Bindings
	@param override Bindings?
	@return Bindings
]=]
function InputBindingRules.effective(defaults: Bindings, override: Bindings?): Bindings
	if override == nil then
		return defaults
	end
	return {
		keyboard = if override.keyboard ~= nil then override.keyboard else defaults.keyboard,
		gamepad = if override.gamepad ~= nil then override.gamepad else defaults.gamepad,
	}
end

local function bindsKey(bindings: Bindings, key: InputKey): boolean
	local keyboard = bindings.keyboard
	if keyboard ~= nil and table.find(keyboard, key) ~= nil then
		return true
	end
	-- Gamepad lists hold KeyCodes only; compare by enum type and name, which identify an EnumItem
	-- exactly and keep this cast-free across the KeyCode | UserInputType union.
	local gamepad = bindings.gamepad
	if gamepad ~= nil and key.EnumType == Enum.KeyCode then
		for _, button in gamepad do
			if button.Name == key.Name then
				return true
			end
		end
	end
	return false
end

--[=[
	The actions `key` triggers: every registered action, in `ids` order, whose context is reachable and
	whose effective bindings include the key.
	@param key InputKey
	@param ids { string } -- registered action ids, in a stable order
	@param lookup (id: string) -> ActionDef?
	@param overrides { [string]: Bindings }
	@param reachableSet { [string]: boolean }
	@return { string }
]=]
function InputBindingRules.actionsFor(
	key: InputKey,
	ids: { string },
	lookup: (id: string) -> ActionDef?,
	overrides: { [string]: Bindings },
	reachableSet: { [string]: boolean }
): { string }
	local found: { string } = {}
	for _, id in ids do
		local def = lookup(id)
		if def ~= nil and reachableSet[def.context] then
			if bindsKey(InputBindingRules.effective(def.bindings, overrides[id]), key) then
				table.insert(found, id)
			end
		end
	end
	return found
end

return InputBindingRules
