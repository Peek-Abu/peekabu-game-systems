--!strict
--[=[
	CharacterPickScene: registers the first-join pick scene (CharacterPickScreen on the Panel layer, the mouse free,
	the HUD hidden) at require. DepotServiceClient opens and closes it (CharacterPickViewModel.shouldOpen).

	@class CharacterPickScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local CharacterPickScreen = require(script.Parent.CharacterPickScreen)
local VM = require(script.Parent.CharacterPickViewModel)

if not SceneRegistry.has(VM.SCENE) then
	SceneRegistry.register({
		name = VM.SCENE,
		screens = {
			{
				layer = "Panel",
				key = "characterPick",
				component = function()
					return React.createElement(CharacterPickScreen, {})
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
