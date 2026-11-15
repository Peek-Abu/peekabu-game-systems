--!strict
--[=[
	UIGamepadFocusSystem: gamepad menu focus (P1 device check, 11-14).

	- When a panel opens (or the player picks up a gamepad with one open), it selects a button in the top scene's
	  panel screen (GuiService:Select), so the stick and A work at once instead of waiting for the Select button.
	- When no panel is open it clears the selection, so a button left selected never eats the stick in play.
	- It keeps UIGamepadStore current from the last input type.
	The decisions are the specced UIGamepadRules; this is the GuiService / PlayerGui shell (spec-exempt).

	@class UIGamepadFocusSystem
]=]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIGamepadRules = require(ReplicatedStorage.Client.Features.UI.Rules.UIGamepadRules)
local UIGamepadStore = require(ReplicatedStorage.Client.Features.UI.State.UIGamepadStore)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)

-- SceneHost commits a frame or two after the stack changes; look this many frames for the screen to mount.
local MOUNT_FRAMES = 20

local stoppers: { () -> () } = {}
local generation = 0

-- The mounted panel screen frame SceneHost keyed `name`, if it is there yet.
local function findFrame(name: string): GuiObject?
	local player = Players.LocalPlayer
	local gui = if player ~= nil then player:FindFirstChildOfClass("PlayerGui") else nil
	local layer = if gui ~= nil then gui:FindFirstChild("UILayer_Panel") else nil
	local host = if layer ~= nil then layer:FindFirstChild("SceneHost", true) else nil
	local frame = if host ~= nil then host:FindFirstChild(name) else nil
	return if frame ~= nil and frame:IsA("GuiObject") then frame else nil
end

local function selectionInside(frame: GuiObject?): boolean
	local selected = GuiService.SelectedObject
	return selected ~= nil and frame ~= nil and selected:IsDescendantOf(frame)
end

-- Re-decides focus; a newer call supersedes one still waiting for its screen to mount.
local function refresh()
	generation += 1
	local mine = generation
	local stack = UIStore.sceneStack()
	local target = UIGamepadRules.targetFrame(stack, SceneStack.screensFor(stack, "Panel"))
	if target == nil then
		if UIGamepadRules.action(UIGamepadStore.active(), nil, false) == "clear" then
			GuiService.SelectedObject = nil
		end
		return
	end
	if not UIGamepadStore.active() then
		return
	end
	task.spawn(function()
		for _ = 1, MOUNT_FRAMES do
			if mine ~= generation then
				return
			end
			local frame = findFrame(target)
			if frame ~= nil and frame.AbsoluteSize.X > 0 then
				if UIGamepadRules.action(UIGamepadStore.active(), target, selectionInside(frame)) == "select" then
					GuiService:Select(frame)
				end
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local UIGamepadFocusSystem = {}

function UIGamepadFocusSystem.start()
	UIGamepadStore.setInput(UserInputService:GetLastInputType())
	local changed = UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local was = UIGamepadStore.active()
		UIGamepadStore.setInput(inputType)
		if UIGamepadStore.active() ~= was then
			refresh()
		end
	end)
	table.insert(stoppers, function()
		changed:Disconnect()
	end)
	table.insert(stoppers, Charm.subscribe(UIStore.sceneStack, refresh))
end

function UIGamepadFocusSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	generation += 1
end

return UIGamepadFocusSystem
