--!strict
--[=[
	FilmCameraStatus: the film camera's one-line status (FilmCameraStore.status) at the bottom left, an admin's filming
	tool, not player UI. Nothing while the camera is off; F6 hides it with the rest of the HUD.

	@class FilmCameraStatus
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local FilmCameraStore = require(ReplicatedStorage.Client.Features.Film.State.FilmCameraStore)

local function FilmCameraStatus(): React.ReactNode
	local status = ReactCharm.useAtom(FilmCameraStore.status)
	if status == nil then
		return nil
	end
	return React.createElement("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(640, 22),
		BackgroundTransparency = 0.4,
		BackgroundColor3 = Color3.new(0, 0, 0),
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Text = status,
	})
end

return FilmCameraStatus
