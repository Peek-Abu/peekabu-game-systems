--!strict
-- Tween a private NumberValue, never a React-owned GUI property. Only bindings update per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)
local Utils = require(script.Parent.ProgressTweenUtils)
local function useProgressTween(
	target: number,
	duration: number,
	resetKey: string?,
	snapDecrease: boolean?
): React.Binding<number>
	local normalized = Utils.target(target)
	local value, setValue = React.useBinding(normalized)
	local reduced, setReduced = React.useState(GuiService.ReducedMotionEnabled)
	local key = resetKey or ""
	local decreasing = snapDecrease == true
	local previousKey = React.useRef(key)
	local driver = React.useMemo(function(): NumberValue
		local number = Instance.new("NumberValue")
		number.Value = normalized
		return number
	end, {})
	React.useEffect(function(): () -> ()
		local preference = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			setReduced(GuiService.ReducedMotionEnabled)
		end)
		return function()
			preference:Disconnect()
			driver:Destroy()
		end
	end, {})
	local dependencies: { unknown } = { normalized, duration, key, reduced, decreasing }
	React.useEffect(function(): () -> ()
		local reset = previousKey.current ~= key
		previousKey.current = key
		local tween: Tween? = nil
		local changed = driver.Changed:Connect(function(nextValue: number)
			setValue(nextValue)
		end)
		if duration <= 0 or Utils.snap(driver.Value, normalized, reduced, reset, decreasing) then
			driver.Value = normalized
			setValue(normalized)
		else
			local nextTween = TweenService:Create(
				driver,
				TweenInfo.new(
					duration,
					if duration <= 0.08 then Enum.EasingStyle.Linear else Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{ Value = normalized }
			)
			nextTween:Play()
			tween = nextTween
		end
		return function()
			changed:Disconnect()
			if tween ~= nil then
				tween:Cancel()
				tween:Destroy()
			end
		end
	end, dependencies)
	return value
end
return useProgressTween
