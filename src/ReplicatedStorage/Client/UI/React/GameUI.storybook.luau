--!strict
--[=[
	GameUI.storybook: the UI Labs storybook that owns this project's stories.

	Without one, UI Labs files every `*.story` module under a catch-all "Unknown Stories" node. Declaring
	the roots here groups them the way the source tree is already organised — `Primitives` and `Screens`
	as separate folders (that is what `groupRoots` does).

	Adding a story anywhere under those two folders is picked up automatically; this file only needs
	editing if a NEW top-level story location appears.

	@class GameUI.storybook
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = ReplicatedStorage.Client.UI.React

return {
	name = "Game UI",
	storyRoots = { React.Primitives, React.Screens },
	groupRoots = true,
}
