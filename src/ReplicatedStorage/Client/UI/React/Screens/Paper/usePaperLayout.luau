--!strict
--[=[
	usePaperLayout: "phone" or "desktop" for the current device, from M5's specced ShiftPlatformRules.detect on the live
	viewport and input devices; re-renders when the viewport changes size. In Studio the Workspace attribute
	DEV_PHONE_ATTRIBUTE forces "phone", for reviewing phone layouts without a device. React hook (exempt: needs a
	renderer).

	@class usePaperLayout
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local usePaperViewport = require(script.Parent.usePaperViewport)
local ShiftPlatformRules = require(ReplicatedStorage.Shared.Features.Shift.Rules.ShiftPlatformRules)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

-- Studio only: forces the phone layout (layout reviews on a desktop window).
local DEV_PHONE_ATTRIBUTE = "DevPhoneLayout"

-- Derive layout from the same lifecycle-safe viewport hook used for screen sizing.
local function usePaperLayout(): UIPaperConstants.Layout
	local viewport = usePaperViewport()
	local platform = ShiftPlatformRules.detect({
		touch = UserInputService.TouchEnabled,
		keyboard = UserInputService.KeyboardEnabled,
		gamepad = UserInputService.GamepadEnabled,
		tenFoot = GuiService:IsTenFootInterface(),
		shortSide = math.min(viewport.X, viewport.Y),
	})
	if RunService:IsStudio() and Workspace:GetAttribute(DEV_PHONE_ATTRIBUTE) == true then
		return "phone"
	end
	return if platform == "phone" then "phone" else "desktop"
end
return usePaperLayout
