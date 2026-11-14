--!strict
--[=[
	ToonCoveredContext: whether the screen being drawn is hidden beneath a scene that covers the whole screen
	(SceneDef.covers, SceneStack.coveredIn). SceneHost provides it for each hosted screen; ToonBackdrop reads it so a
	covered screen never draws its backdrop onto the 3D preview stage's wall (a portal there would show through the
	covering scene's emote hero). Default false: a screen outside SceneHost draws as before.

	@class ToonCoveredContext
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local DEFAULT = false

return table.freeze({
	DEFAULT = DEFAULT,
	Context = React.createContext(DEFAULT),
})
