--!strict
--[=[
	usePaperMotion: a binding that runs 0 -> 1 once over `seconds`, from mount, on RenderStepped (a stamp's pop, a
	sticky's slide). Writes the binding only, so the motion never re-renders. Remount the component (change its key)
	to replay it. React hook (exempt: needs a renderer and RunService).

	@class usePaperMotion
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)

local function usePaperMotion(seconds: number): React.Binding<number>
	local alpha, setAlpha = React.useBinding(0)

	React.useEffect(function(): () -> ()
		local elapsed = 0
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime
			local value = math.min(elapsed / seconds, 1)
			setAlpha(value)
			if value >= 1 and connection ~= nil then
				connection:Disconnect()
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, {})

	return alpha
end

return usePaperMotion
