--!strict
--[=[
	DealChooserScene: registers the one-time deal chooser (DealChooserScreen on the Panel layer, the mouse free, the HUD
	hidden). DealServiceClient registers it at init with its choose callback, and opens and closes it (DealRules.pending).

	@class DealChooserScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealChooserScreen = require(script.Parent.DealChooserScreen)
local VM = require(script.Parent.DealViewModel)

local DealChooserScene = {}

function DealChooserScene.register(onChoose: (deal: DealConstants.DealId, choice: string) -> ())
	if SceneRegistry.has(VM.SCENE) then
		return
	end
	SceneRegistry.register({
		name = VM.SCENE,
		screens = {
			{
				layer = "Panel",
				key = "dealChooser",
				component = function()
					return React.createElement(DealChooserScreen, { onChoose = onChoose })
				end,
			},
		},
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return DealChooserScene
