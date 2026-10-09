--!strict
--[=[
	InputConstants: the input contexts the base knows, and the default actions it registers.

	A game adds its own contexts here (a riding or spectating mode) and its own actions through
	InputActionRegistry.register; the defaults below are the actions every game on the base shares.

	@class InputConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputTypes = require(ReplicatedStorage.Client.Features.Input.Data.InputTypes)

-- The bottom of every context stack: ordinary play. Always reachable unless a sinking context covers it.
local BASE_CONTEXT = "gameplay"

local contextList: { string } = {
	BASE_CONTEXT,
	-- Menus and panels: pushed (sinking) while a scene suppresses movement, so gameplay actions go quiet.
	"ui",
}
local CONTEXTS = table.freeze(contextList)

local defaults: { [string]: InputTypes.ActionDef } = {
	interact = {
		context = BASE_CONTEXT,
		bindings = { keyboard = { Enum.KeyCode.E }, gamepad = { Enum.KeyCode.ButtonX } },
		description = "Interact with what you are looking at",
	},
	sprint = {
		context = BASE_CONTEXT,
		bindings = { keyboard = { Enum.KeyCode.LeftShift }, gamepad = { Enum.KeyCode.ButtonL3 } },
		description = "Sprint while held",
	},
}
local DEFAULT_ACTIONS = table.freeze(defaults)

local InputConstants = {
	BASE_CONTEXT = BASE_CONTEXT,
	CONTEXTS = CONTEXTS,
	DEFAULT_ACTIONS = DEFAULT_ACTIONS,
}

--[=[
	True iff `name` is a declared context.
	@param name string
	@return boolean
]=]
function InputConstants.isContext(name: string): boolean
	return table.find(CONTEXTS, name) ~= nil
end

return InputConstants
