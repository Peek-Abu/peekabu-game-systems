--!strict
--[=[
	HidePeekUtils: the peek camera's mode for a hiding spot (CameraServiceClient's custom mode). Split out of
	HideServiceClient.

	- `peekMode`: the spot's peek frame, turned toward the mouse (or the last touch) within PEEK_YAW / PEEK_PITCH, at
	  PEEK_FOV.

	@class HidePeekUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local CameraTypes = require(ReplicatedStorage.Client.Features.Camera.Data.CameraTypes)

local HidePeekUtils = {}

-- The peek: the spot's frame, turned toward the mouse (or the last touch) within PEEK_YAW / PEEK_PITCH.
function HidePeekUtils.peekMode(base: CFrame): CameraTypes.ModeDef
	return {
		kind = "custom",
		update = function(_dt: number): (CFrame, number?)
			local camera = Workspace.CurrentCamera
			local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1, 1)
			local mouse = UserInputService:GetMouseLocation()
			local x = math.clamp((mouse.X / math.max(viewport.X, 1)) * 2 - 1, -1, 1)
			local y = math.clamp((mouse.Y / math.max(viewport.Y, 1)) * 2 - 1, -1, 1)
			local turn = CFrame.Angles(0, -x * math.rad(HideConstants.PEEK_YAW), 0)
				* CFrame.Angles(-y * math.rad(HideConstants.PEEK_PITCH), 0, 0)
			return base * turn, HideConstants.PEEK_FOV
		end,
	}
end

return HidePeekUtils
