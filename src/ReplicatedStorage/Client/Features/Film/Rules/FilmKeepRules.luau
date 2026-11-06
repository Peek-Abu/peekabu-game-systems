--!strict
--[=[
	FilmKeepRules: what the film hide (F6) leaves showing. Pure.

	- "none" (the default): only the admin console, so the UI can always be brought back.
	- "screen" (Shift+F6 switches to it): also the open screen, the Panel layer's root, where the results card, the
	  Locker, the reveal and the shop draw. The HUD, the floating labels and the prompts still hide.

	@class FilmKeepRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmConstants = require(ReplicatedStorage.Shared.Features.Film.Data.FilmConstants)

export type Mode = "none" | "screen"

local FilmKeepRules = {}

function FilmKeepRules.keeps(guiName: string, mode: Mode): boolean
	if FilmConstants.KEEP_GUIS[guiName] == true then
		return true
	end
	return mode == "screen" and guiName == FilmConstants.SCREEN_LAYER_GUI
end

function FilmKeepRules.nextMode(mode: Mode): Mode
	return if mode == "none" then "screen" else "none"
end

return FilmKeepRules
