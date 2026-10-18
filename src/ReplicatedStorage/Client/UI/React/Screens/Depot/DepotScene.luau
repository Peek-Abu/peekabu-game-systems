--!strict
--[=[
	DepotScene: registers the depot's contract board scene (Cleanup Crew M3 UI, Figma 2a/2b): the board on the Panel
	layer, the mouse freed, the HUD hidden. DepotServiceClient pushes it when the board's prompt is used; CLOSE and
	Escape take it off the stack. Declarative (registers at require).

	@class DepotScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local DepotBoardScreen = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardScreen)

if not SceneRegistry.has(DepotConstants.BOARD_SCENE) then
	SceneRegistry.register({
		name = DepotConstants.BOARD_SCENE,
		screens = { { layer = "Panel", key = "board", component = DepotBoardScreen } },
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
