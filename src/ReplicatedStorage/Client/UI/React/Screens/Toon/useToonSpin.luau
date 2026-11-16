--!strict
--[=[
	useToonSpin: a spinning ToonViewport's input (`spin`): a drag on the frame (either mouse button or a finger), the
	controller's right stick, and the coast after a flick, one frame at a time. Each new state goes into `spinState`,
	and a changed angle to `applySpin` (the model built now). React hook only ToonViewport uses (exempt: needs a
	renderer and input; the drag, coast and stick maths are specced in ToonSpinViewModel). Split out of ToonViewport.

	@class useToonSpin
]=]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ToonSpinViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSpinViewModel)

-- A drag that has not moved for this long (seconds) before letting go does not coast.
local SPIN_HOLD_STILL = 0.08
-- Each spinning viewport binds the right stick under its own action name.
local spinActions = 0

local function useToonSpin(
	frame: ViewportFrame?,
	spin: boolean?,
	spinState: { current: ToonSpinViewModel.State },
	applySpin: { current: ((angle: number) -> ())? }
)
	local spinDeps: { unknown } = { frame, spin == true }
	-- The player's spin: a drag on the frame (either mouse button or a finger), the right stick, and the coast after a
	-- flick, one frame at a time.
	React.useEffect(function(): () -> ()
		local window = frame
		if not window or spin ~= true then
			return function() end
		end
		local function set(state: ToonSpinViewModel.State)
			local was = spinState.current.angle
			spinState.current = state
			local apply = applySpin.current
			if apply ~= nil and state.angle ~= was then
				apply(state.angle)
			end
		end
		local noGrip: InputObject? = nil
		local grip = noGrip
		local lastX, lastAt = 0, 0
		local stick = 0
		local began = window.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if grip ~= nil then
				return
			end
			if
				kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.MouseButton2
				or kind == Enum.UserInputType.Touch
			then
				grip = input
				lastX, lastAt = input.Position.X, os.clock()
				set(ToonSpinViewModel.drag(spinState.current, 0, window.AbsoluteSize.X, 0))
			end
		end)
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			local held = grip
			if held == nil then
				return
			end
			local follows = if held.UserInputType == Enum.UserInputType.Touch
				then input == held
				else input.UserInputType == Enum.UserInputType.MouseMovement
			if not follows then
				return
			end
			local now, x = os.clock(), input.Position.X
			set(ToonSpinViewModel.drag(spinState.current, x - lastX, window.AbsoluteSize.X, now - lastAt))
			lastX, lastAt = x, now
		end)
		local function letGo()
			grip = nil
			local now = os.clock()
			local state = spinState.current
			if now - lastAt > SPIN_HOLD_STILL then
				state = ToonSpinViewModel.drag(state, 0, window.AbsoluteSize.X, now - lastAt)
			end
			set(ToonSpinViewModel.release(state))
		end
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			local held = grip
			if held == nil then
				return
			end
			local same = if held.UserInputType == Enum.UserInputType.Touch
				then input == held
				else input.UserInputType == held.UserInputType
			if same then
				letGo()
			end
		end)
		spinActions += 1
		local action = `ToonSpin{spinActions}`
		ContextActionService:BindActionAtPriority(
			action,
			function(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
				stick = if state == Enum.UserInputState.Change or state == Enum.UserInputState.Begin
					then input.Position.X
					else 0
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Thumbstick2
		)
		local stepping = RunService.Heartbeat:Connect(function(dt: number)
			set(ToonSpinViewModel.step(spinState.current, dt, stick))
		end)
		return function()
			began:Disconnect()
			moved:Disconnect()
			ended:Disconnect()
			stepping:Disconnect()
			ContextActionService:UnbindAction(action)
			if grip ~= nil then
				grip = nil
				spinState.current = ToonSpinViewModel.release(spinState.current)
			end
		end
	end, spinDeps)
end

return useToonSpin
