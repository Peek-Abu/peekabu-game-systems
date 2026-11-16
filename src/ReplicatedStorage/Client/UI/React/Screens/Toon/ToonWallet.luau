--!strict
--[=[
	ToonWallet: a balance pill (Credits, Gleam, Gloom) whose number moves when the balance does (owner pick M5,
	2026-11-16): it counts to the new balance over MOTION.countSeconds; when the balance grows the pill bumps once and a
	mint "+40" floats off it with two soap bubbles; spending just counts down. A balance that arrives right after the
	pill mounts (the profile loading in) is simply shown, so joining never floats "+1,240". Reduced Motion: the number
	changes at once, no bump, no floater. Draws a ToonPill. Presentational (exempt; the count, bump and float curves are
	specced in ToonMotionViewModel.count / bump / float).

	@class ToonWallet
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

local MOTION = UIToonConstants.MOTION

-- A change this soon after the pill mounts is the balance loading in, not an earning (seconds).
local SETTLE_SECONDS = 1.5

export type ToonWalletProps = {
	amount: number,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	meaning: UIToonConstants.Meaning?,
	textSize: number?,
	icon: UIAssets.ToonIcon?,
	iconSize: number?,
	small: boolean?,
	zIndex: number?,
}

type Gain = { id: number, amount: number }

local function ToonWallet(props: ToonWalletProps): React.ReactNode
	local amount = props.amount
	local shown, setShown = React.useState(amount)
	local none: Gain = { id = 0, amount = 0 }
	local gain, setGain = React.useState(none)
	local target = React.useRef(amount)
	local current = React.useRef(amount)
	local mountedAt = React.useRef(os.clock())
	React.useEffect(function(): () -> ()
		local from = current.current or amount
		local previous = target.current or amount
		target.current = amount
		if previous == amount then
			return function() end
		end
		local settled = os.clock() - (mountedAt.current or 0) > SETTLE_SECONDS
		if not settled or GuiService.ReducedMotionEnabled then
			current.current = amount
			setShown(amount)
			return function() end
		end
		if amount > previous then
			setGain(function(last: Gain): Gain
				return { id = last.id + 1, amount = amount - previous }
			end)
		end
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local t = (os.clock() - started) / MOTION.countSeconds
			local value = ToonMotionViewModel.count(from, amount, t)
			current.current = value
			setShown(value)
			if t >= 1 then
				connection:Disconnect()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { amount })

	local gained = gain.id > 0
	local key = tostring(gain.id)
	local bump = useToonPlay(if gained then MOTION.bumpSeconds else 0, 0, key)
	local float = useToonPlay(if gained then MOTION.floatSeconds else 0, 0, key)
	local textSize = props.textSize or 26
	local floatSize = math.max(16, math.floor(textSize * 0.7))
	local floatTransparency = float:map(function(t: number): number
		return ToonMotionViewModel.float(t).transparency
	end)

	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		bump = e("UIScale", {
			Scale = bump:map(function(t: number): number
				return if gained then ToonMotionViewModel.bump(t) else 1
			end),
		}),
		pill = e(ToonPill, {
			text = ToonStyleViewModel.grouped(shown),
			size = UDim2.fromScale(1, 1),
			meaning = props.meaning,
			textSize = props.textSize,
			icon = props.icon,
			iconSize = props.iconSize,
			small = props.small,
		}),
		-- The "+40" and its two bubbles, mounted only while one floats (the bubbles' clock loops while mounted).
		float = if gained
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = float:map(function(t: number): UDim2
					return UDim2.new(0.6, 0, 0, -ToonMotionViewModel.float(t).rise)
				end),
				Size = UDim2.fromOffset(floatSize * 4, floatSize + 8),
				BackgroundTransparency = 1,
				Visible = float:map(function(t: number): boolean
					return t < 1
				end),
				ZIndex = 6,
			}, {
				text = e(ToonText, {
					text = `+{ToonStyleViewModel.grouped(gain.amount)}`,
					textSize = floatSize,
					meaning = "mint",
					size = UDim2.fromScale(1, 1),
					align = "center",
					transparency = floatTransparency,
				}),
				bubbles = e(ToonSparkle, {
					spots = {
						{ position = UDim2.new(0, -2, 0.2, 0), size = math.floor(floatSize * 0.6) },
						{ position = UDim2.new(1, 2, 0.7, 0), size = math.floor(floatSize * 0.42) },
					},
					transparency = floatTransparency,
					zIndex = 2,
				}),
			})
			else nil,
	})
end

return ToonWallet
