--!strict
--[=[
	UIDebugScenes: throwaway scenes the F4 "UI" debugger tab pushes, so the scene stack and world
	suppression can be exercised BEFORE any real screen exists (the V2 checkpoint).

	⚠ HARNESS SCAFFOLDING. `PanelA` carries a throwaway placeholder screen so the SceneHost render path is
	observable; `PanelB`/`Movement` carry none (they exercise only the stack + suppression union). They
	exist to make the mechanics observable. Registered on require; the UI debugger tab requires this
	module. They are inert unless the (admin-gated) debugger pushes them.

	The three shapes are chosen to make composition AND the seam visible:
	- `PanelA` requests mouse + blur AND hides the HUD (`hud = "hidden"`) → pushing it is a live test of
	  the HudRoot hide gate (the whole HUD fades out; pop it and the HUD fades back).
	- `PanelB` requests mouse and declares `hud = "visible"` → pushing it OVER PanelA is a live test of
	  the topmost-opinion rule: the HUD fades back in (B overrides A), and popping B hides it again.
	- `PanelA` + `PanelB` both request mouse → pushing both shows mouse count 2 (HANDLED — engaged once,
	  the refcount compose the old game couldn't do) and blur count 1 (PanelA only).
	- blur and `Movement`'s movement are declared capabilities with NO handler this phase → the
	  "declared but unhandled, logged once" seam is observable (a VFX/Input system registers them later).

	@class UIDebugScenes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local DebugPanelScreen = require(ReplicatedStorage.Client.UI.React.Debugger.DebugPanelScreen)

local UIDebugScenes = {
	PANEL_A = "debug.PanelA",
	PANEL_B = "debug.PanelB",
	MOVEMENT = "debug.Movement",
}

SceneRegistry.register({
	name = UIDebugScenes.PANEL_A,
	-- A real screen now, so pushing PanelA mounts a panel via SceneHost (proving the render path).
	screens = { { layer = "Panel", key = "main", component = DebugPanelScreen } },
	suppress = { mouse = true, blur = true },
	hud = "hidden",
})
SceneRegistry.register({
	name = UIDebugScenes.PANEL_B,
	screens = {},
	suppress = { mouse = true },
	hud = "visible",
})
SceneRegistry.register({
	name = UIDebugScenes.MOVEMENT,
	screens = {},
	suppress = { movement = true },
})

return UIDebugScenes
