--!strict
--[=[
	UIGamepadStore: whether the player is on a gamepad right now (their last input). Key legends (the shift hint row,
	prompt chips) read it so a controller player sees controller buttons; UIGamepadFocusSystem feeds it.

	@class UIGamepadStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local UIGamepadRules = require(ReplicatedStorage.Client.Features.UI.Rules.UIGamepadRules)

-- Window focus and None say nothing about the device, so they keep the last answer.
local IGNORED: { [string]: boolean } = { Focus = true, None = true }

local active = Charm.atom(false)

local UIGamepadStore = { active = active }

function UIGamepadStore.setInput(inputType: Enum.UserInputType)
	if IGNORED[inputType.Name] then
		return
	end
	active(UIGamepadRules.isGamepad(inputType))
end

function UIGamepadStore.reset()
	active(false)
end

return UIGamepadStore
