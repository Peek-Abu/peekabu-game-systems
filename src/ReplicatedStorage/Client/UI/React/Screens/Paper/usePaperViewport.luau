--!strict
--[=[
	usePaperViewport: the live viewport size (Workspace.CurrentCamera.ViewportSize), re-rendering when it changes.
	React hook (exempt: needs a renderer). Falls back to 1920x1080 when there is no camera yet.

	@class usePaperViewport
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local function readViewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080)
end

local function usePaperViewport(): Vector2
	local viewport, setViewport = React.useState(readViewport)
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewport(readViewport())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return viewport
end

return usePaperViewport
