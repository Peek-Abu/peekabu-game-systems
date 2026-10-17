--!strict
--[=[
	useToonPlay: a 0 -> 1 binding that TweenService plays once over `seconds` after `delay`, on mount and again
	whenever `key` changes (a panel's pop-in, the squeegee wipe), or over and over with `loop` (a sparkle's twinkle). The curve is applied by the
	caller (ToonMotionViewModel.pop / wipe). Reduced Motion starts it at 1. React hook (exempt: needs a renderer and
	TweenService; the curves are specced in ToonMotionViewModel).

	@class useToonPlay
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

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

local function useToonPlay(seconds: number, delay: number, key: string?, loop: boolean?): React.Binding<number>
	local reduced = useReduced()
	local driver = useDriver()
	local alpha, setAlpha = React.useBinding(if reduced then 1 else 0)
	local deps: { unknown } = { key or "", reduced, loop == true }
	React.useEffect(function(): () -> ()
		if reduced then
			setAlpha(1)
			return function() end
		end
		driver.Value = 0
		setAlpha(0)
		local changed = driver.Changed:Connect(setAlpha)
		local tween = TweenService:Create(
			driver,
			TweenInfo.new(
				seconds,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out,
				if loop then -1 else 0,
				false,
				delay
			),
			{ Value = 1 }
		)
		tween:Play()
		return function()
			changed:Disconnect()
			tween:Cancel()
			tween:Destroy()
		end
	end, deps)
	return alpha
end

return useToonPlay
