--!strict
--[=[
	FilmCameraStore: the film camera's status line (speed, zoom, marks, glide length, what it follows), nil while the
	camera is off. FilmCameraSystem writes it; the FilmCameraStatus HUD widget shows it.

	@class FilmCameraStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local none: string? = nil

return {
	status = Charm.atom(none),
}
