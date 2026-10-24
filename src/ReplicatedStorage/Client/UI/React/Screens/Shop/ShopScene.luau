--!strict
--[=[
	ShopScene: registers the Shop scene (ShopScreen on the Panel layer, the mouse free, the HUD hidden) at require.
	Required by DepotServiceClient (the Shop opens from the depot hub and from the Inventory's "See in Shop").

	@class ShopScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local ShopScreen = require(script.Parent.ShopScreen)
local VM = require(script.Parent.ShopViewModel)

if not SceneRegistry.has(VM.SCENE) then
	SceneRegistry.register({
		name = VM.SCENE,
		screens = {
			{
				layer = "Panel",
				key = "shop",
				component = function()
					return React.createElement(ShopScreen, {})
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
