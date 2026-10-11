--!strict
--[=[
	useTypedGraphemes: a MaxVisibleGraphemes binding that types `text` out at `rate` characters a second, from when the
	text appears (OccupantFeedbackUtils.reveal), and reads -1 once the whole line is out. It restarts only when `text`
	or `rate` changes, so a re-render with the same line never retypes it. A layout effect, so a new line resets to 0
	before it paints (no one-frame flash of the whole line). Writes the binding only, on RenderStepped.
	React hook (exempt: needs a renderer and RunService); the reveal maths is the specced OccupantFeedbackUtils.reveal.

	@class useTypedGraphemes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local OccupantFeedbackUtils = require(ReplicatedStorage.Shared.Features.Occupant.Utils.OccupantFeedbackUtils)

local function useTypedGraphemes(text: string, rate: number): React.Binding<number>
	local shown, setShown = React.useBinding(0)
	React.useLayoutEffect(function(): () -> ()
		local total = utf8.len(text) or #text
		local started = os.clock()
		setShown(0)
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(_deltaTime: number)
			local count = OccupantFeedbackUtils.reveal(total, os.clock() - started, rate)
			if count >= total then
				setShown(-1)
				if connection ~= nil then
					connection:Disconnect()
				end
			else
				setShown(count)
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
		-- luau-lsp types the deps array from its first element, so the rate is keyed as a string (no cast).
	end, { text, tostring(rate) })
	return shown
end

return useTypedGraphemes
