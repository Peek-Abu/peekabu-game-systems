--!strict
--[=[
	UISuppression: the shared world-suppression singleton (like StateSyncClientStore is shared state, driven by
	StateSyncServiceClient). Wires the pure UIWorldSuppression core to the real scene resolver and the
	ONE handler UI legitimately owns — the mouse (freeing the pointer for UI, through a Modal button) — and exposes
	`registerHandler`/`reconcile`/`counts`. Everything that needs suppression requires THIS module;
	UIServiceClient drives `reconcile` off the scene stack.

	**Everything else is a seam, not UI's job.** `blur` (a post-processing effect), `movement`
	and `cameraState` are declared in the SuppressionRecord so scenes can ASK for
	them, but this module registers no handler for them — the owning system registers one (Input
	registers `movement`, Camera `cameraState`, Vfx `blur`). Until then a
	request is logged once and adopted the moment the handler arrives, with zero change to any scene
	or to this module. That is the "is this slottable?" answer, made concrete: UI declares intent,
	the specialist systems supply the mechanism.

	Exempt from the spec-first rule: the mouse handler touches UserInputService, which TestEZ cannot
	fixture. The refcount/union logic it plugs into is the fully-specced UIWorldSuppression core.

	@class UISuppression
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local UIWorldSuppression = require(script.Parent.UIWorldSuppression)

local log = Logger.new("UISuppression")

-- A scene name to its declared suppression (nil when the scene is unregistered or declares none).
local function resolveScene(name: string): SceneRegistry.SuppressionRecord?
	local def = SceneRegistry.get(name)
	return if def then def.suppress else nil
end

local core = UIWorldSuppression.new(resolveScene, function(message: string)
	log:warn(message)
end)

-- Built-in handler: mouse. Frees the pointer for UI while a scene asks for it. The engine locks the cursor to the
-- centre in first person and in shift lock, and only a visible GuiButton with `Modal` set overrides that lock
-- (`UserInputService.ModalEnabled` does not: it only hides the touch controls; that part is kept as it was). The modal
-- button is a zero-size, invisible TextButton in its own ScreenGui, made on first use and shown only
-- while engaged. engage/disengage fire only on the 0<->1 transition, so save-on-engage is safe.
local savedModalEnabled = false
local modalButton: TextButton? = nil

local function modal(): TextButton?
	local existing = modalButton
	local existingGui = if existing ~= nil then existing.Parent else nil
	if existing ~= nil and existingGui ~= nil and existingGui.Parent ~= nil then
		return existing
	end
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChildOfClass("PlayerGui") else nil
	if playerGui == nil then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UIMouseModal"
	gui.ResetOnSpawn = false
	local button = Instance.new("TextButton")
	button.Name = "FreeMouse"
	button.Size = UDim2.fromOffset(0, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Selectable = false
	button.Active = false
	button.Visible = false
	button.Modal = true
	button.Parent = gui
	gui.Parent = playerGui
	modalButton = button
	return button
end

core.registerHandler("mouse", {
	engage = function()
		savedModalEnabled = UserInputService.ModalEnabled
		UserInputService.ModalEnabled = true
		local button = modal()
		if button ~= nil then
			button.Visible = true
		end
	end,
	disengage = function()
		UserInputService.ModalEnabled = savedModalEnabled
		local button = modalButton
		if button ~= nil then
			button.Visible = false
		end
	end,
})

return core
