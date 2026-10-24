--!strict
--[=[
	InventoryScene: registers the Inventory scene (InventoryScreen on the Panel layer, the mouse free, the HUD hidden)
	at require. Required by DepotServiceClient (the Inventory opens from the depot hub).

	@class InventoryScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local InventoryScreen = require(script.Parent.InventoryScreen)
local VM = require(script.Parent.InventoryViewModel)

if not SceneRegistry.has(VM.SCENE) then
	SceneRegistry.register({
		name = VM.SCENE,
		screens = {
			{
				layer = "Panel",
				key = "inventory",
				component = function()
					return React.createElement(InventoryScreen, {})
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
