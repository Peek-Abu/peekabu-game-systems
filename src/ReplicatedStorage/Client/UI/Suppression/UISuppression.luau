--!strict
--[=[
	UISuppression: the shared world-suppression singleton (like StateSyncClientStore is shared state, driven by
	StateSyncServiceClient). Wires the pure UIWorldSuppression core to the real scene resolver and the
	ONE handler UI legitimately owns — the mouse (freeing the pointer for UI) — and exposes
	`registerHandler`/`reconcile`/`counts`. Everything that needs suppression requires THIS module;
	UIServiceClient drives `reconcile` off the scene stack.

	**Everything else is a seam, not UI's job.** `blur` (a post-processing effect), `movement`
	and `cameraState` are declared in the SuppressionRecord so scenes can ASK for
	them, but this module registers no handler for them — the owning system registers one (Input
	registers `movement`; VFX/post-fx and Camera will register `blur` and `cameraState`). Until then a
	request is logged once and adopted the moment the handler arrives, with zero change to any scene
	or to this module. That is the "is this slottable?" answer, made concrete: UI declares intent,
	the specialist systems supply the mechanism.

	Exempt from the spec-first rule: the mouse handler touches UserInputService, which TestEZ cannot
	fixture. The refcount/union logic it plugs into is the fully-specced UIWorldSuppression core.

	@class UISuppression
]=]

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

-- Built-in handler: mouse. Free the pointer for UI via ModalEnabled, restoring the prior value on
-- release. engage/disengage fire only on the 0↔1 transition, so save-on-engage is safe.
local savedModalEnabled = false
core.registerHandler("mouse", {
	engage = function()
		savedModalEnabled = UserInputService.ModalEnabled
		UserInputService.ModalEnabled = true
	end,
	disengage = function()
		UserInputService.ModalEnabled = savedModalEnabled
	end,
})

return core
