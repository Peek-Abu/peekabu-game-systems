--!strict
--[=[
	ShiftTransitPanel: the load screen in the V1 kit (load render). A full-screen night cover that fades in over
	TRANSIT_FADE_IN when `cover` leaves "none" and out over TRANSIT_FADE_OUT when it returns (it starts opaque when
	mounted covered, so a booting client never sees an unlit frame). With cover "slip" it carries the trip, laid out on
	a 1440x720 canvas scaled by `scale` (ShiftTransitViewModel.fit): the cream "EN ROUTE TO" card (the client in big
	stroked letters, the site line, the run's map's graded photo (while a map's photo is not uploaded, its map card's icon on
	a coloured plate), the truck's number on a sticker), the map's monster's tip and portrait on a
	dark plate with Gloom pooled along its floor, the company truck render driving in on speed lines, and the grape
	loading bar: a real progress bar that follows this client's readiness (`progress`) and never goes back, easing to
	full with DOORS OPEN! once this client is ready, then the cover fades. With cover "welcome" (a first join to the hub,
	while the art loads) it carries the welcome card on the same canvas: the game's name and a line on the cream card,
	Pippa in her Lavender Specs skin waving beside it (a ToonViewport of her live model; ShiftConstants.WELCOME_SKIN), a tip on the dark goo plate and the same loading bar (it follows the preload, then ALL
	SET!). A fading-out cover keeps its last lines. Presentational: the words are ShiftTransitViewModel.slip and
	ShiftTransitViewModel.welcome.

	@class ShiftTransitPanel
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local ShiftTransitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type ShiftTransitPanelProps = {
	cover: ShiftTypes.TransitCover,
	view: ShiftTransitViewModel.SlipView?,
	-- The welcome card's words, with cover "welcome".
	welcome: ShiftTransitViewModel.WelcomeView?,
	-- ShiftTransitViewModel.fit of this screen.
	scale: number,
	-- How far this client is toward its reveal (ShiftTransitStore.progress): the loading bar's target.
	progress: number,
	-- How long the cover's fade in or out takes; nil = TRANSIT_FADE_IN / TRANSIT_FADE_OUT (an office entrance's quick
	-- black cover sets it).
	fadeSeconds: number?,
}

local COLOR = UIToonConstants.COLOR
local CANVAS = Vector2.new(1440, 720)

type Nodes = { [string]: React.ReactNode }

-- The card's picture: the run's map's photo, or (while that map has none uploaded) the map card's icon on a gold
-- plate in the same frame, so a School card never shows the Office.
local function photo(view: ShiftTransitViewModel.SlipView): React.ReactNode
	local image = view.photo
	local frame: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 20) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 5 }),
	}
	if image == nil then
		-- The School map card's gold (DepotMapCards' gleam), lit from the top.
		local gold = UIToonConstants.shade("gold")
		frame.gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(gold.hi, gold.base) })
		frame.icon = e(ToonIcon, {
			icon = view.photoIcon,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromOffset(170, 170),
			drop = 6,
			zIndex = 2,
		})
	end
	return e("ImageLabel", {
		Position = UDim2.fromOffset(28, 192),
		Size = UDim2.fromOffset(544, 206),
		BackgroundColor3 = if image ~= nil then COLOR.ink else COLOR.white,
		Image = image or "",
		ScaleType = Enum.ScaleType.Crop,
	}, frame)
end

local function card(view: ShiftTransitViewModel.SlipView): React.ReactNode
	local face: Nodes = {
		heading = e(ToonText, {
			text = view.heading,
			textSize = 30,
			position = UDim2.fromOffset(28, 22),
			size = UDim2.fromOffset(360, 36),
			fit = true,
		}),
		client = e(ToonText, {
			text = view.client,
			textSize = 76,
			position = UDim2.fromOffset(26, 60),
			size = UDim2.fromOffset(546, 86),
			fit = true,
		}),
		site = e(ToonText, {
			text = view.site,
			font = "body",
			textSize = 24,
			position = UDim2.fromOffset(30, 150),
			size = UDim2.fromOffset(540, 30),
			fit = true,
		}),
		photo = photo(view),
	}
	local truck = view.truck
	if truck ~= nil then
		face.truck = e(ToonPill, {
			text = truck,
			hue = "mint",
			textSize = 22,
			tilt = 6,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, 14, 0, 8),
			size = UDim2.fromOffset(140, 42),
			zIndex = 6,
		})
	end
	return e(ToonPanel, {
		size = Vector2.new(600, 430),
		position = UDim2.fromOffset(40, 30),
		pop = true,
		children = face,
	})
end

local function tip(view: ShiftTransitViewModel.SlipView): React.ReactNode
	local face: Nodes = {
		face = e(ToonIcon, {
			icon = view.portrait,
			position = UDim2.fromOffset(-46, -26),
			size = UDim2.fromOffset(160, 160),
			drop = 6,
			zIndex = 6,
		}),
		title = e(ToonText, {
			text = "TIP",
			textSize = 32,
			position = UDim2.fromOffset(126, 12),
			size = UDim2.fromOffset(200, 38),
		}),
		line = e(ToonText, {
			text = view.tip,
			font = "body",
			color = COLOR.white,
			textSize = 22,
			position = UDim2.fromOffset(128, 50),
			size = UDim2.fromOffset(450, 56),
			wrapped = true,
			fit = true,
			alignY = "top",
		}),
	}
	return e(ToonPanel, {
		hue = "night",
		size = Vector2.new(600, 136),
		position = UDim2.fromOffset(40, 494),
		gloss = false,
		goo = { kind = "pool", from = 150, to = 560, scale = 0.45 },
		children = face,
	})
end

-- The grape loading bar: it follows the client's readiness (`progress`, ShiftTransitRules.progress) and never goes
-- back (ShiftTransitViewModel.advance moves it every frame), and eases to full once this client has arrived.
local function LoadBar(props: { label: string, arrived: boolean, progress: number }): React.ReactNode
	local fill, setFill = React.useBinding(0)
	-- The latest target and arrival, read by the frame loop without re-subscribing it.
	local target = React.useRef(props.progress)
	local arrived = React.useRef(props.arrived)
	target.current = props.progress
	arrived.current = props.arrived
	React.useEffect(function(): () -> ()
		local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			local shown = fill:getValue()
			local nextValue = ShiftTransitViewModel.advance(shown, target.current, arrived.current, deltaTime)
			if nextValue ~= shown then
				setFill(nextValue)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return e(ToonBar, {
		kind = "load",
		fill = fill,
		label = props.label,
		labelSize = 30,
		position = UDim2.fromOffset(40, 660),
		size = UDim2.fromOffset(CANVAS.X - 80, 50),
	})
end

local function trip(view: ShiftTransitViewModel.SlipView, progress: number): React.ReactNode
	local nodes: Nodes = {
		card = card(view),
		tip = tip(view),
		truck = e(ToonIcon, {
			image = UIAssets.toonPhotos.truckCut,
			position = UDim2.fromOffset(660, -40),
			size = UDim2.fromOffset(760, 680),
			drop = 10,
			zIndex = 2,
		}),
		bar = e(LoadBar, { label = view.bar, arrived = view.arrived, progress = progress }),
	}
	-- Speed lines behind the truck.
	for index = 1, 5 do
		nodes[`speed{index}`] = e("Frame", {
			Position = UDim2.fromOffset(640 + (index % 2) * 30, 440 + index * 26),
			Size = UDim2.fromOffset(260 - index * 18, 5),
			BackgroundColor3 = COLOR.white,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes)
end

-- A first join's welcome card: the game's name and a line on the cream card, Pippa saluting, a tip, the bar.
local function greeting(view: ShiftTransitViewModel.WelcomeView, progress: number): React.ReactNode
	local face: Nodes = {
		title = e(ToonText, {
			text = view.title,
			textSize = 120,
			position = UDim2.fromOffset(36, 40),
			size = UDim2.fromOffset(688, 132),
			fit = true,
		}),
		line = e(ToonText, {
			text = view.line,
			font = "body",
			textSize = 32,
			position = UDim2.fromOffset(40, 196),
			size = UDim2.fromOffset(680, 64),
			wrapped = true,
			fit = true,
		}),
	}
	local tipFace: Nodes = {
		line = e(ToonText, {
			text = view.tip,
			font = "body",
			color = COLOR.white,
			textSize = 30,
			position = UDim2.fromOffset(32, 22),
			size = UDim2.fromOffset(696, 60),
			wrapped = true,
			fit = true,
		}),
	}
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		card = e(ToonPanel, {
			size = Vector2.new(760, 300),
			position = UDim2.fromOffset(80, 130),
			pop = true,
			children = face,
		}),
		tip = e(ToonPanel, {
			hue = "night",
			size = Vector2.new(760, 110),
			position = UDim2.fromOffset(80, 480),
			gloss = false,
			goo = { kind = "pool", from = 160, to = 700, scale = 0.45 },
			children = tipFace,
		}),
		-- Pippa in Lavender Specs (ShiftConstants.WELCOME_SKIN), from her live model, waving (her profile pose).
		pippa = e(ToonViewport, {
			employee = ShiftConstants.WELCOME_EMPLOYEE,
			skin = ShiftConstants.WELCOME_SKIN,
			context = "profile",
			framing = "full",
			position = UDim2.fromOffset(900, 10),
			size = UDim2.fromOffset(520, 620),
			zIndex = 2,
		}),
		bar = e(LoadBar, { label = view.bar, arrived = view.arrived, progress = progress }),
	})
end

local function ShiftTransitPanel(props: ShiftTransitPanelProps): React.ReactNode
	local covered = props.cover ~= "none"
	-- The cover's GroupTransparency: 0 opaque, 1 gone.
	local transparency, setTransparency = React.useBinding(if covered then 0 else 1)
	local shown, setShown = React.useState(covered)
	-- The last kind and lines covered, kept through the fade out.
	local lastKind = React.useRef(props.cover)
	local lastView = React.useRef(props.view)
	local lastWelcome = React.useRef(props.welcome)
	if covered then
		lastKind.current = props.cover
	end
	if props.view ~= nil then
		lastView.current = props.view
	end
	if props.welcome ~= nil then
		lastWelcome.current = props.welcome
	end

	React.useEffect(function(): () -> ()
		local target = if covered then 0 else 1
		local seconds = props.fadeSeconds
			or (if covered then ShiftConstants.TRANSIT_FADE_IN else ShiftConstants.TRANSIT_FADE_OUT)
		if covered then
			setShown(true)
		end
		local start = transparency:getValue()
		if start == target or GuiService.ReducedMotionEnabled then
			setTransparency(target)
			if not covered then
				setShown(false)
			end
			return function() end
		end
		local elapsed = 0
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime
			local t = math.min(elapsed / seconds, 1)
			setTransparency(start + (target - start) * t)
			if t >= 1 then
				if connection ~= nil then
					connection:Disconnect()
				end
				if not covered then
					setShown(false)
				end
			end
		end)
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, { covered })

	-- The text's shrink-to-fit limits follow the canvas's scale (see PaperScaleContext).
	local outer = React.useContext(PaperScaleContext.Context)
	local deps: { unknown } = { outer, props.scale }
	local scale = React.useMemo(function(): React.Binding<number>
		return outer:map(function(value: number): number
			return value * props.scale
		end)
	end, deps)

	if not shown and not covered then
		return nil
	end
	local view = lastView.current
	local withSlip = lastKind.current == "slip" and view ~= nil
	local welcome = lastWelcome.current
	local withWelcome = lastKind.current == "welcome" and welcome ~= nil
	return e(PaperScaleContext.Context.Provider, { value = scale }, {
		cover = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = UIToonConstants.shade("night").lo,
			BorderSizePixel = 0,
			GroupTransparency = transparency,
			-- Swallows clicks and taps on whatever is beneath.
			Active = true,
			ZIndex = 1000,
		}, {
			slip = if withSlip and view ~= nil
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
					BackgroundTransparency = 1,
				}, {
					scale = e("UIScale", { Scale = props.scale }),
					trip = trip(view, props.progress),
				})
				else nil,
			welcome = if withWelcome and welcome ~= nil
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
					BackgroundTransparency = 1,
				}, {
					scale = e("UIScale", { Scale = props.scale }),
					greeting = greeting(welcome, props.progress),
				})
				else nil,
		}),
	})
end

return ShiftTransitPanel
