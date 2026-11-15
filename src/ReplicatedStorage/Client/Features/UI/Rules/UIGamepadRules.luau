--!strict
--[=[
	UIGamepadRules: the pure decisions behind gamepad menu focus (P1 device check, 11-14). A panel opened on a gamepad
	had no selected button, so the stick did nothing until the player found the Select button; and a selection left
	behind after a menu closed would keep eating the stick. UIGamepadFocusSystem applies what these decide.

	@class UIGamepadRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)

export type Action = "select" | "clear" | "none"

local UIGamepadRules = {}

--[=[
	True for any gamepad's input (Gamepad1..Gamepad8); false for keyboard, mouse and touch.
	@param inputType Enum.UserInputType
	@return boolean
]=]
function UIGamepadRules.isGamepad(inputType: Enum.UserInputType): boolean
	return string.sub(inputType.Name, 1, 7) == "Gamepad"
end

--[=[
	The frame name SceneHost gives the top scene's first panel screen (`scene:screenKey`), or nil when nothing is open
	or the top scene draws no panel (a wheel, which the stick drives by angle).
	@param stack { string } -- the scene stack, bottom first
	@param hosted { SceneStack.HostedScreen } -- SceneStack.screensFor(stack, "Panel")
	@return string?
]=]
function UIGamepadRules.targetFrame(stack: { string }, hosted: { SceneStack.HostedScreen }): string?
	local top = stack[#stack]
	if top == nil then
		return nil
	end
	for _, entry in hosted do
		if entry.scene == top then
			return `{entry.scene}:{entry.screen.key}`
		end
	end
	return nil
end

--[=[
	What to do with the gamepad selection: select a button in the open panel for a gamepad player whose selection is
	not already in it; clear it once no panel is open (so the stick moves the character again); else nothing.
	@param gamepad boolean -- the player's last input was a gamepad
	@param target string? -- UIGamepadRules.targetFrame
	@param selectionInside boolean -- the current selection already sits in the target frame
	@return Action
]=]
function UIGamepadRules.action(gamepad: boolean, target: string?, selectionInside: boolean): Action
	if target == nil then
		return "clear"
	end
	if gamepad and not selectionInside then
		return "select"
	end
	return "none"
end

return UIGamepadRules
