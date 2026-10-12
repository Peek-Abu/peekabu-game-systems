--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local SceneRegistry = require(ReplicatedStorage.Client.UI.Scenes.SceneRegistry)
local VM = require(script.Parent.DepotHubViewModel)
local Screen = require(script.Parent.DepotHubScreen)
local function register(page: VM.Page)
	local name = VM.scene(page)
	if not SceneRegistry.has(name) then
		SceneRegistry.register({
			name = name,
			screens = {
				{
					layer = "Panel",
					key = page,
					component = function()
						return React.createElement(Screen, { page = page })
					end,
				},
			},
			suppress = { mouse = true },
			hud = "hidden",
		})
	end
end
register("guide")
register("gear")
register("settings")
return {}
