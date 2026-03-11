--!strict
--[=[
	useDrag: a React hook for pointer-drag interactions (moving AND resizing — both are "apply a
	pointer delta to some state", so one hook serves the window drag, the detail-panel drag, and the
	resize grips).

	Returns a `begin(input)` function to call from an element's InputBegan. While the pointer is held,
	every movement invokes `onDelta` with the frame-to-frame pixel delta; the caller applies it to
	whatever state it owns (a position offset, a size). Movement/end are tracked globally via
	UserInputService so the pointer can leave the grip element mid-drag without dropping it.

	@class useDrag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)

--[=[
	@param onDelta (delta: Vector2) -> () -- Applied per pointer movement while dragging
	@return (input: InputObject) -> () -- Call from InputBegan on the drag handle
]=]
local function useDrag(onDelta: (delta: Vector2) -> ()): (input: InputObject) -> ()
	-- The latest callback lives in a ref so the (empty-deps) effect below never goes stale.
	local callbackRef = React.useRef(onDelta)
	callbackRef.current = onDelta

	local draggingRef = React.useRef(false)
	local lastPositionRef = React.useRef(Vector2.zero)

	React.useEffect(function()
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if not draggingRef.current then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local position = Vector2.new(input.Position.X, input.Position.Y)
				local delta = position - (lastPositionRef.current or Vector2.zero)
				lastPositionRef.current = position
				local callback = callbackRef.current
				if callback then
					callback(delta)
				end
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				draggingRef.current = false
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, {})

	return function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingRef.current = true
			lastPositionRef.current = Vector2.new(input.Position.X, input.Position.Y)
		end
	end
end

return useDrag
