--!strict
--[=[
	FadeGroup: wraps its children in a `CanvasGroup` and fades the whole group in/out by easing the
	group's single `GroupTransparency`, instead of snapping `Visible`. The reusable, global fade for UI —
	`HudRoot` uses it to fade the HUD when a scene hides it, and any scene/panel can wrap its content in
	it for a clean enter/exit.

	Why a `CanvasGroup`: it composites its descendants to one layer and fades them uniformly through ONE
	property — no walking the tree tweening each element's own transparency (the fragile thing the old
	game did, which missed element types and fought per-element state). Trade-off: the group renders to a
	texture (minor cost, fine for a HUD).

	The transparency eases on `RunService.Heartbeat` (binding writes only, no re-render) via the shared
	`TrailEasingUtils.approach`. Fully faded, the group also flips `Visible` off (a derived binding, not an
	imperative write) so a hidden HUD costs nothing. Exempt from spec-first (CanvasGroup + renderer);
	the pure easing step is specced.

	@class FadeGroup
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local TrailEasingUtils = require(ReplicatedStorage.Client.UI.React.Hooks.TrailEasingUtils)

local e = React.createElement

-- Ease rate (per second) for the fade; ~0.15s in/out. Below this transparency the group is treated as
-- gone and hidden outright.
local DEFAULT_FADE_RATE = 12
local HIDDEN_THRESHOLD = 0.999

export type FadeGroupProps = {
	visible: boolean,
	fadeRate: number?,
	children: { [string]: React.ReactNode }?,
}

--[=[
	@param props FadeGroupProps
	@return React.ReactNode
]=]
local function FadeGroup(props: FadeGroupProps): React.ReactNode
	local rate = props.fadeRate or DEFAULT_FADE_RATE
	local targetTransparency = if props.visible then 0 else 1

	local transparency, setTransparency = React.useBinding(targetTransparency)
	-- Track the latest target across renders so the Heartbeat (a one-time effect) always chases the
	-- current `visible`.
	local targetRef = React.useRef(targetTransparency)
	targetRef.current = targetTransparency

	React.useEffect(function(): () -> ()
		local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			local current = transparency:getValue()
			local target = targetRef.current
			if current ~= target then
				setTransparency(TrailEasingUtils.approach(current, target, rate, rate, deltaTime))
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	return e("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = transparency,
		-- Derived (a prop, never an imperative `.Visible =` write): drop out of rendering once fully faded.
		Visible = transparency:map(function(value: number)
			return value < HIDDEN_THRESHOLD
		end),
	}, props.children)
end

return FadeGroup
