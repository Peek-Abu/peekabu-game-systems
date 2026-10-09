--!strict
--[=[
	InputTypes: the types the Input feature shares. Types only (spec-exempt).

	@class InputTypes
]=]

-- One physical input: a key / gamepad button, or a mouse button (which Roblox reports as a
-- UserInputType rather than a KeyCode).
export type InputKey = Enum.KeyCode | Enum.UserInputType

--[=[
	The keys that trigger an action, per device. `keyboard` holds keyboard KeyCodes and mouse-button
	UserInputTypes; `gamepad` holds gamepad KeyCodes. A device with no list has no binding.
]=]
export type Bindings = {
	keyboard: { InputKey }?,
	gamepad: { Enum.KeyCode }?,
}

export type ActionDef = {
	-- The context the action belongs to (InputConstants.CONTEXTS); it fires only while reachable.
	context: string,
	bindings: Bindings,
	-- Shown in rebinding UI and the debugger.
	description: string,
}

export type Phase = "begin" | "end"

export type ContextOptions = {
	-- A sinking context hides every context below it (a menu silencing gameplay).
	sink: boolean?,
}

-- One entry on the context stack (see InputContextTracker).
export type ContextEntry = {
	token: number,
	name: string,
	sink: boolean,
}

return {}
