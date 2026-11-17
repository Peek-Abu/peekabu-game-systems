--!strict
--[=[
	ShiftKeyHintViewModel: the desktop key hints row of the Shift HUD (Figma 1a: "Hold LMB vacuum", "G drop", ...) from
	the live Input bindings, the key legends it and the prompt chip print (keyboard, mouse and gamepad names), and which
	action's gamepad bindings a hint reads. Pure (specced). Split out of ShiftKeyHintViewModel, which still exposes each of
	these under its old name.

	@class ShiftKeyHintViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

export type HintView = {
	prefix: string?,
	key: string,
	label: string,
}

-- A device's keyboard bindings per action id (InputServiceClient:bindingsFor(id).keyboard).
export type KeyBindings = { [string]: { Enum.KeyCode | Enum.UserInputType }? }

local ShiftKeyHintViewModel = {}

local KEY_NAMES: { [string]: string } = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	Left = "←",
	Right = "→",
	LeftShift = "Shift",
	LeftControl = "Ctrl",
	-- Gamepad buttons, as a controller prints them (Xbox names; the engine maps them on PlayStation).
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	DPadUp = "D↑",
	DPadDown = "D↓",
	DPadLeft = "D←",
	DPadRight = "D→",
}

-- A key's legend as the HUD prints it on a KeyChip.
function ShiftKeyHintViewModel.keyName(input: Enum.KeyCode | Enum.UserInputType): string
	return KEY_NAMES[input.Name] or input.Name
end

--[=[
	A prompt chip's key legend: the prompt's gamepad button for a controller player, its keyboard key otherwise.
]=]
function ShiftKeyHintViewModel.promptKey(keyboard: Enum.KeyCode, gamepad: Enum.KeyCode, padActive: boolean): string
	return ShiftKeyHintViewModel.keyName(if padActive then gamepad else keyboard)
end

-- Figma 1a's hint row, in order: the action id, how to say it, and whether it is held. `padAction` / `padHold` are
-- the gamepad's when they differ (crouch is a held Ctrl, but a B toggle on a controller).
local HINTS: { { action: string, label: string, hold: boolean, padAction: string?, padHold: boolean? } } = {
	{ action = VacuumConstants.ACTION, label = "vacuum", hold = true },
	{ action = "drop", label = "drop", hold = false },
	{ action = "throw", label = "throw", hold = false },
	{ action = "interact", label = "bank / search", hold = false },
	{ action = "sprint", label = "sprint", hold = true },
	{
		action = CrouchConstants.ACTION,
		label = "crouch",
		hold = true,
		padAction = CrouchConstants.TOGGLE_ACTION,
		padHold = false,
	},
}

--[=[
	The action whose gamepad bindings a hint reads (`crouch` reads `crouchToggle`); the hint's own action otherwise.
]=]
function ShiftKeyHintViewModel.padAction(action: string): string
	for _, hint in HINTS do
		if hint.action == action then
			return hint.padAction or action
		end
	end
	return action
end

local hintActions: { string } = {}
for _, hint in HINTS do
	table.insert(hintActions, hint.action)
end
-- The action ids the hint row reads bindings for (ShiftHud asks InputServiceClient for each).
ShiftKeyHintViewModel.HINT_ACTIONS = table.freeze(hintActions)

local function firstKey(bindings: KeyBindings, action: string): (Enum.KeyCode | Enum.UserInputType)?
	local list = bindings[action]
	return if list ~= nil then list[1] else nil
end

--[=[
	The key hints, one per action with a binding: "Hold LMB vacuum", "G drop", ... `bindings` is keyed by the hint's
	action and holds the keyboard list, or, with `gamepad` set, the gamepad list (crouch's from its toggle, not held).
]=]
function ShiftKeyHintViewModel.keyHints(bindings: KeyBindings, gamepad: boolean?): { HintView }
	local hints: { HintView } = {}
	for _, hint in HINTS do
		local first = firstKey(bindings, hint.action)
		if first ~= nil then
			local hold = if gamepad and hint.padHold ~= nil then hint.padHold else hint.hold
			table.insert(hints, {
				prefix = if hold then "Hold" else nil,
				key = ShiftKeyHintViewModel.keyName(first),
				label = hint.label,
			})
		end
	end
	return hints
end

return ShiftKeyHintViewModel
