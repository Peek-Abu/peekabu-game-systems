--!strict
--[=[
	InventoryScene: registers the real `Inventory` scene — the first non-harness scene. It shows the
	`InventoryPanel` on the `Panel` layer, frees the mouse and asks for blur (a declared seam), and hides
	the HUD while open. Required by `UIServiceClient` at boot so the registration happens once, the same
	way `UIDebugScenes` is required by the debugger tab.

	**This is also where the panel is joined to the network.** The panel takes its equip/unequip actions as
	a prop and requires no service itself, so the ByteNet-backed `EquipmentServiceClient` is required HERE
	— at the boot-time registration — and nowhere in the render tree. That keeps the panel renderable
	outside a running game (UI Labs has no server, and ByteNet's client path waits forever for one).

	@class InventoryScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local InventoryPanel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryPanel)
local EquipmentServiceClient = require(ReplicatedStorage.Client.Features.Equipment.EquipmentServiceClient)

local e = React.createElement

local InventoryScene = {
	SCENE = "Inventory",
}

-- Plain functions over the service's colon methods: the panel declares what it needs to DO, not which
-- service does it.
local EQUIPMENT_ACTIONS: InventoryPanel.EquipmentActions = {
	equip = function(uid: string)
		EquipmentServiceClient:equip(uid)
	end,
	unequip = function(slotId: string)
		EquipmentServiceClient:unequip(slotId)
	end,
}

SceneRegistry.register({
	name = InventoryScene.SCENE,
	screens = {
		{
			layer = "Panel",
			key = "main",
			-- Wrapped rather than passed directly: a scene screen renders with no arguments.
			component = function()
				return e(InventoryPanel, { equipment = EQUIPMENT_ACTIONS })
			end,
		},
	},
	suppress = { mouse = true, blur = true },
	hud = "hidden",
})

return InventoryScene
