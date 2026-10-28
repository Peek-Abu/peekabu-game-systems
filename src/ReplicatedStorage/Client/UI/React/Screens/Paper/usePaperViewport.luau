--!strict
-- All screen-space UI resamples after subscribing and follows replacement cameras.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local UIViewportSystem = require(ReplicatedStorage.Client.Features.UI.Systems.UIViewportSystem)
local function usePaperViewport(): Vector2
	local viewport, setViewport = React.useState(function(): Vector2
		return UIViewportSystem.read()
	end)
	React.useEffect(function(): () -> ()
		return UIViewportSystem.observe(setViewport)
	end, {})
	return viewport
end
return usePaperViewport
