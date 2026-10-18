--!strict
--[=[
	usePaperLayout: "phone" or "desktop" for the current device, from M5's specced ShiftPlatformRules.detect on the live
	viewport and input devices; re-renders when the viewport changes size. React hook (exempt: needs a renderer).

	@class usePaperLayout
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ShiftPlatformRules = require(ReplicatedStorage.Shared.Features.Shift.Rules.ShiftPlatformRules)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

-- Whether this device is a phone. Kept as a boolean in state because React's useState widens a string-literal
-- union to `string`; the hook maps it back to a Layout.
local function readIsPhone(): boolean
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080)
	local platform = ShiftPlatformRules.detect({
		touch = UserInputService.TouchEnabled,
		keyboard = UserInputService.KeyboardEnabled,
		gamepad = UserInputService.GamepadEnabled,
		tenFoot = GuiService:IsTenFootInterface(),
		shortSide = math.min(viewport.X, viewport.Y),
	})
	return platform == "phone"
end

local function usePaperLayout(): UIPaperConstants.Layout
	local isPhone, setIsPhone = React.useState(readIsPhone)
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setIsPhone(readIsPhone())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return if isPhone then "phone" else "desktop"
end

return usePaperLayout
