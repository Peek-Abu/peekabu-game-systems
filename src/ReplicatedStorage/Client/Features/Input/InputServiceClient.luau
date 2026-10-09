--!strict
--[=[
	InputServiceClient: named input actions for the local player (design:
	docs/superpowers/specs/2026-10-09-input-design.md).

	Gameplay code binds to an ACTION ("interact"), never to a key. Keys resolve through the registry and
	the context stack (InputBindingRules); begin/end transitions come from InputActionTracker, so two keys
	bound to one action begin it once and end it once. When the stack changes, a held action whose
	context is no longer reachable gets its `end` immediately.

	It also owns the UI's `movement` suppression seam: while a scene suppresses movement, the character's
	controls are disabled and a sinking `ui` context silences gameplay actions.

	Spec-exempt shell (UserInputService, PlayerModule); the rules live in the specced Data, Rules and
	State modules beside it.

	@class InputServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputClient = ReplicatedStorage.Client.Features.Input
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InputTypes = require(InputClient.Data.InputTypes)
local InputConstants = require(InputClient.Data.InputConstants)
local InputActionRegistry = require(InputClient.Data.InputActionRegistry)
local InputBindingRules = require(InputClient.Rules.InputBindingRules)
local InputContextTracker = require(InputClient.State.InputContextTracker)
local InputActionTracker = require(InputClient.State.InputActionTracker)
local InputControlsSystem = require(InputClient.Systems.InputControlsSystem)
local UISuppression = require(ReplicatedStorage.Client.UI.Suppression.UISuppression)

type Phase = InputTypes.Phase
type Bindings = InputTypes.Bindings
type InputKey = InputTypes.InputKey
type Callback = (phase: Phase) -> ()

local log = Logger.new("InputServiceClient")

local janitor = Janitor.new()
local contexts = InputContextTracker.new()
local actions = InputActionTracker.new()
local overrides: { [string]: Bindings } = {}
local listeners: { [string]: { Callback } } = {}
local counters = { began = 0, ended = 0, callbackErrors = 0 }

local MOUSE_BUTTONS: { Enum.UserInputType } = {
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseButton3,
}

local function fire(actionId: string, phase: Phase)
	if phase == "begin" then
		counters.began += 1
	else
		counters.ended += 1
	end
	local list = listeners[actionId]
	if list == nil then
		return
	end
	-- Copy first: a callback may unbind itself (or another) while we iterate.
	for _, callback in table.clone(list) do
		local ok, err = pcall(function()
			callback(phase)
		end)
		if not ok then
			counters.callbackErrors += 1
			log:error(`"{actionId}" {phase} callback failed: {tostring(err)}`)
		end
	end
end

local function reachableNow(): { [string]: boolean }
	return InputBindingRules.reachable(contexts:snapshot(), InputConstants.BASE_CONTEXT)
end

local function contextOf(actionId: string): string?
	local def = InputActionRegistry.get(actionId)
	return if def ~= nil then def.context else nil
end

-- After the stack changes: end every held action that just became unreachable.
local function settleHeld()
	for _, id in actions:dropUnreachable(contextOf, reachableNow()) do
		fire(id, "end")
	end
end

-- The physical key an InputObject represents, or nil for input we do not bind (movement, touch, ...).
local function keyOf(input: InputObject): InputKey?
	if table.find(MOUSE_BUTTONS, input.UserInputType) ~= nil then
		return input.UserInputType
	end
	-- Keyboard and gamepad buttons arrive with a KeyCode; everything else (movement, touch, wheel) is
	-- not ours to bind.
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.Keyboard or string.match(inputType.Name, "^Gamepad") ~= nil then
		return input.KeyCode
	end
	return nil
end

local function onBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	local key = keyOf(input)
	if key == nil then
		return
	end
	local keyName = tostring(key)
	local found =
		InputBindingRules.actionsFor(key, InputActionRegistry.ids(), InputActionRegistry.get, overrides, reachableNow())
	for _, id in found do
		if actions:press(id, keyName) then
			fire(id, "begin")
		end
	end
end

-- A release always ends what the key holds, whatever the context or focus now (held state never sticks).
local function onEnded(input: InputObject)
	local key = keyOf(input)
	if key == nil then
		return
	end
	local keyName = tostring(key)
	for _, id in actions:held() do
		if actions:release(id, keyName) then
			fire(id, "end")
		end
	end
end

export type InputServiceClient = {
	dependencies: { string },
	init: (self: InputServiceClient) -> (),
	start: (self: InputServiceClient) -> (),
	stop: (self: InputServiceClient) -> (),
	getState: (self: InputServiceClient) -> { [string]: any },

	bind: (self: InputServiceClient, actionId: string, callback: Callback) -> () -> (),
	isHeld: (self: InputServiceClient, actionId: string) -> boolean,
	pushContext: (self: InputServiceClient, name: string, options: InputTypes.ContextOptions?) -> number,
	removeContext: (self: InputServiceClient, token: number) -> boolean,
	setOverride: (self: InputServiceClient, actionId: string, bindings: Bindings?) -> (),
	bindingsFor: (self: InputServiceClient, actionId: string) -> Bindings?,
}

local InputServiceClient: InputServiceClient = {
	dependencies = {},

	--[=[
		Registers the default actions and connects the input listeners.
	]=]
	init = function(_self)
		InputActionRegistry.registerDefaults()
		janitor:Add(UserInputService.InputBegan:Connect(onBegan), "Disconnect")
		janitor:Add(UserInputService.InputEnded:Connect(onEnded), "Disconnect")
		-- Alt-tab drops every release we would otherwise see, so end everything held.
		janitor:Add(
			UserInputService.WindowFocusReleased:Connect(function()
				for _, id in actions:clear() do
					fire(id, "end")
				end
			end),
			"Disconnect"
		)
	end,

	--[=[
		Takes over the UI's `movement` suppression seam (a scene suppressing movement disables the
		character's controls and silences gameplay actions until it closes).
	]=]
	start = function(self)
		local uiToken: number? = nil
		UISuppression.registerHandler("movement", {
			engage = function()
				uiToken = self:pushContext("ui", { sink = true })
				task.spawn(InputControlsSystem.setEnabled, false)
			end,
			disengage = function()
				local token = uiToken
				if token ~= nil then
					self:removeContext(token)
					uiToken = nil
				end
				task.spawn(InputControlsSystem.setEnabled, true)
			end,
		})
	end,

	stop = function(_self)
		janitor:Cleanup()
		for _, id in actions:clear() do
			fire(id, "end")
		end
	end,

	--[=[
		Calls `callback("begin")` when the action starts and `callback("end")` when it stops. Returns a
		function that unbinds. Errors on an unregistered action (a typo should fail where it is written).
	]=]
	bind = function(_self, actionId, callback)
		assert(InputActionRegistry.has(actionId), `input action "{actionId}" is not registered`)
		local list = listeners[actionId]
		if list == nil then
			list = {}
			listeners[actionId] = list
		end
		table.insert(list, callback)
		return function()
			local current = listeners[actionId]
			local index = if current ~= nil then table.find(current, callback) else nil
			if current ~= nil and index ~= nil then
				table.remove(current, index)
			end
		end
	end,

	isHeld = function(_self, actionId)
		return actions:isHeld(actionId)
	end,

	--[=[
		Pushes a context; returns the token that removes it. A sinking context silences every context
		below it (held actions there end at once).
	]=]
	pushContext = function(_self, name, options)
		assert(InputConstants.isContext(name), `"{name}" is not a declared input context`)
		local sink = options ~= nil and options.sink == true
		local token = contexts:push(name, sink)
		settleHeld()
		return token
	end,

	removeContext = function(_self, token)
		local removed = contexts:remove(token)
		if removed then
			settleHeld()
		end
		return removed
	end,

	--[=[
		Rebinds an action for this session (per device; nil restores the default). Persisting it is the
		Settings system's job.
	]=]
	setOverride = function(_self, actionId, bindings)
		assert(InputActionRegistry.has(actionId), `input action "{actionId}" is not registered`)
		if bindings == nil then
			overrides[actionId] = nil
		else
			overrides[actionId] = bindings
		end
	end,

	--[=[
		The effective bindings of an action (default merged with any override) — for button prompts and
		rebinding UI. Nil for an unregistered action.
	]=]
	bindingsFor = function(_self, actionId)
		local def = InputActionRegistry.get(actionId)
		if def == nil then
			return nil
		end
		return InputBindingRules.effective(def.bindings, overrides[actionId])
	end,

	getState = function(_self)
		local stack: { string } = {}
		for _, entry in contexts:snapshot() do
			table.insert(stack, if entry.sink then `{entry.name} (sink)` else entry.name)
		end
		return {
			contexts = stack,
			held = actions:held(),
			counters = table.clone(counters),
		}
	end,
}

return InputServiceClient
