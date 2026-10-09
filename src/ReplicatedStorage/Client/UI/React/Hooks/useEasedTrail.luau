--!strict
--[=[
	useEasedTrail: the shared HUD hook behind every "fill + trail" bar. Given a `target` fraction
	(a binding, so it can be driven with no re-render), it returns TWO eased bindings — the `fill` and a
	`trail` — each easing toward the target on `RunService.Heartbeat` at its own rates.

	This is the one place the damage-trail / gain-lead behaviour lives (DRY). The difference between the
	two is purely CONFIG — which value lags, in which direction, and for how long it holds first:
	- **Health:** the fill drains smoothly; the TRAIL lags on the way DOWN (holds, then drains) → a dark
	  "lost" chunk lingers behind the fill and catches up.
	- **XP:** the TRAIL is a lead that races ahead; the FILL lags on the way UP (holds while the lead
	  shows, then rises) → the dark lead previews the new value and the bright fill sweeps up into it.

	Each value's `Rate` can declare a `hold` (seconds) in a `holdDir` — the value pauses that long before
	easing in that one direction (its lagging direction), and eases freely otherwise. That single knob
	expresses both the health drain-hold (`holdDir = "down"`) and the XP fill-hold (`holdDir = "up"`).

	Both bindings feed a `ClippedBar` (as `fraction` and `catchup`). Because the bar derives its clip AND
	fill sizes from the SAME eased fraction each frame, the clip technique stays exact — the easing is on
	the single fraction, never the two sizes independently (the old code's stretch bug).

	Heartbeat writes bindings only, so easing never triggers a re-render. Exempt from the spec-first rule
	(needs a renderer + RunService); the pure step it calls, `TrailEasingUtils.approach`, is specced.

	@class useEasedTrail
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local TrailEasingUtils = require(ReplicatedStorage.Client.UI.React.Hooks.TrailEasingUtils)

-- Easing for one value. `up`/`down` are per-second rates (split by direction so a bar can, e.g., drain
-- slowly but fill fast; a big rate is effectively an instant snap). Optionally the value HOLDS for
-- `hold` seconds before it begins easing in `holdDir` — its lagging direction — and eases freely the
-- other way.
export type Rate = {
	up: number,
	down: number,
	hold: number?,
	holdDir: ("up" | "down")?,
}

export type TrailConfig = {
	fill: Rate,
	trail: Rate,
}

-- One value's per-frame step, gating the ease through the hold when it's moving in its hold direction.
-- `holdRef` carries the countdown across frames; it re-arms whenever the value isn't holding.
local function step(
	value: React.Binding<number>,
	setValue: (number) -> (),
	target: number,
	rate: Rate,
	holdRef: { current: number },
	deltaTime: number
)
	local current = value:getValue()
	local direction = if target > current then "up" elseif target < current then "down" else "none"
	if rate.holdDir ~= nil and direction == rate.holdDir then
		-- Moving in the hold direction: burn the hold down first, then ease.
		if holdRef.current > 0 then
			holdRef.current -= deltaTime
			return
		end
	else
		-- At target or moving the other way: no hold applies, and re-arm it for the next lag.
		holdRef.current = rate.hold or 0
	end
	-- At rest `approach` returns `current` unchanged, but the WRITE still happens, and each one
	-- reallocates a UDim2 in every binding mapped off this value — so an idle HUD never actually idled.
	-- Matches FadeGroup, which already guards. Placed AFTER the hold block so the hold still re-arms.
	if current == target then
		return
	end
	setValue(TrailEasingUtils.approach(current, target, rate.up, rate.down, deltaTime))
end

--[=[
	@param target React.Binding<number> -- the fraction (0..1) both values ease toward
	@param config TrailConfig -- per-value rates (+ optional directional hold) for the fill and the trail
	@return (React.Binding<number>, React.Binding<number>) -- the eased fill and trail bindings
]=]
local function useEasedTrail(
	target: React.Binding<number>,
	config: TrailConfig
): (React.Binding<number>, React.Binding<number>)
	local seed = target:getValue()
	local fill, setFill = React.useBinding(seed)
	local trail, setTrail = React.useBinding(seed)
	local fillHold = React.useRef(config.fill.hold or 0)
	local trailHold = React.useRef(config.trail.hold or 0)

	React.useEffect(function(): () -> ()
		local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			local t = target:getValue()
			step(fill, setFill, t, config.fill, fillHold, deltaTime)
			step(trail, setTrail, t, config.trail, trailHold, deltaTime)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	return fill, trail
end

return useEasedTrail
