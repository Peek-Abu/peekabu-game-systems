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
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
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
					-- Where it was asked to open (UIStore.inventoryAt, read once as it opens, then cleared).
					local at = React.useState(UIStore.inventoryAt())
					React.useEffect(function()
						UIStore.inventoryAt(nil)
					end, {})
					return React.createElement(InventoryScreen, {
						employee = if at ~= nil then at.employee else nil,
						tab = if at ~= nil then at.tab else nil,
						item = if at ~= nil then at.item else nil,
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
		-- Fills the screen: a reveal beneath (its spot pickers open the Inventory over it) never shows through, even
		-- while an emote page moves the backdrop onto the 3D preview stage.
		covers = true,
	})
end

return {}
