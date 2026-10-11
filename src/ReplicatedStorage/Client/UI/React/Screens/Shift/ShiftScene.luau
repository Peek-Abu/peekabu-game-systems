--!strict
--[=[
	ShiftScene: registers the performance review scene (Cleanup Crew M3 UI, Figma 5a/5b/5c): the review on the Panel
	layer, the mouse freed, the HUD hidden. ShiftServiceClient pushes it when results begin and removes it when they
	end; Escape takes it off the stack and the ShiftReviewTab HUD widget pushes it again while the vote runs.
	Declarative (registers at require).

	@class ShiftScene
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local ShiftReviewScreen = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewScreen)

if not SceneRegistry.has(ShiftConstants.REVIEW_SCENE) then
	SceneRegistry.register({
		name = ShiftConstants.REVIEW_SCENE,
		screens = { { layer = "Panel", key = "review", component = ShiftReviewScreen } },
		suppress = { mouse = true },
		hud = "hidden",
	})
end

return {}
