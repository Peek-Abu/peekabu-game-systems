--!strict
--[=[
	useToonPose: a binding of the kit's Pose that TweenService eases (Back Out) from wherever it is now to `target`
	whenever the target changes (hover, press, selected, recede), cancelling a superseded tween mid-way. TweenService
	drives a private NumberValue 0 -> 1 and the binding blends the two poses (ToonStyleViewModel.blend), so nothing
	re-renders per frame and no GUI property React owns is tweened. Reduced Motion snaps. React hook (exempt: needs a
	renderer and TweenService; the poses and the blend are specced in ToonStyleViewModel).

	@class useToonPose
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

local function useReduced(): boolean
	local reduced, setReduced = React.useState(GuiService.ReducedMotionEnabled)
	React.useEffect(function(): () -> ()
		local connection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			setReduced(GuiService.ReducedMotionEnabled)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return reduced
end

local function useDriver(): NumberValue
	local driver = React.useMemo(function(): NumberValue
		return Instance.new("NumberValue")
	end, {})
	React.useEffect(function(): () -> ()
		return function()
			driver:Destroy()
		end
	end, {})
	return driver
end

local function useToonPose(target: ToonStyleViewModel.Pose, seconds: number): React.Binding<ToonStyleViewModel.Pose>
	local reduced = useReduced()
	local driver = useDriver()
	local pose, setPose = React.useBinding(target)
	-- Rebuilt only when a value of the target changes (a fresh table each render must not restart the tween).
	local deps: { unknown } = { target.lift, target.scale, target.drop, target.lip, target.ring, target.dim, reduced }
	React.useEffect(function(): () -> ()
		local from = pose:getValue()
		if reduced or seconds <= 0 then
			setPose(target)
			return function() end
		end
		driver.Value = 0
		local changed = driver.Changed:Connect(function(t: number)
			setPose(ToonStyleViewModel.blend(from, target, t))
		end)
		local tween = TweenService:Create(
			driver,
			TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Value = 1 }
		)
		tween:Play()
		return function()
			changed:Disconnect()
			tween:Cancel()
			tween:Destroy()
		end
	end, deps)
	return pose
end

return useToonPose
