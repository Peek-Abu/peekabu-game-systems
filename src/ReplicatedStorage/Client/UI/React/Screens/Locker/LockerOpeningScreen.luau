--!strict
--[=[
	LockerOpeningScreen: stage-1 Locker opening over the depot (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md). The Locker render shakes, the key flies in, the
	screen flashes the rolled rarity's colour, rays spin behind the Locker, and when the opening finishes (or the
	player taps Skip after the first second) it hands off to the existing `RevealScreen` via `onFinish`.

	Presentational React screen over `LockerStore.opening` (exempt; values specced in `LockerViewModel`).

	@class LockerOpeningScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local LockerStore = require(ReplicatedStorage.Client.Features.Locker.State.LockerStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement

type Nodes = { [string]: React.ReactNode }

export type LockerOpeningScreenProps = {
	outcome: LockerTypes.Outcome?,
	onFinish: (() -> ())?,
	viewport: Vector2?,
	phone: boolean?,
}

local SPARKLES: { ToonSparkle.Spot } = {
	{ position = UDim2.fromScale(0.12, 0.16), size = 34 },
	{ position = UDim2.fromScale(0.88, 0.2), size = 30 },
	{ position = UDim2.fromScale(0.16, 0.84), size = 28 },
	{ position = UDim2.fromScale(0.86, 0.8), size = 36 },
	{ position = UDim2.fromScale(0.06, 0.52), size = 26 },
	{ position = UDim2.fromScale(0.94, 0.48), size = 32 },
}

local function LockerOpeningScreen(props: LockerOpeningScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local stored = ReactCharm.useAtom(LockerStore.opening)
	local outcome = props.outcome or stored
	local canSkip, setCanSkip = React.useState(false)

	local key = if outcome ~= nil then `{outcome.locker}:{outcome.item}:{outcome.pity}` else ""
	local progress = useToonPlay(VM.OPENING_DURATION, 0, key)

	local deps: { unknown } = { key, outcome ~= nil, props.onFinish }
	React.useEffect(function(): () -> ()
		setCanSkip(false)
		if outcome == nil then
			return function() end
		end
		local running = true
		local skipThread = task.delay(VM.SKIP_AFTER, function()
			if running then
				setCanSkip(true)
			end
		end)
		local finishThread: thread? = nil
		local onFinish = props.onFinish
		if onFinish ~= nil then
			finishThread = task.delay(VM.OPENING_DURATION, function()
				if running then
					onFinish()
				end
			end)
		end
		return function()
			running = false
			task.cancel(skipThread)
			if finishThread ~= nil then
				task.cancel(finishThread)
			end
		end
	end, deps)

	if outcome == nil then
		return nil
	end

	local view = VM.openingView(outcome)
	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local shade = UIToonConstants.rarity(view.rarity)
	local lockerHue: UIToonConstants.Hue = if view.locker == "gleam" then "gold" else "grape"
	local lockerShade = UIToonConstants.shade(lockerHue)
	local boxSize = if phone then 170 else 340
	local keySize = if phone then 64 else 128

	local function skip()
		local onFinish = props.onFinish
		if onFinish ~= nil then
			onFinish()
		end
	end

	local boxChildren: Nodes = {
		icon = e(ToonIcon, {
			icon = "locker",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.48),
			size = UDim2.fromScale(0.72, 0.72),
			drop = 6,
		}),
	}

	local nodes: Nodes = {
		title = e(ToonText, {
			text = string.upper(view.lockerName),
			textSize = if phone then 34 else 72,
			meaning = if view.locker == "gleam" then "gold" else "grape",
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, if phone then 22 else 54),
			size = UDim2.new(0.7, 0, 0, if phone then 42 else 84),
			align = "center",
			fit = true,
			zIndex = 5,
		}),
		guaranteed = if view.guaranteed
			then e(ToonFlag, {
				text = "PITY GUARANTEE!",
				rarity = view.rarity,
				tilt = -3,
				textSize = if phone then 14 else 26,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, if phone then 68 else 148),
				size = UDim2.fromOffset(if phone then 190 else 360, if phone then 28 else 48),
				zIndex = 6,
			})
			else nil,
		lockerBox = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = progress:map(function(alpha: number): UDim2
				local shake = if alpha < 0.72 then math.sin(alpha * math.pi * 22) * (1 - alpha) * 14 else 0
				return UDim2.new(0.5, math.floor(shake), 0.52, 0)
			end),
			Rotation = progress:map(function(alpha: number): number
				return if alpha < 0.72 then math.sin(alpha * math.pi * 18) * 5 else 0
			end),
			Size = UDim2.fromOffset(boxSize, boxSize),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			card = e(ToonSurface, {
				hue = lockerHue,
				pattern = "sparkle",
				radius = 30,
				size = UDim2.fromScale(1, 1),
				children = boxChildren,
			}),
			sparkles = e(ToonSparkle, { spots = SPARKLES, zIndex = 8 }),
		}),
		flyingKey = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = progress:map(function(alpha: number): UDim2
				local t = math.clamp(alpha / 0.45, 0, 1)
				return UDim2.fromScale(0.18 + 0.32 * t, 0.78 - 0.26 * t)
			end),
			Rotation = progress:map(function(alpha: number): number
				local t = math.clamp(alpha / 0.45, 0, 1)
				return -28 + 28 * t
			end),
			Size = UDim2.fromOffset(keySize, keySize),
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, {
			icon = e(ToonIcon, {
				icon = "key",
				size = UDim2.fromScale(1, 1),
				drop = 5,
			}),
		}),
		skip = if canSkip
			then e(ToonButton, {
				variant = "secondary",
				text = "Skip",
				textSize = if phone then 18 else 32,
				small = phone,
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -(if phone then 18 else 36), 1, -(if phone then 16 else 36)),
				size = UDim2.fromOffset(if phone then 110 else 200, if phone then 40 else 68),
				onActivated = skip,
				zIndex = 12,
			})
			else nil,
	}

	local screen: Nodes = {
		flash = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = shade.hi,
			BackgroundTransparency = progress:map(function(alpha: number): number
				if alpha < 0.62 then
					return 1
				end
				local burst = (alpha - 0.62) / 0.38
				return math.clamp(1 - math.sin(burst * math.pi) * 0.85, 0.15, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 20,
		}),
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes),
			},
		}),
	}

	return e(ToonBackdrop, {
		top = lockerShade.base,
		bottom = shade.lo,
		stripes = true,
		rays = { position = UDim2.fromScale(0.5, 0.52), size = 0.95, color = shade.hi, transparency = 0.25 },
		blur = props.outcome == nil,
		children = screen,
	})
end

return LockerOpeningScreen
