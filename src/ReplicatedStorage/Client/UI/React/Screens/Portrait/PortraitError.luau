--!strict
--[=[
	PortraitError: the one loud sign that a character portrait could not be drawn (CharacterPortrait, ToonViewport).
	While `shown` is false it stays blank for PortraitViewModel.ERROR_GRACE (a respawn or a stream-in fills the
	frame in that time), then fills the frame with a danger-red tile and a big "!" and warns once in the output, so
	a broken portrait is never mistaken for a look. One error for every employee and skin: there are no per-skin
	stand-in photos. Presentational (exempt; the wait / error choice is specced in PortraitViewModel.missing).

	@class PortraitError
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type PortraitErrorProps = {
	-- Whether the portrait is drawing; the error only ever shows while it is not.
	shown: boolean,
	-- What could not be drawn, for the output warning (e.g. "Pippa").
	subject: string?,
	round: boolean?,
	zIndex: number?,
}

local function PortraitError(props: PortraitErrorProps): React.ReactNode
	-- When the portrait stopped drawing (nil while it draws), stamped in the same render that sees it go, so a frame
	-- that was showing never flashes the error on its way out.
	local noTime: number? = nil
	local lostAt = React.useRef(noTime)
	if props.shown then
		lostAt.current = nil
	elseif lostAt.current == nil then
		lostAt.current = os.clock()
	end
	local _, setTick = React.useState(0)

	React.useEffect(function(): () -> ()
		if props.shown then
			return function() end
		end
		local pending = task.delay(PortraitViewModel.ERROR_GRACE, function()
			setTick(function(n: number): number
				return n + 1
			end)
		end)
		return function()
			task.cancel(pending)
		end
	end, { props.shown })

	local since = lostAt.current
	local state = PortraitViewModel.missing(props.shown, if since ~= nil then os.clock() - since else 0)
	React.useEffect(function()
		if state == "error" then
			warn(`[Portrait] could not draw {props.subject or "a character"}: showing the error tile`)
		end
	end, { state })

	if state ~= "error" then
		return nil
	end
	local radius = if props.round == true then UDim.new(0.5, 0) else UDim.new(0, UIToonConstants.DEPTH.buttonRadius)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIToonConstants.COLOR.danger,
		ZIndex = props.zIndex,
	}, {
		corner = e("UICorner", { CornerRadius = radius }),
		stroke = e("UIStroke", {
			Color = UIToonConstants.COLOR.ink,
			Thickness = UIToonConstants.DEPTH.outline,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		bang = e("TextLabel", {
			Size = UDim2.fromScale(1, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = UIToonConstants.FONT.display,
			Text = "!",
			TextScaled = true,
			TextColor3 = UIToonConstants.COLOR.white,
			ZIndex = props.zIndex,
		}, {
			ink = e("UIStroke", { Color = UIToonConstants.COLOR.ink, Thickness = 3 }),
		}),
	})
end

return PortraitError
