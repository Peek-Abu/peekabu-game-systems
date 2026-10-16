--!strict
--[=[
	ShiftTransitPanel: the transit screen. A full-screen night-black cover that fades in over TRANSIT_FADE_IN when
	`cover` leaves "none" and out over TRANSIT_FADE_OUT when it returns (it starts opaque when mounted covered, so a
	booting client never sees an unlit frame). With cover "slip" it carries the route slip (ShiftTransitViewModel),
	centred and scaled by `scale`: a 560x300 cream dispatch slip tilted -1.5°, the teal company band ("TRUCK n" in glow
	green), ROUTE SLIP (Oswald 40), FROM / TO lines (Special Elite 24), a dashed road the stamp-red truck block keeps
	crossing (LOOP_SECONDS a crossing; parked at the end once arrived; still under reduced motion), the note,
	and the red IN TRANSIT stamp, which pops to a green ARRIVED. A fading-out slip keeps its last lines. Presentational.

	@class ShiftTransitPanel
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftTransitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftTransitViewModel)

local e = React.createElement

export type ShiftTransitPanelProps = {
	cover: ShiftTypes.TransitCover,
	view: ShiftTransitViewModel.SlipView?,
	-- WorldBillboardViewModel.screenScale of this screen.
	scale: number,
}

local COLOR = UIPaperConstants.COLOR
local SLIP = Vector2.new(560, 300)
local BAND = 46
local DASHES = 13
local DASH = Vector2.new(24, 6)
local DASH_STEP = 36
local ROAD = Vector2.new(24, 214)
local TRUCK = Vector2.new(30, 20)
-- One crossing of the road while in transit.
local LOOP_SECONDS = 2.4

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	position: UDim2,
	frame: UDim2
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = position,
		frame = frame,
		autoSize = false,
		wrapped = false,
		scaled = true,
		zIndex = 2,
	})
end

-- A FROM / TO tag: fixed size (a scaled label shrinks a short word too far).
local function tag(text: string, y: number): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = "heading",
		size = 20,
		color = COLOR.companyTeal,
		position = UDim2.fromOffset(24, y),
		frame = UDim2.fromOffset(60, 30),
		autoSize = false,
		wrapped = false,
		zIndex = 2,
	})
end

-- The dashed road; the truck keeps crossing it until `arrived` parks it at the end.
local function Road(props: { arrived: boolean }): React.ReactNode
	local alpha, setAlpha = React.useBinding(if props.arrived then 1 else 0)
	React.useEffect(function(): () -> ()
		if props.arrived then
			setAlpha(1)
			return function() end
		end
		if GuiService.ReducedMotionEnabled then
			setAlpha(0.5)
			return function() end
		end
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			elapsed += deltaTime
			setAlpha((elapsed / LOOP_SECONDS) % 1)
		end)
		return function()
			connection:Disconnect()
		end
	end, { props.arrived })
	local children: { [string]: React.ReactNode } = {
		truck = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = alpha:map(function(value: number): UDim2
				return UDim2.fromOffset(DASH.X / 2 + value * (DASHES - 1) * DASH_STEP, DASH.Y / 2)
			end),
			Size = UDim2.fromOffset(TRUCK.X, TRUCK.Y),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
	}
	for index = 1, DASHES do
		children[`dash{index}`] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * DASH_STEP, 0),
			Size = UDim2.fromOffset(DASH.X, DASH.Y),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return e("Frame", {
		Position = UDim2.fromOffset(ROAD.X, ROAD.Y),
		Size = UDim2.fromOffset((DASHES - 1) * DASH_STEP + DASH.X, DASH.Y),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, children)
end

local function slip(view: ShiftTransitViewModel.SlipView): React.ReactNode
	local truck = view.truck
	local paper: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		texture = e(PaperTexture, { paper = COLOR.cream, corner = 4 }),
		band = e("Frame", {
			Size = UDim2.new(1, 0, 0, BAND),
			BackgroundColor3 = COLOR.companyTeal,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			label = label(view.band, "heading", 22, COLOR.cream, UDim2.fromOffset(20, 0), UDim2.new(1, -170, 1, 0)),
			truck = if truck ~= nil
				then e(PaperLabel, {
					text = truck,
					role = "heading",
					size = 22,
					color = COLOR.fluorGlow,
					align = "right",
					position = UDim2.new(1, -140, 0, 0),
					frame = UDim2.fromOffset(120, BAND),
					autoSize = false,
					wrapped = false,
					zIndex = 3,
				})
				else nil,
		}),
		title = label(view.title, "heading", 40, COLOR.ink, UDim2.fromOffset(24, 58), UDim2.fromOffset(300, 48)),
		fromTag = tag("FROM", 116),
		from = label(view.from, "body", 24, COLOR.ink, UDim2.fromOffset(90, 116), UDim2.fromOffset(300, 30)),
		toTag = tag("TO", 154),
		to = label(view.to, "body", 24, COLOR.ink, UDim2.fromOffset(90, 154), UDim2.fromOffset(440, 30)),
		road = e(Road, { arrived = view.arrived }),
		note = label(view.note, "body", 18, COLOR.ink, UDim2.fromOffset(24, 246), UDim2.fromOffset(500, 26)),
	}
	-- Keyed by the word, so ARRIVED stamps down fresh (its pop).
	paper[`stamp{view.stamp}`] = e(PaperStamp, {
		text = view.stamp,
		size = 40,
		color = if view.arrived then COLOR.inkGreen else COLOR.stamp,
		tilt = -8,
		pop = view.arrived,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -24, 0, 64),
	})
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SLIP.X, SLIP.Y),
		Rotation = -1.5,
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			Position = UDim2.fromOffset(5, 7),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
		paper = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, paper),
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
	if covered then
		lastKind.current = props.cover
	end
	if props.view ~= nil then
		lastView.current = props.view
	end

	React.useEffect(function(): () -> ()
		local target = if covered then 0 else 1
		local seconds = if covered then ShiftConstants.TRANSIT_FADE_IN else ShiftConstants.TRANSIT_FADE_OUT
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

	-- PaperLabel's shrink-to-fit limits follow the slip's scale (see PaperScaleContext).
	local scale = React.useMemo(function(): React.Binding<number>
		local binding = React.createBinding(props.scale)
		return binding
	end, { tostring(props.scale) })

	if not shown and not covered then
		return nil
	end
	local view = lastView.current
	local withSlip = lastKind.current == "slip" and view ~= nil
	return e(PaperScaleContext.Context.Provider, { value = scale }, {
		cover = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.night,
			BorderSizePixel = 0,
			GroupTransparency = transparency,
			-- Swallows clicks and taps on whatever is beneath.
			Active = true,
			ZIndex = 1000,
		}, {
			slip = if withSlip and view ~= nil
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.46),
					Size = UDim2.fromOffset(SLIP.X, SLIP.Y),
					BackgroundTransparency = 1,
				}, {
					scale = e("UIScale", { Scale = props.scale }),
					slip = slip(view),
				})
				else nil,
		}),
	})
end

return ShiftTransitPanel
