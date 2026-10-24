--!strict
--[=[
	RevealScene: registers the reveal scene (RevealScreen on the Panel layer, the mouse free, the HUD hidden) at
	require. DepotServiceClient opens it while CosmeticRevealStore holds a reveal and the player is in the depot.

	@class RevealScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local RevealScreen = require(script.Parent.RevealScreen)
local VM = require(script.Parent.RevealViewModel)

if not SceneRegistry.has(VM.SCENE) then
	SceneRegistry.register({
		name = VM.SCENE,
		screens = {
			{
				layer = "Panel",
				key = "reveal",
				component = function()
					return React.createElement(RevealScreen, {})
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
