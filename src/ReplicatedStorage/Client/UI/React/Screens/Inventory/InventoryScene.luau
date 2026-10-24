--!strict
--[=[
	InventoryScene: registers the Inventory scene (InventoryScreen on the Panel layer, the mouse free, the HUD hidden)
	at require. Required by DepotServiceClient (the Inventory opens from the depot hub).

	@class InventoryScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local ShopViewModel = require(script.Parent.Parent.Shop.ShopViewModel)
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
					return React.createElement(InventoryScreen, {
						-- "See in Shop": the Shop opens over the Inventory on that item's page.
						onShop = function(id: string)
							ShopStore.open(id)
							SceneStack.push(ShopViewModel.SCENE)
						end,
					})
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
