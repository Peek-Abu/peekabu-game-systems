--!nocheck
-- `--!nocheck` (not `--!strict`): this file requires the PlayerModule, which Roblox inserts into
-- PlayerScripts at RUNTIME. It is not in the static sourcemap, so luau-lsp reports an unknown require
-- and there is no typed PlayerModule to assert against (the AdminServiceClient/CmdrClient precedent).
-- Only the controls toggle belongs in this file.
--[=[
	InputControlsSystem: turns the local character's movement controls off and on, through the
	PlayerModule's controls (`GetControls():Disable()` / `:Enable()`), which every platform's movement
	(keyboard, gamepad, touch thumbstick) goes through.

	Spec-exempt shell: it touches only the runtime PlayerModule.

	@class InputControlsSystem
]=]

local Players = game:GetService("Players")

local InputControlsSystem = {}

local controls = nil

local function getControls()
	if controls == nil then
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
		controls = playerModule:GetControls()
	end
	return controls
end

--[=[
	Enables or disables the local character's movement controls. May yield the first time (waits for
	the PlayerModule).
	@param enabled boolean
]=]
function InputControlsSystem.setEnabled(enabled: boolean)
	local current = getControls()
	if enabled then
		current:Enable()
	else
		current:Disable()
	end
end

return InputControlsSystem
